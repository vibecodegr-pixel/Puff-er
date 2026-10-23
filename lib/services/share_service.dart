import 'dart:async';
import 'package:flutter/services.dart';

class ShareService {
  static const MethodChannel _channel = MethodChannel('com.example.puffer/share');
  static final StreamController<String> _sharedUrlController = StreamController<String>.broadcast();

  static Stream<String> get onSharedUrl => _sharedUrlController.stream;

  static void initialize() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedUrlReceived') {
        final rawText = call.arguments as String?;
        if (rawText != null) {
          final url = extractUrl(rawText);
          if (url != null) {
            _sharedUrlController.add(url);
          }
        }
      }
    });
  }

  /// Fragt die beim Start übergebene Shared-URL ab.
  static Future<String?> getInitialSharedUrl() async {
    try {
      final rawText = await _channel.invokeMethod<String>('getInitialSharedUrl');
      if (rawText != null) {
        return extractUrl(rawText);
      }
    } catch (_) {}
    return null;
  }

  /// Extrahiert eine gültige HTTP/HTTPS-URL aus beliebigem Freitext (z. B. aus Android-Teilen-Dialogen).
  static String? extractUrl(String text) {
    final regExp = RegExp(
      r'(https?:\/\/[^\s]+)',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(text.trim());
    if (match != null) {
      String url = match.group(0)!;
      // Trailing Interpunktion entfernen
      if (url.endsWith('.') || url.endsWith(',') || url.endsWith(')')) {
        url = url.substring(0, url.length - 1);
      }
      return url;
    }
    if (text.startsWith('http://') || text.startsWith('https://')) {
      return text.trim();
    }
    return null;
  }
}
