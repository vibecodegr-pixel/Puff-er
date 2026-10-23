import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// Prüft, ob eine URL zu einem bekannten Werbe- oder Tracking-Netzwerk gehört
  static bool isAdUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('doubleclick.net') ||
        lower.contains('googlesyndication.com') ||
        lower.contains('googleads') ||
        lower.contains('imasdk.googleapis.com') ||
        lower.contains('adservice.google') ||
        lower.contains('amazon-adsystem') ||
        lower.contains('adnxs.com') ||
        lower.contains('pubmatic.com') ||
        lower.contains('rubiconproject.com') ||
        lower.contains('scorecardresearch.com') ||
        lower.contains('taboola.com') ||
        lower.contains('outbrain.com') ||
        lower.contains('/pagead/') ||
        lower.contains('/video_ads/') ||
        lower.contains('vmap') ||
        lower.contains('ad_type=') ||
        lower.contains('ad_tag=');
  }

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

  /// Injektionsskript mit Anti-Werbung, Teaser-Erkennung & Feed-Direkt-Puffer-Buttons
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

      function isAdSource(url) {
        if (!url) return false;
        var lower = url.toLowerCase();
        return lower.indexOf('doubleclick') !== -1 ||
               lower.indexOf('googleads') !== -1 ||
               lower.indexOf('googlesyndication') !== -1 ||
               lower.indexOf('imasdk') !== -1 ||
               lower.indexOf('/pagead/') !== -1 ||
               lower.indexOf('vmap') !== -1 ||
               lower.indexOf('/video_ads/') !== -1;
      }

      function initPuffer() {
        if (window.__pufferInjected) return;
        window.__pufferInjected = true;

        function reportVideo(videoSrc, title, isPreview, duration) {
          var cleanUrl = resolveUrl(videoSrc);
          if (!cleanUrl || cleanUrl.startsWith('blob:') || cleanUrl.startsWith('javascript:')) return;
          if (isAdSource(cleanUrl)) return; // Werbevideos ignorieren!

          try {
            if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
              window.flutter_inappwebview.callHandler('pufferVideoDetected', {
                videoUrl: cleanUrl,
                pageUrl: window.location.href,
                pageTitle: document.title || title || 'Web-Video',
                isPreview: !!isPreview,
                duration: duration || 0
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
                if (!isAdSource(name)) {
                  var isPrev = name.toLowerCase().indexOf('preview') !== -1 || name.toLowerCase().indexOf('teaser') !== -1;
                  reportVideo(name, document.title, isPrev, 0);
                }
              }
            }
          } catch(e) {}
        }

        // 1. Direkt-Puffer-Buttons auf Video-Karten / Thumbnails im Feed einbinden
        function attachFeedQuickBufferButtons() {
          var links = document.querySelectorAll('a[href*="/watch"], a[href*="/video/"], a[href*="/v/"], a[href*="watch?v="]');
          for (var i = 0; i < links.length; i++) {
            var a = links[i];
            if (a.dataset.pufferCardAttached === 'true') continue;

            // Prüfen, ob der Link ein Vorschaubild oder ein Video enthält
            var hasMedia = a.querySelector('img, video, canvas');
            if (!hasMedia && a.offsetHeight < 45) continue;
            a.dataset.pufferCardAttached = 'true';

            var targetUrl = resolveUrl(a.href);
            if (!targetUrl || targetUrl.startsWith('javascript:')) continue;

            var cardBtn = document.createElement('div');
            cardBtn.className = 'puffer-card-quick-btn';
            cardBtn.style.cssText = 'position: absolute; bottom: 8px; right: 8px; z-index: 99999; background: rgba(0, 230, 118, 0.95); color: #000; padding: 5px 10px; border-radius: 14px; font-size: 11px; font-weight: 800; cursor: pointer; box-shadow: 0 3px 10px rgba(0,0,0,0.6); pointer-events: auto; display: flex; align-items: center; gap: 4px;';
            cardBtn.innerHTML = '<span>⚡ In Puffer</span>';

            (function(url, title, btn) {
              btn.addEventListener('click', function(e) {
                e.preventDefault();
                e.stopPropagation();
                btn.style.background = '#666';
                btn.innerHTML = '<span>Lade...</span>';
                if (window.flutter_inappwebview) {
                  window.flutter_inappwebview.callHandler('pufferOpenAndBufferTarget', {
                    targetUrl: url,
                    pageTitle: title
                  });
                }
              });
            })(targetUrl, a.innerText || a.getAttribute('title') || 'Video', cardBtn);

            var comp = window.getComputedStyle(a).position;
            if (comp === 'static') {
              a.style.position = 'relative';
            }
            a.appendChild(cardBtn);
          }
        }

        // 2. Videos auf der Seite scannen & Checkbox montieren
        function attachCheckboxToVideo(video) {
          if (!video || video.dataset.pufferAttached === 'true') return;
          video.dataset.pufferAttached = 'true';

          var src = video.currentSrc || video.src;
          if (!src) {
            var source = video.querySelector('source');
            if (source) src = source.src;
          }

          var isLoop = video.loop;
          var isMuted = video.muted;
          var dur = video.duration || 0;
          var isPreview = (isLoop && isMuted && dur > 0 && dur <= 25) || (src && (src.indexOf('preview') !== -1 || src.indexOf('teaser') !== -1));

          if (src && !isAdSource(src)) {
            reportVideo(src, document.title, isPreview, dur);
          }

          video.addEventListener('play', function() {
            var playSrc = video.currentSrc || video.src;
            if (playSrc && !isAdSource(playSrc)) {
              var pDur = video.duration || 0;
              var pPrev = (video.loop && video.muted && pDur > 0 && pDur <= 25);
              reportVideo(playSrc, document.title, pPrev, pDur);
            }
            scanPerformanceMedia();
          });

          // Overlay-Checkbox über dem Video
          var wrapper = document.createElement('div');
          wrapper.className = 'puffer-overlay-checkbox-container';
          wrapper.style.cssText = 'position: absolute; top: 12px; right: 12px; z-index: 2147483647; background: rgba(18, 18, 18, 0.88); backdrop-filter: blur(8px); border: 1.5px solid #00E676; border-radius: 20px; padding: 6px 12px; display: flex; align-items: center; gap: 8px; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; font-size: 13px; font-weight: 700; color: #ffffff; box-shadow: 0 4px 14px rgba(0,0,0,0.6); user-select: none; pointer-events: auto;';

          var checkbox = document.createElement('input');
          checkbox.type = 'checkbox';
          checkbox.style.cssText = 'width: 18px; height: 18px; accent-color: #00E676; cursor: pointer; margin: 0;';
          
          var label = document.createElement('span');
          label.innerText = isPreview ? 'Vorschau-Puffer' : 'Offline-Puffer (5h)';
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

        function scanAll() {
          var videos = document.querySelectorAll('video');
          for (var i = 0; i < videos.length; i++) {
            attachCheckboxToVideo(videos[i]);
          }
          attachFeedQuickBufferButtons();
          scanPerformanceMedia();
        }

        scanAll();

        var observer = new MutationObserver(function() {
          scanAll();
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
    if (isAdUrl(videoUrl)) return; // Werbe-Videos strikt verwerfen!

    final pageUrl = data['pageUrl'] as String? ?? _currentUrl;
    final pageTitle = data['pageTitle'] as String? ?? _currentTitle;
    final isPreview = data['isPreview'] as bool? ?? false;
    final duration = (data['duration'] is num) ? (data['duration'] as num).toDouble() : null;

    if (!_detectedVideos.containsKey(videoUrl)) {
      setState(() {
        _detectedVideos[videoUrl] = DetectedVideo(
          videoUrl: videoUrl,
          pageUrl: pageUrl,
          pageTitle: pageTitle,
          detectedAt: DateTime.now(),
          isPreview: isPreview,
          duration: duration,
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
    // Sortiere Hauptvideos vor Vorschau-Videos
    final sortedVideos = _detectedVideos.values.toList()
      ..sort((a, b) {
        if (!a.isPreview && b.isPreview) return -1;
        if (a.isPreview && !b.isPreview) return 1;
        return 0;
      });

    final detectedCount = sortedVideos.length;

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
                    domStorageEnabled: true,
                    databaseEnabled: true,
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

                    // Schnell-Puffer-Knopf aus Vorschaukarten im Feed
                    controller.addJavaScriptHandler(
                      handlerName: 'pufferOpenAndBufferTarget',
                      callback: (args) {
                        if (args.isNotEmpty && args[0] is Map) {
                          final data = Map<String, dynamic>.from(args[0] as Map);
                          final targetUrl = data['targetUrl'] as String? ?? '';
                          if (targetUrl.isNotEmpty) {
                            loadUrl(targetUrl);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Row(
                                  children: [
                                    Icon(Icons.bolt, color: Color(0xFF00E676), size: 20),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Öffne Video ohne Werbung zum Direkt-Puffern...',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: Color(0xFF1B5E20),
                                duration: Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
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

                    // 1. INTEGRIERTER WERBEBLOCKER: Pre-Roll Video-Ads nativ blockieren!
                    if (isAdUrl(url)) {
                      return WebResourceResponse(
                        contentType: 'text/plain',
                        data: Uint8List(0),
                        statusCode: 204,
                        reasonPhrase: 'No Content',
                      );
                    }

                    // 2. Echte Video-Streams abfangen
                    final lower = url.toLowerCase();
                    if ((lower.contains('.mp4') || lower.contains('.webm') || lower.contains('.m4v')) &&
                        !lower.startsWith('blob:') &&
                        !lower.startsWith('data:')) {
                      final isPrev = lower.contains('preview') || lower.contains('teaser') || lower.contains('hover');
                      _onVideoDetected({
                        'videoUrl': url,
                        'pageUrl': _currentUrl,
                        'pageTitle': _currentTitle,
                        'isPreview': isPrev,
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
                              child: const Icon(Icons.shield, color: Color(0xFF00E676), size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$detectedCount Video${detectedCount > 1 ? "s" : ""} erkannt',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const Text(
                                    '🛡️ Werbefilter aktiv',
                                    style: TextStyle(color: Color(0xFF00E676), fontSize: 11),
                                  ),
                                ],
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
                            constraints: const BoxConstraints(maxHeight: 240),
                            child: ListView(
                              shrinkWrap: true,
                              children: sortedVideos.map((v) {
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
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: v.isPreview
                                                        ? Colors.blueGrey.withOpacity(0.3)
                                                        : const Color(0xFF00E676).withOpacity(0.18),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    v.isPreview ? '🎞️ Vorschau' : '🎬 Hauptvideo',
                                                    style: TextStyle(
                                                      color: v.isPreview ? Colors.white70 : const Color(0xFF00E676),
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    v.pageTitle.isNotEmpty ? v.pageTitle : 'Web-Video',
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 3),
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
                                              Text(
                                                v.isPreview
                                                    ? 'Kurzer Vorschau-Teaser (antippen zum Puffern)'
                                                    : 'Vollständiges Video (antippen zum Puffern)',
                                                style: const TextStyle(
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
  final bool isPreview;
  final double? duration;

  DetectedVideo({
    required this.videoUrl,
    required this.pageUrl,
    required this.pageTitle,
    required this.detectedAt,
    this.isPreview = false,
    this.duration,
  });
}
