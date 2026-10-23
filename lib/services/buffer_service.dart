import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video_item.dart';

class BufferService extends ChangeNotifier {
  static const String _storageKey = 'puffer_video_history_v1';
  static const Duration bufferTtl = Duration(hours: 5);

  final List<VideoItem> _items = [];
  final Map<String, CancelToken> _cancelTokens = {};
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 120),
    headers: {
      'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
    },
  ));

  Timer? _cleanupTimer;
  bool _isInitialized = false;

  BufferService() {
    _init();
  }

  List<VideoItem> get allItems => List.unmodifiable(_items);

  /// Alle aktuell offline verfügbaren Videos (noch innerhalb der 5h-Frist).
  List<VideoItem> get bufferedItems => _items.where((i) => i.isOfflineAvailable).toList();

  /// Verlauf aller Videos gruppiert nach Mutter-Seite (Domain/Host).
  Map<String, List<VideoItem>> get groupedByMotherPage {
    final map = <String, List<VideoItem>>{};
    for (final item in _items) {
      final host = item.motherPageHost.isNotEmpty ? item.motherPageHost : 'Sonstige Seiten';
      map.putIfAbsent(host, () => []).add(item);
    }
    return map;
  }

  /// Gibt die Gesamtgröße des aktuellen Pufferspeichers in Bytes zurück.
  int get totalBufferedSizeBytes {
    int total = 0;
    for (final item in bufferedItems) {
      if (item.fileSizeBytes != null) {
        total += item.fileSizeBytes!;
      }
    }
    return total;
  }

  /// Formatierte Anzeige des gesamten Pufferspeichers.
  String get formattedTotalBufferedSize {
    final bytes = totalBufferedSizeBytes;
    final mb = bytes / (1024 * 1024);
    if (mb < 1024) {
      return '${mb.toStringAsFixed(1)} MB';
    }
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(2)} GB';
  }

  Future<void> _init() async {
    if (_isInitialized) return;
    await _loadFromStorage();
    await cleanupExpiredFiles();
    
    // Regelmäßiger Prüf-Timer (alle 2 Minuten)
    _cleanupTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      cleanupExpiredFiles();
    });
    _isInitialized = true;
    notifyListeners();
  }

  /// Bereinigt alle Video-Dateien, deren 5-Stunden-Puffer abgelaufen ist.
  Future<void> cleanupExpiredFiles() async {
    bool stateChanged = false;
    final now = DateTime.now();

    for (final item in _items) {
      if (item.status == VideoStatus.buffered) {
        final isExpired = item.expiresAt != null && now.isAfter(item.expiresAt!);
        if (isExpired) {
          if (item.localFilePath != null) {
            try {
              final file = File(item.localFilePath!);
              if (await file.exists()) {
                await file.delete();
              }
            } catch (e) {
              debugPrint('Fehler beim Löschen der abgelaufenen Datei: $e');
            }
          }
          item.localFilePath = null;
          item.status = VideoStatus.expired;
          stateChanged = true;
        }
      }
    }

    if (stateChanged) {
      await _saveToStorage();
      notifyListeners();
    }
  }

  /// Findet ein existierendes VideoItem anhand der Video-URL oder ID.
  VideoItem? findItemByUrl(String videoUrl) {
    try {
      return _items.firstWhere((i) => i.videoUrl == videoUrl);
    } catch (_) {
      return null;
    }
  }

  bool _isAdUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('doubleclick.net') ||
        lower.contains('googlesyndication.com') ||
        lower.contains('googleads') ||
        lower.contains('imasdk.googleapis.com') ||
        lower.contains('adservice.google') ||
        lower.contains('/pagead/') ||
        lower.contains('/video_ads/') ||
        lower.contains('vmap');
  }

  /// Startet den Download eines Videos in den 5-Stunden-Pufferspeicher.
  Future<void> bufferVideo({
    required String videoUrl,
    required String motherPageUrl,
    required String motherPageHost,
    required String title,
  }) async {
    if (_isAdUrl(videoUrl)) {
      debugPrint('Werbe-URL wird abgewiesen: $videoUrl');
      return;
    }
    VideoItem? existing = findItemByUrl(videoUrl);
    if (existing != null) {
      if (existing.isOfflineAvailable) {
        return;
      }
      if (existing.status == VideoStatus.downloading) {
        return;
      }
    }

    final id = existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    final item = existing ??
        VideoItem(
          id: id,
          videoUrl: videoUrl,
          motherPageUrl: motherPageUrl,
          motherPageHost: motherPageHost.isNotEmpty ? motherPageHost : _extractHost(motherPageUrl),
          title: title.isNotEmpty ? title : 'Video aus ${_extractHost(motherPageUrl)}',
        );

    if (existing == null) {
      _items.insert(0, item);
    }

    item.status = VideoStatus.downloading;
    item.progress = 0.0;
    item.errorMessage = null;
    notifyListeners();

    final cancelToken = CancelToken();
    _cancelTokens[item.id] = cancelToken;

    try {
      final tempDir = await getTemporaryDirectory();
      final videosDir = Directory('${tempDir.path}/puffer_videos');
      if (!await videosDir.exists()) {
        await videosDir.create(recursive: true);
      }

      String extension = '.mp4';
      final uri = Uri.tryParse(videoUrl);
      if (uri != null && uri.path.isNotEmpty) {
        final pathLower = uri.path.toLowerCase();
        if (pathLower.endsWith('.webm')) {
          extension = '.webm';
        } else if (pathLower.endsWith('.mkv')) {
          extension = '.mkv';
        } else if (pathLower.endsWith('.mp4')) {
          extension = '.mp4';
        }
      }

      final savePath = '${videosDir.path}/puffer_${item.id}$extension';

      // Wichtig: Referer und Origin mitsenden, damit Web-Server das Video nicht mit 403 / HTML blockieren!
      final headers = {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
        'Accept': '*/*',
        'Accept-Encoding': 'identity',
      };
      if (motherPageUrl.isNotEmpty && motherPageUrl.startsWith('http')) {
        headers['Referer'] = motherPageUrl;
        final motherUri = Uri.tryParse(motherPageUrl);
        if (motherUri != null && motherUri.hasScheme && motherUri.hasAuthority) {
          headers['Origin'] = '${motherUri.scheme}://${motherUri.authority}';
        }
      }

      await _dio.download(
        videoUrl,
        savePath,
        cancelToken: cancelToken,
        options: Options(
          headers: headers,
          validateStatus: (status) => status != null && status >= 200 && status < 400,
        ),
        onReceiveProgress: (received, total) {
          if (total > 0) {
            item.progress = received / total;
            item.fileSizeBytes = received;
            notifyListeners();
          }
        },
      );

      final downloadedFile = File(savePath);
      if (await downloadedFile.exists()) {
        final fileSize = await downloadedFile.length();

        // Validierung: Prüfe ob die Datei ein echtes Video ist oder eine HTML-Fehlerseite (403/DRM block)
        bool isHtmlError = false;
        if (fileSize < 100 * 1024) {
          try {
            final firstBytes = await downloadedFile.openRead(0, 512).first;
            final text = String.fromCharCodes(firstBytes).toLowerCase();
            if (text.contains('<!doctype') || text.contains('<html') || text.contains('403 forbidden') || text.contains('access denied')) {
              isHtmlError = true;
            }
          } catch (_) {}
        }

        if (fileSize < 20 * 1024 || isHtmlError) {
          await downloadedFile.delete();
          throw Exception('Webseite verweigert den direkten Video-Download oder hat eine HTML-Fehlerseite geschickt.');
        }

        item.localFilePath = savePath;
        item.fileSizeBytes = fileSize;
        item.bufferedAt = DateTime.now();
        item.expiresAt = DateTime.now().add(bufferTtl);
        item.status = VideoStatus.buffered;
        item.progress = 1.0;
      } else {
        throw Exception('Datei konnte nicht im temporären Speicher angelegt werden.');
      }
    } catch (e) {
      if (CancelToken.isCancel(e as dynamic)) {
        item.status = VideoStatus.idle;
      } else {
        item.status = VideoStatus.error;
        item.errorMessage = e.toString().replaceFirst('Exception: ', '');
        debugPrint('Download-Fehler für ${item.videoUrl}: $e');
      }
    } finally {
      _cancelTokens.remove(item.id);
      await _saveToStorage();
      notifyListeners();
    }
  }

  /// Bricht einen laufenden Download ab.
  void cancelDownload(String itemId) {
    if (_cancelTokens.containsKey(itemId)) {
      _cancelTokens[itemId]?.cancel('Vom Nutzer abgebrochen');
      _cancelTokens.remove(itemId);
    }
    final item = _items.firstWhere((i) => i.id == itemId, orElse: () => _items.first);
    if (item.status == VideoStatus.downloading) {
      item.status = VideoStatus.idle;
      item.progress = 0.0;
      notifyListeners();
    }
  }

  /// Lädt ein abgelaufenes oder fehlgeschlagenes Video erneut in den Puffer ("Erneut reinladen").
  Future<void> rebuffVideo(VideoItem item) async {
    await bufferVideo(
      videoUrl: item.videoUrl,
      motherPageUrl: item.motherPageUrl,
      motherPageHost: item.motherPageHost,
      title: item.title,
    );
  }

  /// Entfernt ein Video vorzeitig manuell aus dem Pufferspeicher.
  Future<void> removeBufferedFile(VideoItem item) async {
    if (item.localFilePath != null) {
      try {
        final file = File(item.localFilePath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Fehler beim manuellen Löschen der Datei: $e');
      }
    }
    item.localFilePath = null;
    item.status = VideoStatus.expired;
    await _saveToStorage();
    notifyListeners();
  }

  /// Löscht einen Eintrag komplett aus dem Verlauf.
  Future<void> deleteHistoryItem(VideoItem item) async {
    await removeBufferedFile(item);
    _items.removeWhere((i) => i.id == item.id);
    await _saveToStorage();
    notifyListeners();
  }

  /// Löscht alle aktuell gepufferten Dateien.
  Future<void> clearAllBuffered() async {
    for (final item in _items) {
      if (item.localFilePath != null) {
        try {
          final file = File(item.localFilePath!);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
      }
      item.localFilePath = null;
      if (item.status == VideoStatus.buffered) {
        item.status = VideoStatus.expired;
      }
    }
    await _saveToStorage();
    notifyListeners();
  }

  String _extractHost(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst(RegExp(r'^www\.'), '');
    } catch (_) {
      return 'Webseite';
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = _items.map((i) => i.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(listJson));
    } catch (e) {
      debugPrint('Fehler beim Speichern des Verlaufs: $e');
    }
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        _items.clear();
        for (final entry in list) {
          if (entry is Map<String, dynamic>) {
            _items.add(VideoItem.fromJson(entry));
          }
        }
      }
    } catch (e) {
      debugPrint('Fehler beim Laden des Verlaufs: $e');
    }
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    for (final token in _cancelTokens.values) {
      token.cancel('Disposed');
    }
    super.dispose();
  }
}
