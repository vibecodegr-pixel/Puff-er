import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/video_item.dart';

class VideoPlayerScreen extends StatefulWidget {
  final VideoItem item;

  const VideoPlayerScreen({super.key, required this.item});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _showControls = true;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final path = widget.item.localFilePath;
    if (path == null) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Lokaler Dateipfad ist nicht vorhanden.';
      });
      return;
    }

    final file = File(path);
    if (!await file.exists()) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Die Offline-Datei wurde bereits aus dem 5h-Puffer gelöscht.';
      });
      return;
    }

    try {
      _controller = VideoPlayerController.file(file);
      await _controller!.initialize();
      _controller!.addListener(_playerListener);
      setState(() {
        _isInitialized = true;
      });
      _controller!.play();
      _startHideTimer();
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Fehler beim Abspielen: $e';
      });
    }
  }

  void _playerListener() {
    if (mounted) {
      setState(() {});
    }
  }

  void _startHideTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && (_controller?.value.isPlaying ?? false)) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideTimer();
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _controller?.removeListener(_playerListener);
    _controller?.dispose(); // Hardware-Decoder und Speicher sofort freigeben (ressourcenschonend)
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _hasError
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C2C2C)),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Zurück', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              )
            : !_isInitialized
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00E676)),
                  )
                : GestureDetector(
                    onTap: _toggleControls,
                    behavior: HitTestBehavior.opaque,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Center(
                          child: AspectRatio(
                            aspectRatio: _controller!.value.aspectRatio,
                            child: VideoPlayer(_controller!),
                          ),
                        ),

                        // Steuerleisten Overlay
                        if (_showControls)
                          Container(
                            color: Colors.black45,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Oberer Header mit Zurück-Button & Titel
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              widget.item.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            Text(
                                              'Offline aus Mutter-Seite: ${widget.item.motherPageHost}',
                                              style: const TextStyle(color: Colors.white60, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Zentraler Play / Pause Button
                                IconButton(
                                  iconSize: 64,
                                  icon: Icon(
                                    _controller!.value.isPlaying
                                        ? Icons.pause_circle_filled
                                        : Icons.play_circle_filled,
                                    color: Colors.white,
                                  ),
                                  onPressed: () {
                                    if (_controller!.value.isPlaying) {
                                      _controller!.pause();
                                    } else {
                                      _controller!.play();
                                      _startHideTimer();
                                    }
                                  },
                                ),

                                // Untere Kontrollleiste mit Fortschrittsanzeige & Zeit
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Column(
                                    children: [
                                      VideoProgressIndicator(
                                        _controller!,
                                        allowScrubbing: true,
                                        colors: const VideoProgressColors(
                                          playedColor: Color(0xFF00E676),
                                          bufferedColor: Colors.white30,
                                          backgroundColor: Colors.white12,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _formatDuration(_controller!.value.position),
                                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                                          ),
                                          Text(
                                            _formatDuration(_controller!.value.duration),
                                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
