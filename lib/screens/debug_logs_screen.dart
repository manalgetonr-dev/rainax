// lib/screens/debug_logs_screen.dart
//
// Full in-app log viewer. Tap the bug icon in Settings to open.
// Shows every INFO / WARN / ERROR / FATAL entry captured since install,
// with copy-all and share buttons so you can paste logs anywhere.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/crash_log_service.dart';
import '../theme.dart';

class DebugLogsScreen extends StatefulWidget {
  const DebugLogsScreen({super.key});

  @override
  State<DebugLogsScreen> createState() => _DebugLogsScreenState();
}

class _DebugLogsScreenState extends State<DebugLogsScreen> {
  final _svc = CrashLogService.instance;
  LogLevel? _filter; // null = show all

  @override
  void initState() {
    super.initState();
    _svc.addListener(_refresh);
  }

  @override
  void dispose() {
    _svc.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() { if (mounted) setState(() {}); }

  List<LogEntry> get _visible {
    final all = _svc.logs.reversed.toList();
    if (_filter == null) return all;
    return all.where((e) => e.level == _filter).toList();
  }

  Future<void> _copyAll() async {
    await Clipboard.setData(ClipboardData(text: _svc.fullText));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Logs copied — paste anywhere to share'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear all logs?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear', style: TextStyle(color: kDanger))),
        ],
      ),
    );
    if (confirmed == true) await _svc.clear();
  }

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final visible  = _visible;

    return Scaffold(
      backgroundColor: isDark ? kDarkBgPrimary : kLightBgPrimary,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Debug Logs',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
            Text('${_svc.logs.length} entries',
                style: TextStyle(
                    fontSize: 11,
                    color: isDark ? kDarkTextSec : kLightTextSec)),
          ],
        ),
        actions: [
          // Filter chip row
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 20),
            tooltip: 'Copy all',
            onPressed: _svc.logs.isEmpty ? null : _copyAll,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            tooltip: 'Clear',
            onPressed: _svc.logs.isEmpty ? null : _clearAll,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Level filter bar ──────────────────────────────────────
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            color: isDark ? kDarkCard : Colors.white,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _filterChip(null,            'All',   Colors.blueGrey, isDark),
                _filterChip(LogLevel.fatal,  'FATAL', kDanger,         isDark),
                _filterChip(LogLevel.error,  'ERROR', kWarning,        isDark),
                _filterChip(LogLevel.warning,'WARN',  Colors.orange,   isDark),
                _filterChip(LogLevel.info,   'INFO',  kSuccess,        isDark),
              ],
            ),
          ),

          // ── Log list ──────────────────────────────────────────────
          Expanded(
            child: visible.isEmpty
                ? _EmptyState(hasLogs: _svc.logs.isNotEmpty)
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: visible.length,
                    itemBuilder: (_, i) => _LogCard(
                      entry: visible[i],
                      isDark: isDark,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(LogLevel? level, String label, Color color, bool isDark) {
    final selected = _filter == level;
    return GestureDetector(
      onTap: () => setState(() => _filter = level),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.2) : Colors.transparent,
          border: Border.all(
            color: selected ? color : (isDark ? kDarkBorder : kLightBorder),
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? color : (isDark ? kDarkTextSec : kLightTextSec))),
        ),
      ),
    );
  }
}

// ── Log card ──────────────────────────────────────────────────────────────────

class _LogCard extends StatefulWidget {
  final LogEntry entry;
  final bool isDark;
  const _LogCard({required this.entry, required this.isDark});

  @override
  State<_LogCard> createState() => _LogCardState();
}

class _LogCardState extends State<_LogCard> {
  bool _expanded = false;

  Color get _levelColor {
    switch (widget.entry.level) {
      case LogLevel.fatal:   return kDanger;
      case LogLevel.error:   return kWarning;
      case LogLevel.warning: return Colors.orange;
      case LogLevel.info:    return kSuccess;
    }
  }

  @override
  Widget build(BuildContext context) {
    final e      = widget.entry;
    final isDark = widget.isDark;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      onLongPress: () async {
        await Clipboard.setData(ClipboardData(text: e.formatted));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry copied'),
              duration: Duration(seconds: 1)),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isDark ? kDarkCard : Colors.white,
          border: Border.all(color: _levelColor.withOpacity(0.35)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: _levelColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(e.levelLabel,
                      style: TextStyle(
                          color: _levelColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(e.tag,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? kDarkText : kLightText),
                      overflow: TextOverflow.ellipsis),
                ),
                Text(
                  e.time.toLocal().toString().substring(11, 19),
                  style: TextStyle(
                      fontSize: 10,
                      color: isDark ? kDarkTextSec : kLightTextSec),
                ),
                const SizedBox(width: 4),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: isDark ? kDarkTextSec : kLightTextSec,
                ),
              ]),
            ),

            // Message — collapsed shows 2 lines, expanded shows all
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Text(
                e.message,
                maxLines: _expanded ? null : 2,
                overflow: _expanded ? null : TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    height: 1.5,
                    color: isDark
                        ? kDarkTextSec.withOpacity(0.9)
                        : kLightTextSec),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasLogs;
  const _EmptyState({required this.hasLogs});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(hasLogs ? Icons.filter_list_off_rounded : Icons.bug_report_outlined,
            size: 52, color: kDarkTextSec),
        const SizedBox(height: 12),
        Text(
          hasLogs ? 'No entries match filter' : 'No logs yet',
          style: const TextStyle(color: kDarkTextSec, fontSize: 14),
        ),
        if (!hasLogs) ...[
          const SizedBox(height: 6),
          const Text(
            'Reproduce the crash — logs will appear here',
            style: TextStyle(color: kDarkTextSec, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    ),
  );
}
