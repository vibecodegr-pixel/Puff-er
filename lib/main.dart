import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/main_navigation_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Ressourcenschonendes, dunkles System-UI-Design für minimale OLED-Akkulast
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF1E1E1E),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const PufferApp());
}

class PufferApp extends StatelessWidget {
  const PufferApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Puff-er',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFF00E676),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E676),
          secondary: Color(0xFF00B0FF),
          surface: Color(0xFF1E1E1E),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
          foregroundColor: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: const MainNavigationScreen(),
    );
  }
}
