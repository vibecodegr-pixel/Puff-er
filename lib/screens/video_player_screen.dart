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

  // Interaktives Scrubbing / Spulen per Finger-Drag
  bool _isDraggingScrubber = false;
  double _dragPositionMs = 0.0;
  bool _wasPlayingBeforeDrag = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final path = widget.item.localFilePath;
    File? file;
    if (path != null) {
      file = File(path);
    }

    // 1. Primär: Versuche lokale gepufferte Datei abzuspielen
    if (file != null && await file.exists()) {
      try {
        _controller = VideoPlayerController.file(file);
        await _controller!.initialize();
        _controller!.addListener(_playerListener);
        setState(() {
          _isInitialized = true;
          _hasError = false;
        });
        _controller!.play();
        _startHideTimer();
        return;
      } catch (e) {
        debugPrint('Lokale Videowiedergabe fehlgeschlagen: $e');
      }
    }

    // 2. Sekundär: Fallback auf Direkt-Stream über Video-URL
    if (widget.item.videoUrl.isNotEmpty && widget.item.videoUrl.startsWith('http')) {
      try {
        _controller?.dispose();
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(widget.item.videoUrl),
          httpHeaders: {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
            'Referer': widget.item.motherPageUrl,
          },
        );
        await _controller!.initialize();
        _controller!.addListener(_playerListener);
        setState(() {
          _isInitialized = true;
          _hasError = false;
        });
        _controller!.play();
        _startHideTimer();
        return;
      } catch (e) {
        debugPrint('Netzwerk-Fallback fehlgeschlagen: $e');
      }
    }

    // 3. Verständliche Fehlererklärung für den Nutzer
    String friendlyMessage = 'Das Video konnte nicht abgespielt werden.';
    if (file != null && await file.exists()) {
      final size = await file.length();
      if (size < 50 * 1024) {
        friendlyMessage = 'Die Datei ist unvollständig oder die Webseite schützt ihre Videos mit einem DRM-Kopierschutz.';
      } else {
        friendlyMessage = 'Der Videocodec dieses Streams wird vom Android-Player nicht nativ dekodiert.';
      }
    } else {
      friendlyMessage = 'Die temporäre Videodatei ist nicht vorhanden oder bereits nach 5h abgelaufen.';
    }

    setState(() {
      _hasError = true;
      _errorMessage = friendlyMessage;
    });
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
    _controller?.dispose();
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
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.error_outline, size: 52, color: Colors.redAccent),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Wiedergabe nicht möglich',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2C2C2C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: const Text('Zurück zum Puffer'),
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

                        if (_showControls)
                          Container(
                            color: Colors.black45,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
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
                                              'Mutter-Seite: ${widget.item.motherPageHost}',
                                              style: const TextStyle(color: Colors.white60, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Zentrale Steuerung: 10s zurück, Play/Pause, 10s vor
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      iconSize: 42,
                                      icon: const Icon(Icons.replay_10, color: Colors.white),
                                      tooltip: '10 Sekunden zurück',
                                      onPressed: () {
                                        final cur = _controller!.value.position;
                                        final target = cur - const Duration(seconds: 10);
                                        _controller!.seekTo(target < Duration.zero ? Duration.zero : target);
                                        _startHideTimer();
                                      },
                                    ),
                                    const SizedBox(width: 20),
                                    IconButton(
                                      iconSize: 68,
                                      icon: Icon(
                                        _controller!.value.isPlaying
                                            ? Icons.pause_circle_filled
                                            : Icons.play_circle_filled,
                                        color: const Color(0xFF00E676),
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
                                    const SizedBox(width: 20),
                                    IconButton(
                                      iconSize: 42,
                                      icon: const Icon(Icons.forward_10, color: Colors.white),
                                      tooltip: '10 Sekunden vor',
                                      onPressed: () {
                                        final cur = _controller!.value.position;
                                        final dur = _controller!.value.duration;
                                        final target = cur + const Duration(seconds: 10);
                                        _controller!.seekTo(target > dur ? dur : target);
                                        _startHideTimer();
                                      },
                                    ),
                                  ],
                                ),

                                // Interaktive Zeitleiste mit Finger-Drag-Spulen
                                Builder(
                                  builder: (context) {
                                    final duration = _controller!.value.duration;
                                    final position = _controller!.value.position;
                                    final totalMs = duration.inMilliseconds.toDouble();
                                    final currentMs = _isDraggingScrubber
                                        ? _dragPositionMs
                                        : position.inMilliseconds.toDouble();
                                    final displayPos = _isDraggingScrubber
                                        ? Duration(milliseconds: _dragPositionMs.toInt())
                                        : position;

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      child: Column(
                                        children: [
                                          SliderTheme(
                                            data: SliderTheme.of(context).copyWith(
                                              trackHeight: 5.0,
                                              activeTrackColor: const Color(0xFF00E676),
                                              inactiveTrackColor: Colors.white24,
                                              thumbColor: const Color(0xFF00E676),
                                              thumbShape: const RoundSliderThumbShape(
                                                enabledThumbRadius: 8.5,
                                                pressedElevation: 6.0,
                                              ),
                                              overlayColor: const Color(0xFF00E676).withOpacity(0.25),
                                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 22.0),
                                              trackShape: const RoundedRectSliderTrackShape(),
                                            ),
                                            child: Slider(
                                              min: 0.0,
                                              max: totalMs > 0 ? totalMs : 1.0,
                                              value: totalMs > 0 ? currentMs.clamp(0.0, totalMs) : 0.0,
                                              onChangeStart: (value) {
                                                _hideControlsTimer?.cancel();
                                                _wasPlayingBeforeDrag = _controller!.value.isPlaying;
                                                if (_wasPlayingBeforeDrag) {
                                                  _controller!.pause();
                                                }
                                                setState(() {
                                                  _isDraggingScrubber = true;
                                                  _dragPositionMs = value;
                                                });
                                              },
                                              onChanged: (value) {
                                                setState(() {
                                                  _dragPositionMs = value;
                                                });
                                              },
                                              onChangeEnd: (value) async {
                                                final target = Duration(milliseconds: value.toInt());
                                                await _controller!.seekTo(target);
                                                if (mounted) {
                                                  setState(() {
                                                    _isDraggingScrubber = false;
                                                  });
                                                  if (_wasPlayingBeforeDrag) {
                                                    _controller!.play();
                                                  }
                                                  _startHideTimer();
                                                }
                                              },
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  _formatDuration(displayPos),
                                                  style: TextStyle(
                                                    color: _isDraggingScrubber ? const Color(0xFF00E676) : Colors.white70,
                                                    fontSize: 12.5,
                                                    fontWeight: _isDraggingScrubber ? FontWeight.bold : FontWeight.normal,
                                                  ),
                                                ),
                                                Text(
                                                  _formatDuration(duration),
                                                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
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
