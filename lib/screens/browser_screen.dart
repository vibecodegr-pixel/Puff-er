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

  /// Erkennt interne Video-Transport-Chunks und Segmente (z.B. beim Vor- und Zurückspulen).
  /// Verhindert, dass für jeden Spulschritt ein einzelnes 2-Sekunden-Snippet als Video erkannt wird!
  static bool isSegmentChunk(String url) {
    final lower = url.toLowerCase();
    return lower.contains('/seg-') ||
        lower.contains('/segment') ||
        lower.contains('frag-') ||
        lower.contains('fragment') ||
        lower.contains('.ts') ||
        lower.contains('.m4s') ||
        lower.contains('.m4a') ||
        lower.contains('sq/') ||
        lower.contains('/chunks/') ||
        lower.contains('range=') ||
        lower.contains('bytes=') ||
        lower.contains('start=') ||
        lower.contains('offset=') ||
        lower.contains('&t=') ||
        lower.contains('?t=') ||
        (lower.contains('.m3u8') && (lower.contains('seg-') || lower.contains('chunklist')));
  }

  /// Bereinigt und normalisiert Video-URLs von Spul-, Byte-Range- und Zeitparametern,
  /// sodass mehrere Anfragen desselben Videos zu einer einzigen Master-URL zusammengeführt werden.
  static String normalizeVideoUrl(String rawUrl) {
    try {
      final uri = Uri.parse(rawUrl);
      final queryParams = Map<String, String>.from(uri.queryParameters);
      const stripKeys = [
        'start',
        'begin',
        't',
        'time',
        'range',
        'bytes',
        'offset',
        'ir',
        'pos',
        'viewkey_t'
      ];
      for (final key in stripKeys) {
        queryParams.remove(key);
      }
      final normalized = uri.replace(
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );
      return normalized.toString();
    } catch (_) {
      return rawUrl;
    }
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

  /// Injektionsskript mit Anti-Werbung, Teaser-Erkennung, Pornhub/Stream-Master-Extraktion & Feed-Direkt-Puffer-Buttons
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

      function cleanVideoUrl(rawUrl) {
        try {
          var u = new URL(rawUrl, window.location.href);
          var removeParams = ['start', 'begin', 't', 'time', 'range', 'bytes', 'offset', 'ir', 'pos'];
          for (var i = 0; i < removeParams.length; i++) {
            u.searchParams.delete(removeParams[i]);
          }
          return u.href;
        } catch(e) {
          return rawUrl;
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

      function isSegment(url) {
        if (!url) return false;
        var u = url.toLowerCase();
        return u.indexOf('/seg-') !== -1 ||
               u.indexOf('/segment') !== -1 ||
               u.indexOf('frag-') !== -1 ||
               u.indexOf('fragment') !== -1 ||
               u.indexOf('.ts') !== -1 ||
               u.indexOf('.m4s') !== -1 ||
               u.indexOf('.m4a') !== -1 ||
               u.indexOf('sq/') !== -1 ||
               u.indexOf('/chunks/') !== -1 ||
               u.indexOf('range=') !== -1 ||
               u.indexOf('bytes=') !== -1 ||
               u.indexOf('start=') !== -1 ||
               u.indexOf('&t=') !== -1 ||
               u.indexOf('?t=') !== -1 ||
               u.indexOf('offset=') !== -1;
      }

      function reportVideo(videoSrc, title, isPreview, duration, isMaster, quality) {
        var cleanUrl = resolveUrl(videoSrc);
        if (!cleanUrl || cleanUrl.startsWith('blob:') || cleanUrl.startsWith('javascript:')) return;
        if (isAdSource(cleanUrl)) return;
        if (!isMaster && isSegment(cleanUrl)) return; // Transport Chunks & Seek-Segmente NIEMALS melden!

        cleanUrl = cleanVideoUrl(cleanUrl);

        try {
          if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
            window.flutter_inappwebview.callHandler('pufferVideoDetected', {
              videoUrl: cleanUrl,
              pageUrl: window.location.href,
              pageTitle: title || document.title || 'Web-Video',
              isPreview: !!isPreview,
              duration: duration || 0,
              isMaster: !!isMaster,
              quality: quality || ''
            });
          }
        } catch(e) {}
      }

      function parseAndReportDefs(defs) {
        if (!Array.isArray(defs)) return;
        for (var i = 0; i < defs.length; i++) {
          var d = defs[i];
          if (!d) continue;
          var vUrl = d.videoUrl || d.url;
          if (!vUrl || typeof vUrl !== 'string') continue;
          vUrl = vUrl.replace(/\\\\\\//g, '/').replace(/\\//g, '/');
          if (isAdSource(vUrl) || isSegment(vUrl)) continue;

          var format = (d.format || '').toLowerCase();
          var qual = d.quality;
          if (Array.isArray(qual)) qual = qual.join('/');
          var qStr = qual ? ('' + qual) : '';
          if (qStr && qStr.indexOf('p') === -1 && !isNaN(qStr)) qStr += 'p';

          var title = document.title || 'Hauptvideo';
          if (format === 'mp4' || vUrl.indexOf('.mp4') !== -1) {
            reportVideo(vUrl, title, false, 0, true, qStr || 'MP4');
          } else if (format === 'hls' || vUrl.indexOf('.m3u8') !== -1) {
            reportVideo(vUrl, title, false, 0, true, qStr ? (qStr + ' HLS') : 'HLS');
          }
        }
      }

      function extractMediaDefinitions() {
        try {
          // 1. window Globals (flashvars_..., player_..., media_0, etc.)
          for (var key in window) {
            if (key.indexOf('flashvars') !== -1 || key.indexOf('player_mp4') !== -1 || key === 'media_0') {
              try {
                var obj = window[key];
                if (obj && obj.mediaDefinitions) {
                  parseAndReportDefs(obj.mediaDefinitions);
                }
              } catch(e) {}
            }
          }

          // 2. <script> Tags nach JSON & mediaDefinitions durchsuchen
          var scripts = document.getElementsByTagName('script');
          for (var s = 0; s < scripts.length; s++) {
            var text = scripts[s].textContent || '';
            if (text.indexOf('mediaDefinitions') !== -1) {
              var match = text.match(/mediaDefinitions\\s*:\\s*(\\[\\s*\\{[\\s\\S]*?\\}\\s*\\])/);
              if (match && match[1]) {
                try {
                  var parsed = JSON.parse(match[1]);
                  if (Array.isArray(parsed)) {
                    parseAndReportDefs(parsed);
                  }
                } catch(e) {
                  extractUrlsFromScriptText(text);
                }
              } else {
                extractUrlsFromScriptText(text);
              }
            } else if (text.indexOf('flashvars_') !== -1) {
              extractUrlsFromScriptText(text);
            }
          }
        } catch(e) {}
      }

      function extractUrlsFromScriptText(text) {
        try {
          var regex = /"videoUrl"\\s*:\\s*"([^"]+)"/g;
          var m;
          while ((m = regex.exec(text)) !== null) {
            var u = m[1].replace(/\\\\\\//g, '/').replace(/\\//g, '/');
            if (u && !isAdSource(u) && !isSegment(u)) {
              reportVideo(u, document.title || 'Hauptvideo', false, 0, true, 'HD');
            }
          }
        } catch(e) {}
      }

      // 3. Network Fetch / XHR Interception für dynamische Video-APIs (z.B. /video/get_media)
      if (!window.__pufferNetworkIntercepted) {
        window.__pufferNetworkIntercepted = true;
        var origFetch = window.fetch;
        if (origFetch) {
          window.fetch = function() {
            return origFetch.apply(this, arguments).then(function(res) {
              try {
                var url = res.url || '';
                if (url.indexOf('get_media') !== -1 || url.indexOf('playback') !== -1 || url.indexOf('playlist') !== -1) {
                  res.clone().json().then(function(data) {
                    if (data && data.mediaDefinitions) {
                      parseAndReportDefs(data.mediaDefinitions);
                    }
                  }).catch(function(){});
                }
              } catch(e) {}
              return res;
            });
          };
        }

        var origXhrOpen = XMLHttpRequest.prototype.open;
        XMLHttpRequest.prototype.open = function(method, url) {
          this.__pufferUrl = url;
          return origXhrOpen.apply(this, arguments);
        };
        var origXhrSend = XMLHttpRequest.prototype.send;
        XMLHttpRequest.prototype.send = function() {
          this.addEventListener('load', function() {
            try {
              var url = this.__pufferUrl || '';
              if (url.indexOf('get_media') !== -1 || url.indexOf('playback') !== -1 || url.indexOf('playlist') !== -1) {
                var data = JSON.parse(this.responseText);
                if (data && data.mediaDefinitions) {
                  parseAndReportDefs(data.mediaDefinitions);
                }
              }
            } catch(e) {}
          });
          return origXhrSend.apply(this, arguments);
        };
      }

      function initPuffer() {
        if (window.__pufferInjected) {
          extractMediaDefinitions();
          return;
        }
        window.__pufferInjected = true;

        function scanPerformanceMedia() {
          try {
            var entries = window.performance.getEntriesByType('resource');
            for (var i = 0; i < entries.length; i++) {
              var name = entries[i].name;
              if (!name || isAdSource(name) || isSegment(name)) continue;
              if (name.match(/\\.(mp4|webm|m4v)(\\?.*)?\$/i) || name.match(/\\.m3u8(\\?.*)?\$/i)) {
                var isPrev = name.toLowerCase().indexOf('preview') !== -1 || name.toLowerCase().indexOf('teaser') !== -1;
                reportVideo(name, document.title, isPrev, 0, false, '');
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

          if (src && !isAdSource(src) && !isSegment(src)) {
            reportVideo(src, document.title, isPreview, dur, false, '');
          }

          video.addEventListener('play', function() {
            extractMediaDefinitions();
            var playSrc = video.currentSrc || video.src;
            if (playSrc && !isAdSource(playSrc) && !isSegment(playSrc)) {
              var pDur = video.duration || 0;
              var pPrev = (video.loop && video.muted && pDur > 0 && pDur <= 25);
              reportVideo(playSrc, document.title, pPrev, pDur, false, '');
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
          extractMediaDefinitions();
          var videos = document.querySelectorAll('video');
          for (var i = 0; i < videos.length; i++) {
            attachCheckboxToVideo(videos[i]);
          }
          attachFeedQuickBufferButtons();
          scanPerformanceMedia();
        }

        scanAll();

        // Regelmäßiger Scan in den ersten Sekunden nach Laden (für dynamische Player)
        var scanCount = 0;
        var intervalId = setInterval(function() {
          scanAll();
          scanCount++;
          if (scanCount >= 6) clearInterval(intervalId);
        }, 1500);

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
    final rawUrl = data['videoUrl'] as String?;
    if (rawUrl == null || rawUrl.isEmpty) return;
    if (isAdUrl(rawUrl)) return; // Werbe-Videos strikt verwerfen!

    final isMaster = data['isMaster'] as bool? ?? false;
    // Segmente und Seek-Chunks verwerfen (außer es ist ein expliziter Master-Stream)
    if (!isMaster && isSegmentChunk(rawUrl)) return;

    final videoUrl = normalizeVideoUrl(rawUrl);
    final pageUrl = data['pageUrl'] as String? ?? _currentUrl;
    final pageTitle = data['pageTitle'] as String? ?? _currentTitle;
    final isPreview = data['isPreview'] as bool? ?? false;
    final duration = (data['duration'] is num) ? (data['duration'] as num).toDouble() : null;
    final quality = data['quality'] as String? ?? '';

    if (!_detectedVideos.containsKey(videoUrl)) {
      final item = DetectedVideo(
        videoUrl: videoUrl,
        pageUrl: pageUrl,
        pageTitle: pageTitle,
        detectedAt: DateTime.now(),
        isPreview: isPreview,
        duration: duration,
        isProbingSize: true,
        isMaster: isMaster,
        quality: quality,
      );
      setState(() {
        _detectedVideos[videoUrl] = item;
      });
      _probeVideoSize(item);
    } else {
      final existing = _detectedVideos[videoUrl]!;
      if (isMaster && !existing.isMaster) {
        setState(() {
          existing.isMaster = true;
          if (quality.isNotEmpty) existing.quality = quality;
        });
      }
    }
  }

  void _probeVideoSize(DetectedVideo item) async {
    final size = await widget.bufferService.probeVideoSize(
      videoUrl: item.videoUrl,
      motherPageUrl: item.pageUrl,
    );
    if (mounted && _detectedVideos.containsKey(item.videoUrl)) {
      setState(() {
        item.fileSizeBytes = size;
        item.isProbingSize = false;
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
    int qualityRank(String q) {
      if (q.contains('1080')) return 1080;
      if (q.contains('720')) return 720;
      if (q.contains('480')) return 480;
      if (q.contains('360')) return 360;
      if (q.contains('240')) return 240;
      return 0;
    }

    // Sortiere: Master-Videos (aus mediaDefinitions / Stream-Manifest) immer ganz nach oben!
    // Danach nach Dateigröße (größtes Video zuerst!), dann Nicht-Vorschau vor Vorschau.
    final sortedVideos = _detectedVideos.values.toList()
      ..sort((a, b) {
        if (a.isMaster && !b.isMaster) return -1;
        if (!a.isMaster && b.isMaster) return 1;

        if (a.isMaster && b.isMaster) {
          final qA = qualityRank(a.quality);
          final qB = qualityRank(b.quality);
          if (qA != qB) return qB.compareTo(qA);
        }

        final aSize = a.fileSizeBytes ?? -1;
        final bSize = b.fileSizeBytes ?? -1;
        if (aSize != bSize) {
          return bSize.compareTo(aSize); // Größtes Video ganz oben!
        }
        if (!a.isPreview && b.isPreview) return -1;
        if (a.isPreview && !b.isPreview) return 1;
        return b.detectedAt.compareTo(a.detectedAt);
      });

    final detectedCount = sortedVideos.length;
    final maxSizeBytes = sortedVideos.map((v) => v.fileSizeBytes ?? 0).fold(0, (prev, s) => s > prev ? s : prev);
    final largestVideo = sortedVideos.isNotEmpty ? sortedVideos.first : null;

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

                    // 2. Transport-Chunks & Segmente beim Spulen verwerfen (kein Spam!)
                    if (isSegmentChunk(url)) {
                      return null; // Lässt das interne Abspielen im Web-Player zu, aber erzeugt kein Video-Item
                    }

                    // 3. Echte Video-Streams abfangen (MP4, WEBM, M4V, M3U8 Master)
                    final lower = url.toLowerCase();
                    if ((lower.contains('.mp4') ||
                            lower.contains('.webm') ||
                            lower.contains('.m4v') ||
                            lower.contains('.m3u8')) &&
                        !lower.startsWith('blob:') &&
                        !lower.startsWith('data:')) {
                      final isPrev = lower.contains('preview') ||
                          lower.contains('teaser') ||
                          lower.contains('hover');
                      _onVideoDetected({
                        'videoUrl': url,
                        'pageUrl': _currentUrl,
                        'pageTitle': _currentTitle,
                        'isPreview': isPrev,
                        'isMaster': false,
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
          // Schwebender Video-Erkennungs- und Download-Banner am unteren Bildschirmrand
          AnimatedBuilder(
            animation: widget.bufferService,
            builder: (context, _) {
              final activeDownloads = widget.bufferService.activeDownloads;
              if (detectedCount == 0 && activeDownloads.isEmpty) {
                return const SizedBox.shrink();
              }

              final primaryDownload = activeDownloads.isNotEmpty ? activeDownloads.first : null;
              final isLargestBuffered = largestVideo != null && (widget.bufferService.findItemByUrl(largestVideo.videoUrl)?.isOfflineAvailable ?? false);
              final isLargestDownloading = largestVideo != null && (widget.bufferService.findItemByUrl(largestVideo.videoUrl)?.status == VideoStatus.downloading);

              return Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E).withOpacity(0.96),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: activeDownloads.isNotEmpty
                          ? const Color(0xFF00E676)
                          : const Color(0xFF00E676).withOpacity(0.4),
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(color: Colors.black87, blurRadius: 18, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 1. Live-Download-Fortschrittsbalken falls ein Video gerade gepuffert wird
                          if (primaryDownload != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1B5E20).withOpacity(0.35),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF00E676).withOpacity(0.4)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.downloading, color: Color(0xFF00E676), size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          primaryDownload.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        primaryDownload.progress >= 0
                                            ? '${(primaryDownload.progress * 100).toInt()}%'
                                            : 'Lädt...',
                                        style: const TextStyle(
                                          color: Color(0xFF00E676),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: primaryDownload.progress >= 0 ? primaryDownload.progress : null,
                                      minHeight: 6,
                                      backgroundColor: Colors.white12,
                                      valueColor: const AlwaysStoppedAnimation(Color(0xFF00E676)),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        primaryDownload.downloadProgressText,
                                        style: const TextStyle(
                                          color: Color(0xFF00E676),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        primaryDownload.downloadEtaText,
                                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // 2. Zusammenfassungsleiste der erkannten Videos dieser Seite
                          if (detectedCount > 0)
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _showVideoDrawer = !_showVideoDrawer;
                                });
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00E676).withOpacity(0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.video_library_outlined, color: Color(0xFF00E676), size: 18),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '$detectedCount Video${detectedCount > 1 ? "s" : ""} auf dieser Seite',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                          if (largestVideo?.fileSizeBytes != null)
                                            Text(
                                              '🏆 Größtes: ${largestVideo!.formattedSize}',
                                              style: const TextStyle(color: Color(0xFF00E676), fontSize: 11.5, fontWeight: FontWeight.w600),
                                            )
                                          else
                                            const Text(
                                              '🛡️ Größen werden ermittelt...',
                                              style: TextStyle(color: Colors.white54, fontSize: 11),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (largestVideo != null && !isLargestBuffered && !isLargestDownloading)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 6),
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF00E676),
                                            foregroundColor: Colors.black,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          ),
                                          icon: const Icon(Icons.bolt, size: 15),
                                          label: Text(
                                            largestVideo.fileSizeBytes != null
                                                ? 'Größtes (${largestVideo.formattedSize})'
                                                : 'Größtes laden',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                          onPressed: () {
                                            _triggerVideoBuffer(largestVideo.videoUrl, largestVideo.pageUrl, largestVideo.pageTitle);
                                          },
                                        ),
                                      ),
                                    Icon(
                                      _showVideoDrawer ? Icons.expand_less : Icons.expand_more,
                                      color: Colors.white70,
                                      size: 24,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // 3. Ausklappbare Liste aller Videos mit Dateigröße & Scroll-Funktion
                          if (_showVideoDrawer && detectedCount > 0) ...[
                            const Divider(color: Colors.white12, height: 16),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Tippe auf das gewünschte Video zum Puffern:',
                                style: TextStyle(color: Colors.white54, fontSize: 11.5),
                              ),
                            ),
                            const SizedBox(height: 6),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: MediaQuery.of(context).size.height * 0.42,
                              ),
                              child: ListView(
                                shrinkWrap: true,
                                children: sortedVideos.map((v) {
                                  final existing = widget.bufferService.findItemByUrl(v.videoUrl);
                                  final isBuffered = existing?.isOfflineAvailable ?? false;
                                  final isDownloading = existing?.status == VideoStatus.downloading;
                                  final isLargest = maxSizeBytes > 0 && v.fileSizeBytes == maxSizeBytes;

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2C2C2C),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isLargest
                                            ? const Color(0xFF00E676).withOpacity(0.55)
                                            : Colors.white10,
                                        width: isLargest ? 1.5 : 1.0,
                                      ),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(10),
                                        onTap: isBuffered || isDownloading
                                            ? null
                                            : () {
                                                _triggerVideoBuffer(v.videoUrl, v.pageUrl, v.pageTitle);
                                              },
                                        child: Padding(
                                          padding: const EdgeInsets.all(10),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  // Badge: Master-Stream vs Größtes vs Vorschau vs Snippet
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: v.isMaster || isLargest
                                                          ? const Color(0xFF00E676)
                                                          : v.isPreview || (v.fileSizeBytes != null && v.fileSizeBytes! < 1.5 * 1024 * 1024)
                                                              ? Colors.amber.withOpacity(0.2)
                                                              : Colors.white12,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      v.isMaster
                                                          ? (v.quality.isNotEmpty ? '🏆 Hauptvideo (${v.quality})' : '🏆 Hauptvideo')
                                                          : isLargest
                                                              ? '🏆 Größte Datei'
                                                              : v.isPreview
                                                                  ? '🎞️ Vorschau'
                                                                  : (v.fileSizeBytes != null && v.fileSizeBytes! < 1.5 * 1024 * 1024)
                                                                      ? '⚠️ Klein / Snippet'
                                                                      : '🎬 Video',
                                                      style: TextStyle(
                                                        color: v.isMaster || isLargest
                                                            ? Colors.black
                                                            : v.isPreview || (v.fileSizeBytes != null && v.fileSizeBytes! < 1.5 * 1024 * 1024)
                                                                ? Colors.amberAccent
                                                                : Colors.white70,
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  // Prominente Dateigrößen-Anzeige
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: isLargest
                                                          ? const Color(0xFF00E676).withOpacity(0.18)
                                                          : const Color(0xFF1E1E1E),
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(
                                                        color: isLargest
                                                            ? const Color(0xFF00E676)
                                                            : Colors.white12,
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        if (v.isProbingSize) ...[
                                                          const SizedBox(
                                                            width: 10,
                                                            height: 10,
                                                            child: CircularProgressIndicator(
                                                              strokeWidth: 1.5,
                                                              color: Colors.white70,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 4),
                                                        ] else ...[
                                                          Icon(
                                                            Icons.sd_storage,
                                                            size: 12,
                                                            color: isLargest ? const Color(0xFF00E676) : Colors.white70,
                                                          ),
                                                          const SizedBox(width: 4),
                                                        ],
                                                        Text(
                                                          v.formattedSize,
                                                          style: TextStyle(
                                                            color: isLargest ? const Color(0xFF00E676) : Colors.white,
                                                            fontSize: 11.5,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                v.pageTitle.isNotEmpty ? v.pageTitle : 'Web-Video',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 4),

                                              // Download-Balkenanzeige oder Aktionszeile
                                              if (isDownloading) ...[
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(4),
                                                  child: LinearProgressIndicator(
                                                    value: existing!.progress >= 0 ? existing.progress : null,
                                                    minHeight: 6,
                                                    backgroundColor: Colors.white12,
                                                    valueColor: const AlwaysStoppedAnimation(Color(0xFF00E676)),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(
                                                      existing.downloadProgressText,
                                                      style: const TextStyle(color: Color(0xFF00E676), fontSize: 11, fontWeight: FontWeight.w600),
                                                    ),
                                                    Text(
                                                      existing.downloadEtaText,
                                                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                                                    ),
                                                  ],
                                                ),
                                              ] else if (isBuffered) ...[
                                                Row(
                                                  children: [
                                                    const Icon(Icons.check_circle, color: Color(0xFF00E676), size: 16),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      'Offline bereit (${existing!.remainingFormatted})',
                                                      style: const TextStyle(color: Color(0xFF00E676), fontSize: 11.5),
                                                    ),
                                                  ],
                                                ),
                                              ] else ...[
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        isLargest
                                                            ? 'Empfohlenes Video • Antippen zum Puffern'
                                                            : (v.isPreview || (v.fileSizeBytes != null && v.fileSizeBytes! < 1.5 * 1024 * 1024))
                                                                ? 'Kleiner Clip / Vorschau'
                                                                : 'Antippen zum Puffern',
                                                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                                                      ),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(Icons.download, color: Color(0xFF00E676), size: 20),
                                                      padding: EdgeInsets.zero,
                                                      constraints: const BoxConstraints(),
                                                      onPressed: () {
                                                        _triggerVideoBuffer(v.videoUrl, v.pageUrl, v.pageTitle);
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
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
              );
            },
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
  int? fileSizeBytes;
  bool isProbingSize;
  bool isMaster;
  String quality;

  DetectedVideo({
    required this.videoUrl,
    required this.pageUrl,
    required this.pageTitle,
    required this.detectedAt,
    this.isPreview = false,
    this.duration,
    this.fileSizeBytes,
    this.isProbingSize = false,
    this.isMaster = false,
    this.quality = '',
  });

  String get formattedSize {
    if (fileSizeBytes == null || fileSizeBytes == 0) {
      return isProbingSize ? 'Ermittle...' : 'Unbekannt';
    }
    final bytes = fileSizeBytes!;
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }
}
