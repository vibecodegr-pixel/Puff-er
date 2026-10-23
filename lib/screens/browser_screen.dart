import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../models/video_item.dart';
import '../services/buffer_service.dart';

class BrowserScreen extends StatefulWidget {
  final BufferService bufferService;
  final String? initialUrl;

  const BrowserScreen({
    super.key,
    required this.bufferService,
    this.initialUrl,
  });

  @override
  State<BrowserScreen> createState() => BrowserScreenState();
}

class BrowserScreenState extends State<BrowserScreen> {
  InAppWebViewController? _webViewController;
  final TextEditingController _urlController = TextEditingController();
  double _progress = 0;
  bool _isLoading = false;
  String _currentTitle = '';
  String _currentUrl = 'https://duckduckgo.com';
  bool _canGoBack = false;
  bool _canGoForward = false;

  final Map<String, DetectedVideo> _detectedVideos = {};
  bool _showVideoDrawer = false;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.initialUrl ?? 'https://duckduckgo.com';
    _urlController.text = _currentUrl;
  }

  @override
  void didUpdateWidget(covariant BrowserScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialUrl != null && widget.initialUrl != oldWidget.initialUrl) {
      loadUrl(widget.initialUrl!);
    }
  }

  /// Ermöglicht der Navigation, den Android-Hardware-Zurück-Button abzufangen
  Future<bool> handleBackPress() async {
    if (_webViewController != null && await _webViewController!.canGoBack()) {
      await _webViewController!.goBack();
      _updateNavState();
      return true;
    }
    return false;
  }

  Future<void> _updateNavState() async {
    if (_webViewController != null && mounted) {
      final canBack = await _webViewController!.canGoBack();
      final canForward = await _webViewController!.canGoForward();
      setState(() {
        _canGoBack = canBack;
        _canGoForward = canForward;
      });
    }
  }

  void loadUrl(String input) {
    String target = input.trim();
    if (target.isEmpty) return;

    if (!target.startsWith('http://') && !target.startsWith('https://')) {
      if (target.contains('.') && !target.contains(' ')) {
        target = 'https://$target';
      } else {
        target = 'https://duckduckgo.com/?q=${Uri.encodeComponent(target)}';
      }
    }

    _urlController.text = target;
    _webViewController?.loadUrl(
      urlRequest: URLRequest(url: WebUri(target)),
    );
  }

  /// Robustes JavaScript zur Video-Erkennung & Checkbox-Overlay
  static const String _videoDetectionScript = """
    (function() {
      function resolveUrl(url) {
        if (!url) return '';
        try {
          return new URL(url, window.location.href).href;
        } catch(e) {
          return url;
        }
      }

      function initPuffer() {
        if (window.__pufferInjected) return;
        window.__pufferInjected = true;

        function reportVideo(videoSrc, title) {
          var cleanUrl = resolveUrl(videoSrc);
          if (!cleanUrl || cleanUrl.startsWith('blob:') || cleanUrl.startsWith('javascript:')) return;
          try {
            if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
              window.flutter_inappwebview.callHandler('pufferVideoDetected', {
                videoUrl: cleanUrl,
                pageUrl: window.location.href,
                pageTitle: document.title || title || 'Web-Video'
              });
            }
          } catch(e) {}
        }

        function scanPerformanceMedia() {
          try {
            var entries = window.performance.getEntriesByType('resource');
            for (var i = 0; i < entries.length; i++) {
              var name = entries[i].name;
              if (name && name.match(/\\.(mp4|webm|m4v)(\\?.*)?\$/i)) {
                reportVideo(name, document.title);
              }
            }
          } catch(e) {}
        }

        function attachCheckboxToVideo(video) {
          if (!video || video.dataset.pufferAttached === 'true') return;
          video.dataset.pufferAttached = 'true';

          var src = video.currentSrc || video.src;
          if (!src) {
            var source = video.querySelector('source');
            if (source) src = source.src;
          }

          if (src) {
            reportVideo(src, document.title);
          }

          video.addEventListener('play', function() {
            var playSrc = video.currentSrc || video.src;
            if (playSrc) reportVideo(playSrc, document.title);
            scanPerformanceMedia();
          });

          // Overlay-Container
          var wrapper = document.createElement('div');
          wrapper.className = 'puffer-overlay-checkbox-container';
          wrapper.style.cssText = 'position: absolute; top: 12px; right: 12px; z-index: 2147483647; background: rgba(18, 18, 18, 0.88); backdrop-filter: blur(8px); border: 1.5px solid #00E676; border-radius: 20px; padding: 6px 12px; display: flex; align-items: center; gap: 8px; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; font-size: 13px; font-weight: 700; color: #ffffff; box-shadow: 0 4px 14px rgba(0,0,0,0.6); user-select: none; pointer-events: auto;';

          var checkbox = document.createElement('input');
          checkbox.type = 'checkbox';
          checkbox.style.cssText = 'width: 18px; height: 18px; accent-color: #00E676; cursor: pointer; margin: 0;';
          
          var label = document.createElement('span');
          label.innerText = 'Offline-Puffer (5h)';
          label.style.cssText = 'cursor: pointer;';

          function triggerBuffer() {
            var targetSrc = video.currentSrc || video.src;
            if (!targetSrc) {
              var s = video.querySelector('source');
              if (s) targetSrc = s.src;
            }
            targetSrc = resolveUrl(targetSrc);
            if (targetSrc && window.flutter_inappwebview) {
              checkbox.disabled = true;
              label.innerText = 'Wird gepuffert...';
              window.flutter_inappwebview.callHandler('pufferTriggerDownload', {
                videoUrl: targetSrc,
                pageUrl: window.location.href,
                pageTitle: document.title || 'Video'
              });
            }
          }

          checkbox.addEventListener('change', function() {
            if (checkbox.checked) triggerBuffer();
          });
          label.addEventListener('click', function() {
            if (!checkbox.disabled && !checkbox.checked) {
              checkbox.checked = true;
              triggerBuffer();
            }
          });

          wrapper.appendChild(checkbox);
          wrapper.appendChild(label);

          var parent = video.parentElement;
          if (parent) {
            var computedPos = window.getComputedStyle(parent).position;
            if (computedPos === 'static') {
              parent.style.position = 'relative';
            }
            parent.appendChild(wrapper);
          }
        }

        function scanAllVideos() {
          var videos = document.querySelectorAll('video');
          for (var i = 0; i < videos.length; i++) {
            attachCheckboxToVideo(videos[i]);
          }
          scanPerformanceMedia();
        }

        scanAllVideos();

        var observer = new MutationObserver(function() {
          scanAllVideos();
        });
        if (document.body) {
          observer.observe(document.body, { childList: true, subtree: true });
        }
      }

      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initPuffer);
      } else {
        initPuffer();
      }
    })();
  """;

  void _onVideoDetected(Map<String, dynamic> data) {
    final videoUrl = data['videoUrl'] as String?;
    if (videoUrl == null || videoUrl.isEmpty) return;

    final pageUrl = data['pageUrl'] as String? ?? _currentUrl;
    final pageTitle = data['pageTitle'] as String? ?? _currentTitle;

    if (!_detectedVideos.containsKey(videoUrl)) {
      setState(() {
        _detectedVideos[videoUrl] = DetectedVideo(
          videoUrl: videoUrl,
          pageUrl: pageUrl,
          pageTitle: pageTitle,
          detectedAt: DateTime.now(),
        );
      });
    }
  }

  void _triggerVideoBuffer(String videoUrl, String pageUrl, String title) {
    final host = Uri.tryParse(pageUrl)?.host.replaceFirst('www.', '') ?? 'Webseite';
    widget.bufferService.bufferVideo(
      videoUrl: videoUrl,
      motherPageUrl: pageUrl,
      motherPageHost: host,
      title: title.isNotEmpty ? title : 'Video aus $host',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.downloading, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Video wird in den 5h-Puffer geladen...',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Color(0xFF1B5E20),
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detectedCount = _detectedVideos.length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          backgroundColor: const Color(0xFF1E1E1E),
          elevation: 2,
          titleSpacing: 4,
          title: Row(
            children: [
              // Browser-Verlauf: Zurück
              IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new,
                  size: 18,
                  color: _canGoBack ? Colors.white : Colors.white24,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                onPressed: _canGoBack
                    ? () async {
                        await _webViewController?.goBack();
                        _updateNavState();
                      }
                    : null,
              ),
              // Browser-Verlauf: Vorwärts
              IconButton(
                icon: Icon(
                  Icons.arrow_forward_ios,
                  size: 18,
                  color: _canGoForward ? Colors.white : Colors.white24,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                onPressed: _canGoForward
                    ? () async {
                        await _webViewController?.goForward();
                        _updateNavState();
                      }
                    : null,
              ),
              const SizedBox(width: 2),
              // Adress- und Suchleiste
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2C),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.home_outlined, size: 18, color: Colors.white70),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32),
                        onPressed: () => loadUrl('https://duckduckgo.com'),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          style: const TextStyle(fontSize: 13.5, color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'URL oder Suche...',
                            hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          ),
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.go,
                          onSubmitted: (value) => loadUrl(value),
                        ),
                      ),
                      if (_isLoading)
                        Container(
                          width: 32,
                          alignment: Alignment.center,
                          child: const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E676)),
                          ),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.arrow_forward, size: 18, color: Color(0xFF00E676)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32),
                          onPressed: () => loadUrl(_urlController.text),
                        ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20, color: Colors.white70),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36),
                onPressed: () => _webViewController?.reload(),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (_progress < 1.0)
                LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.transparent,
                  color: const Color(0xFF00E676),
                  minHeight: 2.5,
                ),
              Expanded(
                child: InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(_currentUrl)),
                  initialSettings: InAppWebViewSettings(
                    // Kern-Einstellungen für reibungsloses Laden aller Seiten:
                    domStorageEnabled: true, // Behebt das Hängenbleiben bei 5% (ermöglicht localStorage/sessionStorage)
                    databaseEnabled: true,   // Erlaubt IndexedDB
                    javaScriptEnabled: true,
                    javaScriptCanOpenWindowsAutomatically: true,
                    thirdPartyCookiesEnabled: true,
                    mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                    cacheEnabled: true,
                    clearCache: false,
                    allowsInlineMediaPlayback: true,
                    mediaPlaybackRequiresUserGesture: false,
                    useShouldOverrideUrlLoading: true,
                    supportMultipleWindows: false,
                    useWideViewPort: true,
                    loadWithOverviewMode: true,
                    supportZoom: true,
                    builtInZoomControls: true,
                    displayZoomControls: false,
                    // Modernes Standard-Chrome-User-Agent verhindert Bot-/WebView-Blocks
                    userAgent: 'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
                  ),
                  initialUserScripts: UnmodifiableListView([
                    UserScript(
                      source: _videoDetectionScript,
                      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
                    ),
                  ]),
                  onWebViewCreated: (controller) {
                    _webViewController = controller;

                    controller.addJavaScriptHandler(
                      handlerName: 'pufferVideoDetected',
                      callback: (args) {
                        if (args.isNotEmpty && args[0] is Map) {
                          final data = Map<String, dynamic>.from(args[0] as Map);
                          _onVideoDetected(data);
                        }
                      },
                    );

                    controller.addJavaScriptHandler(
                      handlerName: 'pufferTriggerDownload',
                      callback: (args) {
                        if (args.isNotEmpty && args[0] is Map) {
                          final data = Map<String, dynamic>.from(args[0] as Map);
                          final videoUrl = data['videoUrl'] as String? ?? '';
                          final pageUrl = data['pageUrl'] as String? ?? _currentUrl;
                          final title = data['pageTitle'] as String? ?? _currentTitle;
                          _triggerVideoBuffer(videoUrl, pageUrl, title);
                        }
                      },
                    );
                  },
                  shouldOverrideUrlLoading: (controller, navigationAction) async {
                    final uri = navigationAction.request.url;
                    if (uri != null) {
                      final scheme = uri.scheme.toLowerCase();
                      if (!['http', 'https', 'file', 'data', 'about', 'javascript'].contains(scheme)) {
                        return NavigationActionPolicy.CANCEL;
                      }
                    }
                    return NavigationActionPolicy.ALLOW;
                  },
                  onReceivedServerTrustAuthRequest: (controller, challenge) async {
                    return ServerTrustAuthResponse(action: ServerTrustAuthResponseAction.PROCEED);
                  },
                  shouldInterceptRequest: (controller, request) async {
                    final url = request.url.toString();
                    final lower = url.toLowerCase();
                    if ((lower.contains('.mp4') || lower.contains('.webm') || lower.contains('.m4v')) &&
                        !lower.startsWith('blob:') &&
                        !lower.startsWith('data:')) {
                      _onVideoDetected({
                        'videoUrl': url,
                        'pageUrl': _currentUrl,
                        'pageTitle': _currentTitle,
                      });
                    }
                    return null;
                  },
                  onLoadStart: (controller, url) {
                    setState(() {
                      _isLoading = true;
                      _currentUrl = url?.toString() ?? '';
                      _urlController.text = _currentUrl;
                      _detectedVideos.clear();
                    });
                    _updateNavState();
                  },
                  onLoadStop: (controller, url) async {
                    setState(() {
                      _isLoading = false;
                      _currentUrl = url?.toString() ?? '';
                    });
                    final title = await controller.getTitle();
                    if (title != null) {
                      _currentTitle = title;
                    }
                    _updateNavState();
                    await controller.evaluateJavascript(source: _videoDetectionScript);
                  },
                  onUpdateVisitedHistory: (controller, url, isReload) {
                    _updateNavState();
                  },
                  onProgressChanged: (controller, progress) {
                    setState(() {
                      _progress = progress / 100.0;
                    });
                  },
                  onTitleChanged: (controller, title) {
                    if (title != null) {
                      _currentTitle = title;
                    }
                  },
                ),
              ),
            ],
          ),

          // Schwebender Video-Erkennungs-Banner am unteren Bildschirmrand
          if (detectedCount > 0)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF00E676).withOpacity(0.4), width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 4)),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E676).withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.videocam, color: Color(0xFF00E676), size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '$detectedCount Video${detectedCount > 1 ? "s" : ""} erkannt',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                _showVideoDrawer ? Icons.expand_less : Icons.expand_more,
                                color: Colors.white70,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                setState(() {
                                  _showVideoDrawer = !_showVideoDrawer;
                                });
                              },
                            ),
                          ],
                        ),

                        if (_showVideoDrawer) ...[
                          const Divider(color: Colors.white12, height: 16),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 220),
                            child: ListView(
                              shrinkWrap: true,
                              children: _detectedVideos.values.map((v) {
                                final existing = widget.bufferService.findItemByUrl(v.videoUrl);
                                final isBuffered = existing?.isOfflineAvailable ?? false;
                                final isDownloading = existing?.status == VideoStatus.downloading;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2C2C2C),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Checkbox(
                                        value: isBuffered || isDownloading,
                                        activeColor: const Color(0xFF00E676),
                                        checkColor: Colors.black,
                                        onChanged: isBuffered || isDownloading
                                            ? null
                                            : (bool? checked) {
                                                if (checked == true) {
                                                  _triggerVideoBuffer(v.videoUrl, v.pageUrl, v.pageTitle);
                                                }
                                              },
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              v.pageTitle.isNotEmpty ? v.pageTitle : 'Web-Video',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            if (isDownloading)
                                              Text(
                                                'Wird gepuffert... ${(existing!.progress * 100).toInt()}%',
                                                style: const TextStyle(
                                                  color: Color(0xFF00E676),
                                                  fontSize: 11,
                                                ),
                                              )
                                            else if (isBuffered)
                                              Text(
                                                'Offline bereit (${existing!.remainingFormatted})',
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 11,
                                                ),
                                              )
                                            else
                                              const Text(
                                                'Checkbox antippen zum 5h-Puffern',
                                                style: TextStyle(
                                                  color: Colors.white38,
                                                  fontSize: 11,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (isDownloading)
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            value: existing!.progress > 0 ? existing.progress : null,
                                            strokeWidth: 2,
                                            color: const Color(0xFF00E676),
                                          ),
                                        )
                                      else if (isBuffered)
                                        const Icon(Icons.check_circle, color: Color(0xFF00E676), size: 20)
                                      else
                                        IconButton(
                                          icon: const Icon(Icons.download, color: Color(0xFF00E676), size: 20),
                                          onPressed: () {
                                            _triggerVideoBuffer(v.videoUrl, v.pageUrl, v.pageTitle);
                                          },
                                        ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class DetectedVideo {
  final String videoUrl;
  final String pageUrl;
  final String pageTitle;
  final DateTime detectedAt;

  DetectedVideo({
    required this.videoUrl,
    required this.pageUrl,
    required this.pageTitle,
    required this.detectedAt,
  });
}
