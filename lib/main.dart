// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'providers/download_provider.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Transparent status & nav bars
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:                 Colors.transparent,
    systemNavigationBarColor:       Colors.transparent,
    statusBarIconBrightness:        Brightness.light,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const RainaxApp());
}

class RainaxApp extends StatelessWidget {
  const RainaxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DownloadProvider()..init()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (_, themeProv, __) => MaterialApp(
          title:     'RAINAX',
          debugShowCheckedModeBanner: false,
          themeMode: themeProv.mode,
          theme:     buildLightTheme(),
          darkTheme: buildDarkTheme(),
          home:      const _PermissionGate(),
        ),
      ),
    );
  }
}

// ── Permission gate ───────────────────────────────────────────────────────────

class _PermissionGate extends StatefulWidget {
  const _PermissionGate();
  @override
  State<_PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<_PermissionGate> {
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // Storage
    await [
      Permission.storage,
      Permission.manageExternalStorage,
    ].request();

    // Notifications (Android 13+)
    await Permission.notification.request();

    if (mounted) setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_done) {
      return const Scaffold(
        backgroundColor: kDarkBgPrimary,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: kAccent),
              SizedBox(height: 16),
              Text('Initialising RAINAX…',
                  style: TextStyle(color: kDarkTextSec)),
            ],
          ),
        ),
      );
    }
    return const HomeScreen();
  }
}
