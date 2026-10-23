import 'dart:async';
import 'package:flutter/material.dart';
import '../models/video_item.dart';
import '../services/buffer_service.dart';
import 'video_player_screen.dart';

class PufferScreen extends StatefulWidget {
  final BufferService bufferService;
  final VoidCallback onGoToBrowser;

  const PufferScreen({
    super.key,
    required this.bufferService,
    required this.onGoToBrowser,
  });

  @override
  State<PufferScreen> createState() => _PufferScreenState();
}

class _PufferScreenState extends State<PufferScreen> {
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    // Regelmäßiges UI-Update für den 5-Stunden Countdown (alle 30 Sekunden)
    _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _playOfflineVideo(VideoItem item) {
    if (!item.isOfflineAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video ist nicht mehr offline verfügbar oder abgelaufen.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(item: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.bufferService,
      builder: (context, _) {
        final bufferedItems = widget.bufferService.bufferedItems;
        final totalSize = widget.bufferService.formattedTotalBufferedSize;

        return Scaffold(
          backgroundColor: const Color(0xFF121212),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1E1E1E),
            elevation: 0,
            title: const Text(
              'Offline-Puffer (5h)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            actions: [
              if (bufferedItems.isNotEmpty)
                IconButton(
                  tooltip: 'Pufferspeicher leeren',
                  icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white70),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF242424),
                        title: const Text('Puffer leeren?', style: TextStyle(color: Colors.white)),
                        content: const Text(
                          'Möchtest du alle temporär gespeicherten Videos sofort aus dem Offline-Speicher entfernen? Die Links bleiben im Verlauf erhalten.',
                          style: TextStyle(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Abbrechen', style: TextStyle(color: Colors.white54)),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              widget.bufferService.clearAllBuffered();
                            },
                            child: const Text('Leeren', style: TextStyle(color: Colors.redAccent)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
          body: Column(
            children: [
              // Informationsleiste zur Speicherbelegung & 5h-TTL
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  border: Border(bottom: BorderSide(color: Colors.white10)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.storage, color: Color(0xFF00E676), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pufferspeicher: $totalSize belegt',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Dateien werden nach 5 Std. automatisch gelöscht.',
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${bufferedItems.length} Video${bufferedItems.length == 1 ? "" : "s"}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: bufferedItems.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.04),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.cloud_download_outlined, size: 56, color: Colors.white30),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Keine Videos im Offline-Puffer',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Öffne eine Seite mit Videos im In-App-Browser oder teile einen Link aus Chrome/Firefox an Puff-er, um Videos offline zu speichern.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00E676),
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                ),
                                onPressed: widget.onGoToBrowser,
                                icon: const Icon(Icons.travel_explore, size: 18),
                                label: const Text('Zum Browser gehen', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        itemCount: bufferedItems.length,
                        itemBuilder: (context, index) {
                          final item = bufferedItems[index];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => _playOfflineVideo(item),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // Video-Play-Symbol
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF00E676).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.play_arrow_rounded,
                                          color: Color(0xFF00E676),
                                          size: 32,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const Icon(Icons.public, size: 12, color: Colors.white38),
                                                const SizedBox(width: 4),
                                                Text(
                                                  item.motherPageHost,
                                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  '•  ${item.formattedSize}',
                                                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            // TTL Restzeit Badge
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF00E676).withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.timer_outlined, size: 12, color: Color(0xFF00E676)),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Noch ${item.remainingFormatted} offline',
                                                    style: const TextStyle(
                                                      color: Color(0xFF00E676),
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.white38),
                                        tooltip: 'Aus Puffer entfernen',
                                        onPressed: () {
                                          widget.bufferService.removeBufferedFile(item);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
