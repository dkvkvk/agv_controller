import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'models/agv_state.dart';
import 'services/bluetooth_service.dart';
import 'services/protocol_service.dart';
import 'pages/connection_page.dart';
import 'pages/control_page.dart';
import 'pages/monitor_page.dart';
import 'pages/settings_page.dart';
import 'pages/terminal_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0D1133),
  ));
  runApp(const AGVControllerApp());
}

// ─────────────────────────────────────────────
//  Color constants
// ─────────────────────────────────────────────
class AppColors {
  static const background = Color(0xFF0A0E27);
  static const surface = Color(0xFF111636);
  static const navBar = Color(0xFF0D1133);
  static const primary = Color(0xFF00D4FF);   // cyan
  static const secondary = Color(0xFF7C4DFF); // purple
  static const success = Color(0xFF00E676);
  static const warning = Color(0xFFFF9100);
  static const danger = Color(0xFFFF1744);
  static const textPrimary = Color(0xFFE0E6FF);
  static const textSecondary = Color(0xFF6B7DB3);
}

// ─────────────────────────────────────────────
//  App root
// ─────────────────────────────────────────────
class AGVControllerApp extends StatelessWidget {
  const AGVControllerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BluetoothService()),
        ChangeNotifierProvider(create: (_) => AGVState()),
        // ProtocolService bridges BT and State — created eagerly
        Provider<ProtocolService>(
          create: (ctx) => ProtocolService(
            ctx.read<BluetoothService>(),
            ctx.read<AGVState>(),
          ),
          lazy: false,
          dispose: (_, s) => s.dispose(),
        ),
      ],
      child: MaterialApp(
        title: 'AGV Controller',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        home: const MainScreen(),
      ),
    );
  }

  ThemeData _buildTheme() {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.danger,
        onPrimary: Colors.black,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: GoogleFonts.rajdhaniTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.navBar,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Main scaffold with bottom nav
// ─────────────────────────────────────────────
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  static const _pages = <Widget>[
    ConnectionPage(),
    ControlPage(),
    MonitorPage(),
    SettingsPage(),
    TerminalPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: AppColors.primary.withOpacity(0.08),
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.bluetooth), label: '连接'),
            BottomNavigationBarItem(
                icon: Icon(Icons.gamepad), label: '控制'),
            BottomNavigationBarItem(
                icon: Icon(Icons.monitor_heart), label: '监控'),
            BottomNavigationBarItem(
                icon: Icon(Icons.tune), label: '参数'),
            BottomNavigationBarItem(
                icon: Icon(Icons.terminal), label: '终端'),
          ],
        ),
      ),
    );
  }
}
