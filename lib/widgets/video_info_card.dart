// lib/widgets/video_info_card.dart

import 'package:flutter/material.dart';
import '../theme.dart';

class VideoInfoCard extends StatelessWidget {
  final Map<String, dynamic> info;
  const VideoInfoCard({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final title      = info['title'] as String? ?? '';
    final uploader   = info['uploader'] as String? ?? '';
    final thumb      = info['thumbnail'] as String? ?? '';
    final durationS  = info['duration'];
    final isPlaylist = info['is_playlist'] == true;
    final count      = info['entry_count'] as int? ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? kDarkHover : kLightBgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? kDarkBorder : kLightBorder, width: 0.5),
      ),
      child: Row(
        children: [
          // Thumbnail
          if (thumb.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(11)),
              child: Image.network(
                thumb, width: 80, height: 60, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(width: 0),
              ),
            ),

          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isPlaylist ? 'Playlist – $count videos' : title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: isDark ? kDarkText : kLightText,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  if (uploader.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(uploader,
                        style: TextStyle(
                            fontSize: 11,
                            color: isDark ? kDarkTextSec : kLightTextSec)),
                  ],
                  if (durationS != null && !isPlaylist) ...[
                    const SizedBox(height: 3),
                    Text(_fmtDuration(durationS),
                        style: const TextStyle(
                            fontSize: 11, color: kAccent)),
                  ],
                ],
              ),
            ),
          ),

          // Check icon
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.check_circle_rounded,
                color: kSuccess, size: 18),
          ),
        ],
      ),
    );
  }

  String _fmtDuration(dynamic secs) {
    final s = (secs as num?)?.toInt() ?? 0;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) return '${h}h ${m}m ${sec}s';
    if (m > 0) return '${m}m ${sec}s';
    return '${sec}s';
  }
}
