import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/buffer_service.dart';
import '../services/share_service.dart';
import 'browser_screen.dart';
import 'history_screen.dart';
import 'puffer_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  late final BufferService _bufferService;
  StreamSubscription<String>? _shareSubscription;
  final GlobalKey<BrowserScreenState> _browserKey = GlobalKey<BrowserScreenState>();
  String? _pendingBrowserUrl;
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    _bufferService = BufferService();
    _initSharing();
  }

  Future<void> _initSharing() async {
    ShareService.initialize();

    // Laufende Shares verarbeiten
    _shareSubscription = ShareService.onSharedUrl.listen((url) {
      _handleIncomingUrl(url);
    });

    // Cold-Start Share prüfen
    final initialUrl = await ShareService.getInitialSharedUrl();
    if (initialUrl != null) {
      _handleIncomingUrl(initialUrl);
    }
  }

  void _handleIncomingUrl(String url) {
    if (!mounted) return;
    setState(() {
      _currentIndex = 0; // Zum Browser wechseln
      _pendingBrowserUrl = url;
    });

    _browserKey.currentState?.loadUrl(url);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.share, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Geteilter Link geöffnet: $url',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1B5E20),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openUrlInBrowser(String url) {
    setState(() {
      _currentIndex = 0;
      _pendingBrowserUrl = url;
    });
    _browserKey.currentState?.loadUrl(url);
  }

  @override
  void dispose() {
    _shareSubscription?.cancel();
    _bufferService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // 1. Wenn nicht im Browser-Tab: zurück zum Browser-Tab springen
        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
          return;
        }

        // 2. Wenn im Browser-Tab: Web-Verlauf rückwärts navigieren
        final browserState = _browserKey.currentState;
        if (browserState != null) {
          final handled = await browserState.handleBackPress();
          if (handled) {
            return;
          }
        }

        // 3. Wenn auf der Startseite: vor versehentlichem Beenden schützen
        final now = DateTime.now();
        if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erneut drücken zum Beenden'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        // Bei schnellem zweiten Druck App sauber beenden
        SystemNavigator.pop();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            BrowserScreen(
              key: _browserKey,
              bufferService: _bufferService,
              initialUrl: _pendingBrowserUrl,
            ),
            PufferScreen(
              bufferService: _bufferService,
              onGoToBrowser: () {
                setState(() {
                  _currentIndex = 0;
                });
              },
            ),
            HistoryScreen(
              bufferService: _bufferService,
              onOpenInBrowser: _openUrlInBrowser,
            ),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            border: Border(top: BorderSide(color: Colors.white10)),
          ),
          child: AnimatedBuilder(
            animation: _bufferService,
            builder: (context, _) {
              final bufferedCount = _bufferService.bufferedItems.length;

              return BottomNavigationBar(
                currentIndex: _currentIndex,
                backgroundColor: const Color(0xFF1E1E1E),
                selectedItemColor: const Color(0xFF00E676),
                unselectedItemColor: Colors.white54,
                selectedFontSize: 12,
                unselectedFontSize: 12,
                type: BottomNavigationBarType.fixed,
                onTap: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                items: [
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.travel_explore),
                    activeIcon: Icon(Icons.travel_explore, color: Color(0xFF00E676)),
                    label: 'Browser',
                  ),
                  BottomNavigationBarItem(
                    icon: Badge(
                      isLabelVisible: bufferedCount > 0,
                      label: Text('$bufferedCount', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      backgroundColor: const Color(0xFF00E676),
                      child: const Icon(Icons.download_for_offline_outlined),
                    ),
                    activeIcon: Badge(
                      isLabelVisible: bufferedCount > 0,
                      label: Text('$bufferedCount', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      backgroundColor: const Color(0xFF00E676),
                      child: const Icon(Icons.download_for_offline, color: Color(0xFF00E676)),
                    ),
                    label: 'Offline-Puffer',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.history),
                    activeIcon: Icon(Icons.history, color: Color(0xFF00E676)),
                    label: 'Mutter-Seiten',
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
