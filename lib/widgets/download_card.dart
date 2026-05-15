// lib/widgets/download_card.dart

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import '../models/download_task.dart';
import '../providers/download_provider.dart';
import '../theme.dart';

class DownloadCard extends StatelessWidget {
  final DownloadTask task;
  const DownloadCard({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: task,
      builder: (_, __) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: isDark ? kDarkCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _borderColor(task.status).withOpacity(0.3),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              // ── Main row ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thumbnail / icon
                    _Thumbnail(task: task),
                    const SizedBox(width: 12),

                    // Title + meta
                    Expanded(child: _Info(task: task, isDark: isDark)),

                    // Action buttons
                    _Actions(task: task),
                  ],
                ),
              ),

              // ── Progress bar (only when active) ────────────────────
              if (task.isActive || task.status == DownloadStatus.paused) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: _ProgressRow(task: task, isDark: isDark),
                ),
              ],

              // ── Error message ───────────────────────────────────────
              if (task.status == DownloadStatus.failed &&
                  task.errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: Text(
                    task.errorMessage,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: kDanger, fontSize: 11),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Color _borderColor(DownloadStatus s) {
    switch (s) {
      case DownloadStatus.running:   return kAccent;
      case DownloadStatus.completed: return kSuccess;
      case DownloadStatus.failed:    return kDanger;
      case DownloadStatus.paused:    return kWarning;
      default:                       return Colors.transparent;
    }
  }
}

// ── Thumbnail ─────────────────────────────────────────────────────────────────

class _Thumbnail extends StatelessWidget {
  final DownloadTask task;
  const _Thumbnail({required this.task});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final thumb  = task.thumbnail;

    return Container(
      width: 56, height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: isDark ? kDarkHover : kLightBgSecondary,
      ),
      clipBehavior: Clip.antiAlias,
      child: thumb != null && thumb.isNotEmpty
          ? Image.network(
              thumb,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallbackIcon(),
            )
          : _fallbackIcon(),
    );
  }

  Widget _fallbackIcon() => Icon(
    task.format.isAudioOnly
        ? Icons.music_note_rounded
        : Icons.play_circle_outline_rounded,
    color: kAccent.withOpacity(0.6),
    size: 28,
  );
}

// ── Info ──────────────────────────────────────────────────────────────────────

class _Info extends StatelessWidget {
  final DownloadTask task;
  final bool isDark;
  const _Info({required this.task, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          task.title.isEmpty
              ? Uri.tryParse(task.url)?.host ?? task.url
              : task.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isDark ? kDarkText : kLightText,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 5),
        Row(children: [
          _StatusBadge(status: task.status),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: kAccent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(task.format.label,
                style: const TextStyle(color: kAccent,
                    fontSize: 10, fontWeight: FontWeight.w600)),
          ),
        ]),
        if (task.isPlaylist) ...[
          const SizedBox(height: 4),
          Text('Playlist · ${task.playlistDone}/${task.playlistCount}',
              style: TextStyle(
                  color: isDark ? kDarkTextSec : kLightTextSec,
                  fontSize: 11)),
        ],
      ],
    );
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final DownloadStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      DownloadStatus.queued    => ('Queued',      kDarkTextSec),
      DownloadStatus.starting  => ('Starting…',  kWarning),
      DownloadStatus.running   => ('Downloading', kAccent),
      DownloadStatus.paused    => ('Paused',      kWarning),
      DownloadStatus.cancelling=> ('Cancelling…', kDanger),
      DownloadStatus.cancelled => ('Cancelled',   kDarkTextSec),
      DownloadStatus.completed => ('Complete',    kSuccess),
      DownloadStatus.failed    => ('Failed',      kDanger),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(color: color,
              fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Progress row ──────────────────────────────────────────────────────────────

class _ProgressRow extends StatelessWidget {
  final DownloadTask task;
  final bool isDark;
  const _ProgressRow({required this.task, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final pct     = task.progress / 100.0;
    final isActive = task.isActive;
    final color   = task.status == DownloadStatus.paused ? kWarning : kAccent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: isActive && task.progress == 0 ? null : pct,
            minHeight: 5,
            backgroundColor: isDark ? kDarkBorder : kLightBorder,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Text('${task.progress.toStringAsFixed(1)}%',
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          if (task.speed.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(task.speed,
                style: TextStyle(
                    color: isDark ? kDarkTextSec : kLightTextSec,
                    fontSize: 11)),
          ],
          const Spacer(),
          if (task.eta.isNotEmpty)
            Text('ETA ${task.eta}',
                style: TextStyle(
                    color: isDark ? kDarkTextSec : kLightTextSec,
                    fontSize: 11)),
        ]),
      ],
    );
  }
}

// ── Action buttons ────────────────────────────────────────────────────────────

class _Actions extends StatelessWidget {
  final DownloadTask task;
  const _Actions({required this.task});

  @override
  Widget build(BuildContext context) {
    final prov   = context.read<DownloadProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pause / Resume
        if (task.canPause)
          _btn(Icons.pause_rounded, kWarning,
              () => prov.pause(task.id))
        else if (task.canResume)
          _btn(Icons.play_arrow_rounded, kSuccess,
              () => prov.resume(task.id)),

        // Open file (completed)
        if (task.status == DownloadStatus.completed &&
            task.filePath.isNotEmpty)
          _btn(Icons.folder_open_rounded, kAccent,
              () => OpenFilex.open(task.filePath)),

        // Retry (failed)
        if (task.canRetry)
          _btn(Icons.refresh_rounded, kAccent,
              () => prov.retry(task.id)),

        // Cancel / Remove
        if (task.canCancel)
          _btn(Icons.close_rounded, kDanger,
              () => prov.cancel(task.id))
        else
          _btn(Icons.delete_outline_rounded,
              isDark ? kDarkTextSec : kLightTextSec,
              () => prov.remove(task.id)),
      ],
    );
  }

  Widget _btn(IconData icon, Color color, VoidCallback onTap) =>
      InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: color),
        ),
      );
}
