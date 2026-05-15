// lib/screens/add_download_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/download_task.dart';
import '../providers/download_provider.dart';
import '../theme.dart';
import '../widgets/format_chip.dart';
import '../widgets/video_info_card.dart';

class AddDownloadSheet extends StatefulWidget {
  final String? prefillUrl;
  const AddDownloadSheet({super.key, this.prefillUrl});

  @override
  State<AddDownloadSheet> createState() => _AddDownloadSheetState();
}

class _AddDownloadSheetState extends State<AddDownloadSheet> {
  final _urlCtrl    = TextEditingController();
  final _urlFocus   = FocusNode();
  DownloadFormat    _format   = DownloadFormat.bestAuto;
  Map<String, dynamic>? _info;
  bool _fetching    = false;
  String? _fetchErr;
  bool _playlist    = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefillUrl != null) {
      _urlCtrl.text = widget.prefillUrl!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchInfo());
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _urlFocus.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null && mounted) {
      _urlCtrl.text = data!.text!;
      _fetchInfo();
    }
  }

  Future<void> _fetchInfo() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    // Basic URL validation before hitting the network
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      setState(() {
        _fetchErr = 'Please enter a valid URL starting with http:// or https://';
        _fetching = false;
      });
      return;
    }
    setState(() { _fetching = true; _fetchErr = null; _info = null; });
    try {
      final info = await context.read<DownloadProvider>().fetchInfo(url);
      if (!mounted) return;
      if (info == null) {
        setState(() {
          _fetchErr = 'Could not fetch video info. Check the URL and try again.';
          _fetching = false;
        });
        return;
      }
      if (info.containsKey('error')) {
        setState(() {
          _fetchErr = info['error']?.toString() ?? 'Unknown error';
          _fetching = false;
        });
        return;
      }
      setState(() {
        _info      = info;
        _fetching  = false;
        _playlist  = info['is_playlist'] == true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fetchErr = e.toString().replaceFirst('Exception: ', '');
        _fetching = false;
      });
    }
  }

  Future<void> _startDownload() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;

    final prov = context.read<DownloadProvider>();
    await prov.addDownload(
      url:           url,
      title:         _info?['title'] as String? ?? url,
      format:        _format,
      thumbnail:     _info?['thumbnail'] as String?,
      isPlaylist:    _playlist,
      playlistCount: (_info?['entry_count'] as int?) ?? 1,
    );
    if (mounted) Navigator.pop(context);
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? kDarkCard : Colors.white;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            // ── Drag handle ────────────────────────────────────────────
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: isDark ? kDarkBorder : kLightBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Title ──────────────────────────────────────────────────
            Text('New Download',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),

            // ── URL field ──────────────────────────────────────────────
            Row(children: [
              Expanded(
                child: TextField(
                  controller:  _urlCtrl,
                  focusNode:   _urlFocus,
                  decoration:  const InputDecoration(
                    hintText:    'Paste YouTube or web URL…',
                    prefixIcon:  Icon(Icons.link_rounded, size: 18),
                  ),
                  keyboardType: TextInputType.url,
                  onSubmitted:  (_) => _fetchInfo(),
                ),
              ),
              const SizedBox(width: 8),
              _iconBtn(
                icon: Icons.content_paste_rounded,
                tooltip: 'Paste',
                onTap: _pasteFromClipboard,
                isDark: isDark,
              ),
              const SizedBox(width: 6),
              _iconBtn(
                icon: Icons.search_rounded,
                tooltip: 'Fetch info',
                onTap: _fetchInfo,
                isDark: isDark,
                accent: true,
              ),
            ]),

            const SizedBox(height: 16),

            // ── Video info card ────────────────────────────────────────
            if (_fetching) ...[
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 16),
            ] else if (_fetchErr != null) ...[
              _ErrorBanner(message: _fetchErr!),
              const SizedBox(height: 12),
            ] else if (_info != null) ...[
              VideoInfoCard(info: _info!),
              const SizedBox(height: 16),
              if (_info!['is_playlist'] == true) ...[
                _PlaylistToggle(
                  count: (_info!['entry_count'] as int?) ?? 0,
                  downloadAll: _playlist,
                  onToggle: (v) => setState(() => _playlist = v),
                ),
                const SizedBox(height: 12),
              ],
            ],

            // ── Format selector ────────────────────────────────────────
            Text('Format & Quality',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? kDarkTextSec : kLightTextSec)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: DownloadFormat.values.map((f) => FormatChip(
                label:    f.label,
                icon:     f.isAudioOnly
                              ? Icons.music_note_rounded
                              : Icons.videocam_rounded,
                selected: _format == f,
                onTap:    () => setState(() => _format = f),
              )).toList(),
            ),

            const SizedBox(height: 28),

            // ── Download button ────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _urlCtrl.text.trim().isEmpty ? null : _startDownload,
                icon:  const Icon(Icons.download_rounded, size: 20),
                label: Text(_playlist
                    ? 'Download Playlist (${(_info?["entry_count"] as int?) ?? "?"} videos)'
                    : 'Start Download'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required bool isDark,
    bool accent = false,
  }) {
    return Material(
      color: accent ? kAccent : (isDark ? kDarkHover : kLightBgSecondary),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Icon(icon,
                size: 20,
                color: accent ? Colors.white
                              : (isDark ? kDarkText : kLightText)),
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: kDanger.withOpacity(0.1),
      border: Border.all(color: kDanger.withOpacity(0.3)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded, color: kDanger, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(message,
          style: const TextStyle(color: kDanger, fontSize: 13))),
    ]),
  );
}

class _PlaylistToggle extends StatelessWidget {
  final int count;
  final bool downloadAll;
  final ValueChanged<bool> onToggle;
  const _PlaylistToggle({
    required this.count,
    required this.downloadAll,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kAccent.withOpacity(0.08),
        border: Border.all(color: kAccent.withOpacity(0.25)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        const Icon(Icons.playlist_play_rounded, color: kAccent, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text('Playlist – $count videos',
              style: TextStyle(
                  color: isDark ? kDarkText : kLightText,
                  fontWeight: FontWeight.w500)),
        ),
        Switch(
          value:          downloadAll,
          onChanged:      onToggle,
          activeColor:    kAccent,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ]),
    );
  }
}
