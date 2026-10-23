import 'package:flutter/material.dart';
import '../models/video_item.dart';
import '../services/buffer_service.dart';
import 'video_player_screen.dart';

class HistoryScreen extends StatefulWidget {
  final BufferService bufferService;
  final Function(String url) onOpenInBrowser;

  const HistoryScreen({
    super.key,
    required this.bufferService,
    required this.onOpenInBrowser,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _searchQuery = '';
  final Set<String> _collapsedHosts = {};

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.bufferService,
      builder: (context, _) {
        final grouped = widget.bufferService.groupedByMotherPage;
        final totalCount = widget.bufferService.allItems.length;

        // Filter nach Suchbegriff
        final filteredGrouped = <String, List<VideoItem>>{};
        if (_searchQuery.trim().isEmpty) {
          filteredGrouped.addAll(grouped);
        } else {
          final query = _searchQuery.toLowerCase().trim();
          grouped.forEach((host, items) {
            final matches = items.where((i) {
              return i.title.toLowerCase().contains(query) ||
                  i.motherPageHost.toLowerCase().contains(query) ||
                  i.motherPageUrl.toLowerCase().contains(query);
            }).toList();
            if (matches.isNotEmpty) {
              filteredGrouped[host] = matches;
            }
          });
        }

        return Scaffold(
          backgroundColor: const Color(0xFF121212),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1E1E1E),
            elevation: 0,
            title: const Text(
              'Link-Verlauf nach Mutter-Seite',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          body: Column(
            children: [
              // Suchleiste
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: const Color(0xFF1E1E1E),
                child: TextField(
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Nach Video oder Mutter-Seite suchen...',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFF2C2C2C),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                ),
              ),

              Expanded(
                child: totalCount == 0
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
                                child: const Icon(Icons.history_toggle_off, size: 56, color: Colors.white30),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Noch keine Videos im Verlauf',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Alle erfassten Videos bleiben hier dauerhaft nach ihrer Mutter-Seite geordnet, auch wenn ihr temporärer Puffer nach 5h abgelaufen ist.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        children: filteredGrouped.entries.map((entry) {
                          final host = entry.key;
                          final items = entry.value;
                          final isCollapsed = _collapsedHosts.contains(host);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header der Mutter-Seite
                                InkWell(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                                  onTap: () {
                                    setState(() {
                                      if (isCollapsed) {
                                        _collapsedHosts.remove(host);
                                      } else {
                                        _collapsedHosts.add(host);
                                      }
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF00E676).withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(Icons.public, color: Color(0xFF00E676), size: 20),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                host,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              Text(
                                                '${items.length} Video${items.length == 1 ? "" : "s"} erfasst',
                                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Mutter-Seite im Browser aufrufen',
                                          icon: const Icon(Icons.open_in_browser, color: Colors.white70, size: 20),
                                          onPressed: () {
                                            if (items.isNotEmpty && items.first.motherPageUrl.isNotEmpty) {
                                              widget.onOpenInBrowser(items.first.motherPageUrl);
                                            } else {
                                              widget.onOpenInBrowser('https://$host');
                                            }
                                          },
                                        ),
                                        Icon(
                                          isCollapsed ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                                          color: Colors.white54,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Liste der Videos dieser Mutter-Seite
                                if (!isCollapsed) ...[
                                  const Divider(color: Colors.white10, height: 1),
                                  ...items.map((item) {
                                    final isBuffered = item.isOfflineAvailable;
                                    final isDownloading = item.status == VideoStatus.downloading;
                                    final isExpired = item.isExpired || (!isBuffered && !isDownloading);

                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      decoration: const BoxDecoration(
                                        border: Border(bottom: BorderSide(color: Colors.white10)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      item.title,
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 13.5,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      item.videoUrl,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(color: Colors.white30, fontSize: 11),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              // Aktionen je nach Puffer-Status
                                              if (isDownloading)
                                                SizedBox(
                                                  width: 32,
                                                  height: 32,
                                                  child: Stack(
                                                    alignment: Alignment.center,
                                                    children: [
                                                      CircularProgressIndicator(
                                                        value: item.progress > 0 ? item.progress : null,
                                                        strokeWidth: 2.5,
                                                        color: const Color(0xFF00E676),
                                                      ),
                                                      IconButton(
                                                        padding: EdgeInsets.zero,
                                                        icon: const Icon(Icons.close, size: 14, color: Colors.white70),
                                                        onPressed: () => widget.bufferService.cancelDownload(item.id),
                                                      ),
                                                    ],
                                                  ),
                                                )
                                              else if (isBuffered)
                                                ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF00E676),
                                                    foregroundColor: Colors.black,
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                    minimumSize: Size.zero,
                                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                  ),
                                                  icon: const Icon(Icons.play_arrow, size: 16),
                                                  label: const Text('Abspielen', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                  onPressed: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) => VideoPlayerScreen(item: item),
                                                      ),
                                                    );
                                                  },
                                                )
                                              else
                                                ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF2C2C2C),
                                                    foregroundColor: const Color(0xFF00E676),
                                                    side: const BorderSide(color: Color(0xFF00E676), width: 1),
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                    minimumSize: Size.zero,
                                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                  ),
                                                  icon: const Icon(Icons.refresh, size: 14),
                                                  label: const Text('Erneut reinladen', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                  onPressed: () {
                                                    widget.bufferService.rebuffVideo(item);
                                                  },
                                                ),
                                            ],
                                          ),
                                          if (isDownloading) ...[
                                            const SizedBox(height: 8),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(4),
                                              child: LinearProgressIndicator(
                                                value: item.progress >= 0 ? item.progress : null,
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
                                                  item.downloadProgressText,
                                                  style: const TextStyle(color: Color(0xFF00E676), fontSize: 11.5, fontWeight: FontWeight.w600),
                                                ),
                                                Text(
                                                  item.downloadEtaText,
                                                  style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                                                ),
                                              ],
                                            ),
                                          ] else ...[
                                            const SizedBox(height: 8),
                                            // Status-Badge
                                            Row(
                                              children: [
                                                if (isBuffered)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF00E676).withOpacity(0.12),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      '🟢 Offline bereit (${item.remainingFormatted})',
                                                      style: const TextStyle(color: Color(0xFF00E676), fontSize: 11, fontWeight: FontWeight.w600),
                                                    ),
                                                  )
                                                else
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white.withOpacity(0.06),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: const Text(
                                                      '⚪ 5h-Puffer abgelaufen (Datei gelöscht)',
                                                      style: TextStyle(color: Colors.white54, fontSize: 11),
                                                    ),
                                                  ),
                                                const Spacer(),
                                                IconButton(
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.white30),
                                                  tooltip: 'Aus Verlauf löschen',
                                                  onPressed: () => widget.bufferService.deleteHistoryItem(item),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
