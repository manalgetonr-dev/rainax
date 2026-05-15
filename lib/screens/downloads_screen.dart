// lib/screens/downloads_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/download_task.dart';
import '../providers/download_provider.dart';
import '../theme.dart';
import '../widgets/download_card.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 80,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              title: Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [kAccent, kAccent2],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.download_rounded,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                const Text('RAINAX',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5)),
              ]),
            ),
            actions: [
              Consumer<DownloadProvider>(
                builder: (_, prov, __) =>
                    prov.tasks.any((t) => t.isTerminal)
                        ? IconButton(
                            icon: const Icon(Icons.clear_all_rounded),
                            tooltip: 'Clear finished',
                            onPressed: prov.clearCompleted,
                          )
                        : const SizedBox.shrink(),
              ),
            ],
          ),

          // ── Stats bar ──────────────────────────────────────────────
          SliverToBoxAdapter(child: _StatsBar()),

          // ── Task list ──────────────────────────────────────────────
          Consumer<DownloadProvider>(
            builder: (_, prov, __) {
              final tasks = prov.tasks;
              if (tasks.isEmpty) {
                return SliverFillRemaining(
                  child: _EmptyState(),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => DownloadCard(task: tasks[i]),
                    childCount: tasks.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Stats bar ─────────────────────────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer<DownloadProvider>(
      builder: (_, prov, __) {
        final active    = prov.activeCount;
        final queued    = prov.queuedDownloads.length;
        final completed = prov.completedDownloads.length;
        final failed    = prov.failedDownloads.length;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? kDarkCard : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: isDark ? kDarkBorder : kLightBorder, width: 0.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Stat(label: 'Active',    value: '$active',    color: kAccent),
              _divider(isDark),
              _Stat(label: 'Queued',    value: '$queued',    color: kWarning),
              _divider(isDark),
              _Stat(label: 'Done',      value: '$completed', color: kSuccess),
              _divider(isDark),
              _Stat(label: 'Failed',    value: '$failed',    color: kDanger),
            ],
          ),
        );
      },
    );
  }

  Widget _divider(bool isDark) => Container(
    width: 0.5, height: 28,
    color: isDark ? kDarkBorder : kLightBorder,
  );
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(children: [
      Text(value,
          style: TextStyle(
              color: color, fontSize: 18, fontWeight: FontWeight.w700)),
      Text(label,
          style: TextStyle(
              color: isDark ? kDarkTextSec : kLightTextSec,
              fontSize: 11)),
    ]);
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_download_outlined,
              size: 72, color: isDark ? kDarkBorder : kLightBorder),
          const SizedBox(height: 16),
          Text('No downloads yet',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600,
                  color: isDark ? kDarkTextSec : kLightTextSec)),
          const SizedBox(height: 8),
          Text('Tap + to add a YouTube or web URL',
              style: TextStyle(
                  fontSize: 13,
                  color: (isDark ? kDarkTextSec : kLightTextSec)
                      .withOpacity(0.7))),
        ],
      ),
    );
  }
}
