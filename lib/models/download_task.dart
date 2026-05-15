// lib/models/download_task.dart

import 'package:flutter/material.dart';

enum DownloadStatus {
  queued, starting, running, paused, cancelling, cancelled, completed, failed,
}

enum DownloadFormat {
  bestAuto, mp4_1080p, mp4_720p, mp4_480p, mp4_360p, mp3, m4a, worstAuto,
}

extension DownloadFormatExt on DownloadFormat {
  String get label {
    switch (this) {
      case DownloadFormat.bestAuto:  return 'Best Quality';
      case DownloadFormat.mp4_1080p: return 'MP4 1080p';
      case DownloadFormat.mp4_720p:  return 'MP4 720p';
      case DownloadFormat.mp4_480p:  return 'MP4 480p';
      case DownloadFormat.mp4_360p:  return 'MP4 360p';
      case DownloadFormat.mp3:       return 'MP3 Audio';
      case DownloadFormat.m4a:       return 'M4A Audio';
      case DownloadFormat.worstAuto: return 'Smallest Size';
    }
  }

  String get ytdlpFormat {
    switch (this) {
      case DownloadFormat.bestAuto:  return 'bv*+ba/b';
      case DownloadFormat.mp4_1080p: return 'bv*[height<=1080][ext=mp4]+ba[ext=m4a]/bv*[height<=1080]+ba/b[height<=1080]';
      case DownloadFormat.mp4_720p:  return 'bv*[height<=720][ext=mp4]+ba[ext=m4a]/bv*[height<=720]+ba/b[height<=720]';
      case DownloadFormat.mp4_480p:  return 'bv*[height<=480][ext=mp4]+ba[ext=m4a]/bv*[height<=480]+ba/b[height<=480]';
      case DownloadFormat.mp4_360p:  return 'bv*[height<=360][ext=mp4]+ba[ext=m4a]/bv*[height<=360]+ba/b[height<=360]';
      case DownloadFormat.mp3:       return 'ba/b';
      case DownloadFormat.m4a:       return 'ba[ext=m4a]/ba/b';
      case DownloadFormat.worstAuto: return 'worst';
    }
  }

  bool get isAudioOnly => this == DownloadFormat.mp3 || this == DownloadFormat.m4a;
  bool get isMp3       => this == DownloadFormat.mp3;
  IconData get icon    => isAudioOnly ? Icons.music_note_rounded : Icons.videocam_rounded;
}

class DownloadTask extends ChangeNotifier {
  final String id, url, title, outputDir;
  final String? thumbnail;
  final DownloadFormat format;
  final bool isPlaylist;
  final int playlistCount;
  final DateTime addedAt;

  DownloadStatus _status = DownloadStatus.queued;
  double _progress = 0.0;
  String _speed = '', _eta = '', _filename = '', _filePath = '', _errorMessage = '';
  int _playlistDone = 0;

  DownloadTask({
    required this.id, required this.url, required this.title,
    required this.format, required this.outputDir,
    this.thumbnail, this.isPlaylist = false, this.playlistCount = 1, DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  DownloadStatus get status    => _status;
  double get progress          => _progress;
  String get speed             => _speed;
  String get eta               => _eta;
  String get filename          => _filename;
  String get filePath          => _filePath;
  String get errorMessage      => _errorMessage;
  int get playlistDone         => _playlistDone;

  bool get isTerminal => _status == DownloadStatus.completed ||
      _status == DownloadStatus.failed || _status == DownloadStatus.cancelled;
  bool get isActive   => _status == DownloadStatus.running || _status == DownloadStatus.starting;
  bool get canPause   => _status == DownloadStatus.running;
  bool get canResume  => _status == DownloadStatus.paused;
  bool get canCancel  => !isTerminal;
  bool get canRetry   => _status == DownloadStatus.failed;

  void updateProgress({
    required double percent, required String speed, required String eta,
    required String filename, required DownloadStatus status, String error = '',
  }) {
    _progress  = percent.clamp(0.0, 100.0);
    _speed     = speed; _eta = eta;
    if (filename.isNotEmpty) _filename = filename;
    _status = status;
    if (error.isNotEmpty) _errorMessage = error;
    notifyListeners();
  }

  void setCompleted(String path) {
    _status = DownloadStatus.completed; _progress = 100.0;
    _filePath = path; _speed = ''; _eta = '';
    notifyListeners();
  }
  void setFailed(String err)   { _status = DownloadStatus.failed;     _errorMessage = err; notifyListeners(); }
  void setPaused()             { _status = DownloadStatus.paused;      notifyListeners(); }
  void setResumed()            { _status = DownloadStatus.running;     notifyListeners(); }
  void setCancelled()          { _status = DownloadStatus.cancelled;   notifyListeners(); }
  void incrementPlaylistDone() { _playlistDone++;                       notifyListeners(); }

  Map<String, dynamic> toJson() => {
    'id': id, 'url': url, 'title': title, 'thumbnail': thumbnail,
    'format': format.index, 'isPlaylist': isPlaylist, 'playlistCount': playlistCount,
    'outputDir': outputDir, 'status': _status.index, 'progress': _progress,
    'filePath': _filePath, 'addedAt': addedAt.toIso8601String(),
  };

  factory DownloadTask.fromJson(Map<String, dynamic> j) {
    final t = DownloadTask(
      id: j['id'] as String, url: j['url'] as String, title: j['title'] as String? ?? '',
      thumbnail: j['thumbnail'] as String?, format: DownloadFormat.values[j['format'] as int? ?? 0],
      isPlaylist: j['isPlaylist'] as bool? ?? false, playlistCount: j['playlistCount'] as int? ?? 1,
      outputDir: j['outputDir'] as String? ?? '',
      addedAt: DateTime.tryParse(j['addedAt'] as String? ?? '') ?? DateTime.now(),
    );
    t._status   = DownloadStatus.values[j['status'] as int? ?? 0];
    t._progress = (j['progress'] as num?)?.toDouble() ?? 0.0;
    t._filePath = j['filePath'] as String? ?? '';
    return t;
  }
}
