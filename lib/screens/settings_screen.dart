// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';

// FIX 21: ThemeProvider now persists the theme choice to SharedPreferences
// so dark/light mode survives app restarts.
class ThemeProvider extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.dark;
  ThemeMode get mode => _mode;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('rainax_dark_mode') ?? true;
    _mode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> toggle() async {
    _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rainax_dark_mode', _mode == ThemeMode.dark);
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final thProv = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Settings',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(title: 'Appearance', children: [
            _SwitchTile(
              icon:      Icons.dark_mode_rounded,
              title:     'Dark Mode',
              value:     thProv.mode == ThemeMode.dark,
              onChanged: (_) => thProv.toggle(),
            ),
          ]),

          _Section(title: 'Downloads', children: [
            _InfoTile(
              icon:  Icons.folder_rounded,
              title: 'Storage Location',
              sub:   'External storage / RAINAX / [Videos|Music]',
            ),
            _InfoTile(
              icon:  Icons.info_outline_rounded,
              title: 'Supported Sites',
              sub:   'YouTube, Vimeo, SoundCloud, Dailymotion, TikTok + 1000 more',
            ),
          ]),

          _Section(title: 'About', children: [
            _InfoTile(
              icon:  Icons.auto_awesome_rounded,
              title: 'RAINAX Downloader',
              sub:   'v1.0.0  ·  Powered by yt-dlp + ffmpeg',
            ),
            _InfoTile(
              icon:  Icons.code_rounded,
              title: 'Engine',
              sub:   'yt-dlp (Chaquopy CPython 3.12) + ffmpeg',
            ),
          ]),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 0, 8),
          child: Text(title.toUpperCase(),
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: kAccent)),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? kDarkCard : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: isDark ? kDarkBorder : kLightBorder, width: 0.5),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchTile(
      {required this.icon, required this.title,
       required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => SwitchListTile(
    secondary: Icon(icon, color: kAccent, size: 20),
    title: Text(title, style: const TextStyle(fontSize: 14)),
    value: value,
    onChanged: onChanged,
    activeColor: kAccent,
  );
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  const _InfoTile(
      {required this.icon, required this.title, required this.sub});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Icon(icon, color: kAccent, size: 20),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(sub,
          style: TextStyle(
              fontSize: 11,
              color: isDark ? kDarkTextSec : kLightTextSec)),
    );
  }
}
