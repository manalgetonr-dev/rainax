// lib/providers/download_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/download_task.dart';
import '../services/download_service.dart';

class DownloadProvider extends ChangeNotifier {
  final DownloadService _svc = DownloadService.instance;

  List<DownloadTask> _tasks = [];
  bool _ytdlpAvailable = true;
  bool _isLoading = false;

  List<DownloadTask> get tasks          => _tasks;
  bool get ytdlpAvailable               => _ytdlpAvailable;
  bool get isLoading                    => _isLoading;

  List<DownloadTask> get activeDownloads    => _tasks.where((t) => t.isActive).toList();
  List<DownloadTask> get queuedDownloads    => _tasks.where((t) => t.status == DownloadStatus.queued).toList();
  List<DownloadTask> get completedDownloads => _tasks.where((t) => t.status == DownloadStatus.completed).toList();
  List<DownloadTask> get failedDownloads    => _tasks.where((t) => t.status == DownloadStatus.failed).toList();
  int  get activeCount                  => activeDownloads.length;

  // Expose the shared URL stream from the service layer
  Stream<String> get sharedUrlStream => _svc.sharedUrlStream;

  StreamSubscription? _sub;

  Future<void> init() async {
    await _svc.init();
    _tasks           = _svc.tasks;
    _ytdlpAvailable  = await _svc.checkYtDlp();

    _sub = _svc.taskStream.listen((_) {
      _tasks = _svc.tasks;
      notifyListeners();
    });

    notifyListeners();
  }

  Future<Map<String, dynamic>?> fetchInfo(String url) async {
    _isLoading = true;
    notifyListeners();
    try {
      return await _svc.fetchInfo(url);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<DownloadTask?> addDownload({
    required String url,
    required String title,
    required DownloadFormat format,
    String? thumbnail,
    bool isPlaylist = false,
    int playlistCount = 1,
  }) async {
    final task = await _svc.addDownload(
      url: url, title: title, format: format,
      thumbnail: thumbnail, isPlaylist: isPlaylist, playlistCount: playlistCount,
    );
    _tasks = _svc.tasks;
    notifyListeners();
    return task;
  }

  Future<void> pause(String id)  async { await _svc.pauseDownload(id);   notifyListeners(); }
  Future<void> resume(String id) async { await _svc.resumeDownload(id);  notifyListeners(); }
  Future<void> cancel(String id) async {
    await _svc.cancelDownload(id);
    _tasks = _svc.tasks;
    notifyListeners();
  }
  Future<void> retry(String id)  async { await _svc.retryDownload(id);   notifyListeners(); }
  Future<void> remove(String id) async {
    await _svc.removeTask(id);
    _tasks = _svc.tasks;
    notifyListeners();
  }
  Future<void> clearCompleted()  async {
    await _svc.clearCompleted();
    _tasks = _svc.tasks;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
