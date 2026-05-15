// lib/services/download_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/download_task.dart';

const _downloadChannel = MethodChannel('com.rainax.downloader/download');
const _progressChannel = EventChannel('com.rainax.downloader/progress');
const _ytdlpChannel    = MethodChannel('com.rainax.downloader/ytdlp');

class DownloadService {
  DownloadService._();
  static final DownloadService instance = DownloadService._();

  final _uuid = const Uuid();
  final Map<String, DownloadTask> _tasks = {};

  final _taskController     = StreamController<DownloadTask>.broadcast();
  final _sharedUrlController = StreamController<String>.broadcast();

  Stream<DownloadTask> get taskStream      => _taskController.stream;
  Stream<String>       get sharedUrlStream => _sharedUrlController.stream;

  StreamSubscription? _progressSub;

  // ── Init ──────────────────────────────────────────────────────────

  Future<void> init() async {
    await _loadPersistedTasks();
    _subscribeToProgress();
    _downloadChannel.setMethodCallHandler(_onNativeCall);
  }

  void _subscribeToProgress() {
    _progressSub?.cancel();
    _progressSub = _progressChannel.receiveBroadcastStream().listen(
      _onProgressEvent,
      onError: (_) {
        // Re-subscribe after a short delay on channel error
        Future.delayed(const Duration(seconds: 1), _subscribeToProgress);
      },
    );
  }

  Future<dynamic> _onNativeCall(MethodCall call) async {
    if (call.method == 'onSharedUrl') {
      final url = (call.arguments as Map?)?['url'] as String? ?? '';
      if (url.isNotEmpty) _sharedUrlController.add(url);
    }
  }

  // ── Accessors ─────────────────────────────────────────────────────

  List<DownloadTask> get tasks =>
      _tasks.values.toList()
        ..sort((a, b) => b.addedAt.compareTo(a.addedAt));

  // ── Download CRUD ──────────────────────────────────────────────────

  Future<DownloadTask> addDownload({
    required String url,
    required String title,
    required DownloadFormat format,
    String? thumbnail,
    bool isPlaylist = false,
    int playlistCount = 1,
  }) async {
    final outputDir = await _outputDirFor(format);
    final task = DownloadTask(
      id: _uuid.v4(),
      url: url,
      title: title,
      thumbnail: thumbnail,
      format: format,
      isPlaylist: isPlaylist,
      playlistCount: playlistCount,
      outputDir: outputDir,
    );
    _tasks[task.id] = task;
    await _persistTasks();
    await _invokeStart(task);
    _taskController.add(task);
    return task;
  }

  Future<void> pauseDownload(String taskId) async {
    await _downloadChannel.invokeMethod('pauseDownload', {'taskId': taskId});
    _tasks[taskId]?.setPaused();
    _notifyTask(taskId);
  }

  Future<void> resumeDownload(String taskId) async {
    await _downloadChannel.invokeMethod('resumeDownload', {'taskId': taskId});
    _tasks[taskId]?.setResumed();
    _notifyTask(taskId);
  }

  Future<void> cancelDownload(String taskId) async {
    await _downloadChannel.invokeMethod('cancelDownload', {'taskId': taskId});
    _tasks[taskId]?.setCancelled();
    _notifyTask(taskId);
    await _persistTasks();
  }

  Future<void> retryDownload(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) return;
    task.updateProgress(
      percent: 0, speed: '', eta: '', filename: '',
      status: DownloadStatus.queued,
    );
    await _invokeStart(task);
    _notifyTask(taskId);
  }

  Future<void> removeTask(String taskId) async {
    _tasks.remove(taskId);
    await _persistTasks();
  }

  Future<void> clearCompleted() async {
    _tasks.removeWhere((_, t) => t.isTerminal);
    await _persistTasks();
  }

  // ── yt-dlp info ───────────────────────────────────────────────────

  Future<Map<String, dynamic>?> fetchInfo(String url) async {
    try {
      final result = await _ytdlpChannel.invokeMethod('fetchInfo', {'url': url});
      if (result == null) return null;
      return _deepCast(result as Map);
    } on PlatformException catch (e) {
      throw Exception(e.message ?? 'Failed to fetch video info');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  /// Recursively converts Map<Object?,Object?> → Map<String,dynamic>
  Map<String, dynamic> _deepCast(Map raw) {
    return raw.map((k, v) {
      final key = k?.toString() ?? '';
      dynamic val;
      if (v is Map)  val = _deepCast(v);
      else if (v is List) val = v.map((e) => e is Map ? _deepCast(e) : e).toList();
      else val = v;
      return MapEntry(key, val);
    });
  }

  Future<bool> checkYtDlp() async {
    try {
      return await _ytdlpChannel.invokeMethod('checkYtDlp') as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  // ── Internal helpers ──────────────────────────────────────────────

  Future<void> _invokeStart(DownloadTask task) async {
    try {
      await _downloadChannel.invokeMethod('startDownload', {
        'taskId':    task.id,
        'url':       task.url,
        'format':    task.format.ytdlpFormat,
        'outputDir': task.outputDir,
        'audioOnly': task.format.isAudioOnly,
        'mp3':       task.format.isMp3,
        'playlist':  task.isPlaylist,
        'quality':   task.format.label,
      });
    } on PlatformException catch (e) {
      task.setFailed(e.message ?? 'Failed to start download service');
      _taskController.add(task);
    } catch (e) {
      task.setFailed(e.toString());
      _taskController.add(task);
    }
  }

  void _notifyTask(String taskId) {
    final t = _tasks[taskId];
    if (t != null) _taskController.add(t);
  }

  void _onProgressEvent(dynamic raw) {
    if (raw == null) return;
    final e      = Map<String, dynamic>.from(raw as Map);
    final taskId = e['taskId'] as String? ?? '';
    final task   = _tasks[taskId];
    if (task == null) return;

    final status   = e['status']   as String? ?? '';
    final percent  = (e['percent'] as num?)?.toDouble() ?? 0.0;
    final speed    = e['speed']    as String? ?? '';
    final eta      = e['eta']      as String? ?? '';
    final filename = e['filename'] as String? ?? '';
    final filePath = e['filePath'] as String? ?? '';
    final error    = e['error']    as String? ?? '';

    switch (status) {
      case 'STARTING':
        task.updateProgress(
          percent: 0, speed: '', eta: '', filename: '',
          status: DownloadStatus.starting,
        );
      case 'RUNNING':
        task.updateProgress(
          percent: percent, speed: speed, eta: eta,
          filename: filename, status: DownloadStatus.running,
        );
      case 'COMPLETED':
        task.setCompleted(filePath.isEmpty ? filename : filePath);
        _persistTasks();
      case 'FAILED':
        task.setFailed(error);
        _persistTasks();
      case 'PAUSED':
        task.setPaused();
      case 'CANCELLED':
        task.setCancelled();
        _persistTasks();
    }
    _taskController.add(task);
  }

  Future<String> _outputDirFor(DownloadFormat format) async {
    final base = await getExternalStorageDirectory()
               ?? await getApplicationDocumentsDirectory();
    final sub  = format.isAudioOnly ? 'Music' : 'Videos';
    return '${base.path}/RAINAX/$sub';
  }

  Future<void> _persistTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final list  = _tasks.values
        .where((t) => !t.isTerminal || t.status == DownloadStatus.completed)
        .map((t) => jsonEncode(t.toJson()))
        .toList();
    await prefs.setStringList('rainax_tasks_v1', list);
  }

  Future<void> _loadPersistedTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final list  = prefs.getStringList('rainax_tasks_v1') ?? [];
    for (final raw in list) {
      try {
        final task = DownloadTask.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
        // Tasks that were mid-download when the app was killed → reset to queued
        if (task.status == DownloadStatus.running ||
            task.status == DownloadStatus.starting) {
          task.updateProgress(
            percent: task.progress, speed: '', eta: '',
            filename: task.filename, status: DownloadStatus.queued,
          );
        }
        _tasks[task.id] = task;
      } catch (_) {}
    }
  }

  void dispose() {
    _progressSub?.cancel();
    _taskController.close();
    _sharedUrlController.close();
  }
}
