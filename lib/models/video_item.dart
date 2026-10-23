import 'dart:io';

enum VideoStatus {
  idle,
  downloading,
  buffered,
  expired,
  error,
}

class VideoItem {
  final String id;
  final String videoUrl;
  final String motherPageUrl;
  final String motherPageHost;
  final String title;
  String? localFilePath;
  DateTime? bufferedAt;
  DateTime? expiresAt;
  int? fileSizeBytes;
  VideoStatus status;
  double progress;
  String? errorMessage;

  VideoItem({
    required this.id,
    required this.videoUrl,
    required this.motherPageUrl,
    required this.motherPageHost,
    required this.title,
    this.localFilePath,
    this.bufferedAt,
    this.expiresAt,
    this.fileSizeBytes,
    this.status = VideoStatus.idle,
    this.progress = 0.0,
    this.errorMessage,
  });

  /// Prüft, ob das Video aktuell offline auf der Festplatte vorliegt und noch nicht abgelaufen ist.
  bool get isOfflineAvailable {
    if (status != VideoStatus.buffered || localFilePath == null) return false;
    if (isExpired) return false;
    final file = File(localFilePath!);
    return file.existsSync();
  }

  /// Prüft, ob die 5 Stunden Puffer-Frist überschritten ist.
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Verbleibende Zeit bis zur automatischen Löschung.
  Duration get remainingTime {
    if (expiresAt == null) return Duration.zero;
    final diff = expiresAt!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Formatierte Restzeitanzeige (z. B. "4 Std. 25 Min." oder "Abgelaufen").
  String get remainingFormatted {
    if (isExpired || !isOfflineAvailable) {
      return 'Abgelaufen';
    }
    final rem = remainingTime;
    final hours = rem.inHours;
    final minutes = rem.inMinutes.remainder(60);
    if (hours > 0) {
      return '$hours Std. $minutes Min.';
    }
    return '$minutes Min.';
  }

  /// Formatierte Dateigröße.
  String get formattedSize {
    if (fileSizeBytes == null || fileSizeBytes == 0) return 'Unbekannte Größe';
    final kb = fileSizeBytes! / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'videoUrl': videoUrl,
      'motherPageUrl': motherPageUrl,
      'motherPageHost': motherPageHost,
      'title': title,
      'localFilePath': localFilePath,
      'bufferedAt': bufferedAt?.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'fileSizeBytes': fileSizeBytes,
      'status': status.name,
    };
  }

  factory VideoItem.fromJson(Map<String, dynamic> json) {
    VideoStatus parsedStatus = VideoStatus.idle;
    try {
      parsedStatus = VideoStatus.values.byName(json['status'] as String? ?? 'idle');
    } catch (_) {
      parsedStatus = VideoStatus.idle;
    }

    final item = VideoItem(
      id: json['id'] as String,
      videoUrl: json['videoUrl'] as String,
      motherPageUrl: json['motherPageUrl'] as String? ?? '',
      motherPageHost: json['motherPageHost'] as String? ?? 'Unbekannt',
      title: json['title'] as String? ?? 'Video',
      localFilePath: json['localFilePath'] as String?,
      bufferedAt: json['bufferedAt'] != null
          ? DateTime.tryParse(json['bufferedAt'] as String)
          : null,
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String)
          : null,
      fileSizeBytes: json['fileSizeBytes'] as int?,
      status: parsedStatus,
    );

    // Wenn der Eintrag als 'buffered' markiert war, aber die Frist um ist oder die Datei fehlt:
    if (item.status == VideoStatus.buffered) {
      if (item.isExpired || (item.localFilePath != null && !File(item.localFilePath!).existsSync())) {
        item.status = VideoStatus.expired;
        item.localFilePath = null;
      }
    }

    return item;
  }
}
