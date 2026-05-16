// lib/screens/home_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/download_provider.dart';
import '../theme.dart';
import 'add_download_screen.dart';
import 'downloads_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  // FIX 15: keep subscription so it can be cancelled in dispose()
  StreamSubscription<String>? _sharedUrlSub;

  final List<Widget> _screens = const [
    DownloadsScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sharedUrlSub = context.read<DownloadProvider>().sharedUrlStream.listen((url) {
        if (mounted) _openAddDownload(prefillUrl: url);
      });
    });
  }

  @override
  void dispose() {
    // FIX 15: cancel subscription to prevent setState after dispose
    _sharedUrlSub?.cancel();
    super.dispose();
  }

  void _openAddDownload({String? prefillUrl}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddDownloadSheet(prefillUrl: prefillUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? kDarkBgSecondary : Colors.white;

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDownload,
        icon:  const Icon(Icons.add_rounded),
        label: const Text('New Download'),
        elevation: 6,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _BottomNav(
        selectedIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        bgColor: bgColor,
        isDark: isDark,
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final Color bgColor;
  final bool isDark;

  const _BottomNav({
    required this.selectedIndex,
    required this.onTap,
    required this.bgColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          top: BorderSide(
            color: isDark ? kDarkBorder : kLightBorder,
            width: 0.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Consumer<DownloadProvider>(
        builder: (_, prov, __) {
          return BottomAppBar(
            color: Colors.transparent,
            elevation: 0,
            notchMargin: 8,
            shape: const CircularNotchedRectangle(),
            child: SizedBox(
              height: 56,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _navItem(context, 0, Icons.download_rounded, 'Downloads',
                      badge: prov.activeCount > 0 ? '${prov.activeCount}' : null),
                  _navItem(context, 1, Icons.history_rounded, 'History'),
                  const SizedBox(width: 72),
                  _navItem(context, 2, Icons.settings_rounded, 'Settings'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _navItem(BuildContext context, int index, IconData icon, String label,
      {String? badge}) {
    final selected = selectedIndex == index;
    final color = selected ? kAccent : kDarkTextSec;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: 22),
                if (badge != null)
                  Positioned(
                    right: -8, top: -5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: kAccent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(badge,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}
