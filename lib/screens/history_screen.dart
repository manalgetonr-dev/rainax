// lib/screens/history_screen.dart

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import '../models/download_task.dart';
import '../providers/download_provider.dart';
import '../theme.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Download History',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          Consumer<DownloadProvider>(
            builder: (_, prov, __) =>
                prov.completedDownloads.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_all_rounded),
                        onPressed: prov.clearCompleted,
                      )
                    : const SizedBox.shrink(),
          ),
        ],
      ),
      body: Consumer<DownloadProvider>(
        builder: (_, prov, __) {
          final completed = prov.completedDownloads;
          if (completed.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_rounded,
                      size: 64,
                      color: isDark ? kDarkBorder : kLightBorder),
                  const SizedBox(height: 12),
                  Text('No completed downloads',
                      style: TextStyle(
                          color: isDark ? kDarkTextSec : kLightTextSec)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: completed.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) => _HistoryItem(task: completed[i]),
          );
        },
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final DownloadTask task;
  const _HistoryItem({required this.task});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      tileColor:    isDark ? kDarkCard : Colors.white,
      shape:        RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
      leading: CircleAvatar(
        backgroundColor: kSuccess.withOpacity(0.15),
        child: Icon(
          task.format.isAudioOnly
              ? Icons.music_note_rounded
              : Icons.movie_rounded,
          color: kSuccess, size: 18,
        ),
      ),
      title: Text(task.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
      subtitle: Text(
        '${task.format.label}  ·  ${_fmt(task.addedAt)}',
        style: TextStyle(
            fontSize: 11,
            color: isDark ? kDarkTextSec : kLightTextSec),
      ),
      trailing: task.filePath.isNotEmpty
          ? IconButton(
              icon: const Icon(Icons.folder_open_rounded,
                  color: kAccent, size: 20),
              onPressed: () => OpenFilex.open(task.filePath),
            )
          : null,
    );
  }

  String _fmt(DateTime dt) {
    final now  = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
