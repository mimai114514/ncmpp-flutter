/// Isolate 池实现
/// 复用 Isolate 避免重复创建开销

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import '../core/ncm_dump.dart';

/// 解密任务参数
class DecodeTask {
  final String inputPath;
  final String outputDir;
  final bool useStreaming;
  final int bufferSize;
  final int flushInterval;

  DecodeTask(
    this.inputPath,
    this.outputDir, {
    this.useStreaming = true,
    this.bufferSize = 262144, // 256KB 默认值
    this.flushInterval = 8, // 每 8 块刷新一次
  });
}

/// 解密任务结果
class DecodeTaskResult {
  final String inputPath;
  final String outputPath;
  final bool success;
  final String? errorMessage;

  DecodeTaskResult({
    required this.inputPath,
    required this.outputPath,
    required this.success,
    this.errorMessage,
  });
}

/// Isolate 池
/// 通过复用 Isolate 减少创建开销，提升批量任务执行效率
class IsolatePool {
  final int _maxSize;
  final List<_PooledIsolate> _isolates = [];
  final List<Completer<_PooledIsolate>> _waitingQueue = [];
  bool _isDisposed = false;

  /// 创建 Isolate 池
  /// [maxSize] 池的最大容量，默认为 CPU 核心数
  IsolatePool({int? maxSize})
    : _maxSize = maxSize ?? Platform.numberOfProcessors;

  /// 预热 Isolate 池
  /// [count] 预热的 Isolate 数量，默认为池的最大容量
  Future<void> warmUp([int? count]) async {
    if (_isDisposed) return;

    final warmUpCount = (count ?? _maxSize).clamp(1, _maxSize);
    debugPrint('[IsolatePool] 预热 $warmUpCount 个 Isolate');

    final futures = <Future<void>>[];
    for (var i = _isolates.length; i < warmUpCount; i++) {
      futures.add(_createIsolate());
    }
    await Future.wait(futures);

    debugPrint('[IsolatePool] 预热完成，当前池大小: ${_isolates.length}');
  }

  /// 执行解密任务
  Future<DecodeTaskResult> runDecode(DecodeTask task) async {
    if (_isDisposed) {
      throw StateError('IsolatePool 已被销毁');
    }

    // 获取可用的 Isolate
    final isolate = await _acquireIsolate();

    try {
      // 在 Isolate 中执行任务
      final result = await isolate.runDecode(task);
      return result;
    } finally {
      // 释放 Isolate 回池
      _releaseIsolate(isolate);
    }
  }

  /// 获取可用的 Isolate
  Future<_PooledIsolate> _acquireIsolate() async {
    // 查找空闲的 Isolate
    for (final isolate in _isolates) {
      if (!isolate.isBusy) {
        isolate.isBusy = true;
        return isolate;
      }
    }

    // 如果池未满，创建新的 Isolate
    if (_isolates.length < _maxSize) {
      await _createIsolate();
      final isolate = _isolates.last;
      isolate.isBusy = true;
      return isolate;
    }

    // 池已满，等待释放
    final completer = Completer<_PooledIsolate>();
    _waitingQueue.add(completer);
    return completer.future;
  }

  /// 释放 Isolate 回池
  void _releaseIsolate(_PooledIsolate isolate) {
    if (_isDisposed) return;

    // 如果有等待的任务，直接分配给等待者
    if (_waitingQueue.isNotEmpty) {
      final completer = _waitingQueue.removeAt(0);
      completer.complete(isolate);
    } else {
      isolate.isBusy = false;
    }
  }

  /// 创建新的 Isolate
  Future<void> _createIsolate() async {
    final isolate = await _PooledIsolate.spawn();
    _isolates.add(isolate);
  }

  /// 销毁 Isolate 池
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    debugPrint('[IsolatePool] 销毁 ${_isolates.length} 个 Isolate');

    // 取消所有等待的任务
    for (final completer in _waitingQueue) {
      completer.completeError(StateError('IsolatePool 已被销毁'));
    }
    _waitingQueue.clear();

    // 销毁所有 Isolate
    for (final isolate in _isolates) {
      isolate.dispose();
    }
    _isolates.clear();
  }

  /// 获取是否已销毁
  bool get isDisposed => _isDisposed;

  /// 获取当前池大小
  int get size => _isolates.length;

  /// 获取空闲 Isolate 数量
  int get availableCount => _isolates.where((i) => !i.isBusy).length;

  /// 获取繁忙 Isolate 数量
  int get busyCount => _isolates.where((i) => i.isBusy).length;
}

/// 池化的 Isolate
class _PooledIsolate {
  final Isolate _isolate;
  final SendPort _sendPort;
  final ReceivePort _resultPort;
  bool isBusy = false;
  int _taskId = 0;
  final Map<int, Completer<DecodeTaskResult>> _pendingTasks = {};

  _PooledIsolate._(this._isolate, this._sendPort, this._resultPort) {
    _resultPort.listen(_handleMessage);
  }

  /// 创建池化的 Isolate
  static Future<_PooledIsolate> spawn() async {
    final initPort = ReceivePort();
    final isolate = await Isolate.spawn(_isolateEntry, initPort.sendPort);

    // 等待 Isolate 发送其 SendPort
    final sendPort = await initPort.first as SendPort;
    initPort.close();

    // 创建结果接收端口
    final resultPort = ReceivePort();
    sendPort.send(resultPort.sendPort);

    return _PooledIsolate._(isolate, sendPort, resultPort);
  }

  /// 处理从 Isolate 收到的消息
  void _handleMessage(dynamic message) {
    if (message is _TaskResponse) {
      final completer = _pendingTasks.remove(message.taskId);
      if (completer != null) {
        completer.complete(message.result);
      }
    }
  }

  /// 执行解密任务
  Future<DecodeTaskResult> runDecode(DecodeTask task) async {
    final taskId = _taskId++;
    final completer = Completer<DecodeTaskResult>();
    _pendingTasks[taskId] = completer;

    _sendPort.send(_TaskRequest(taskId, task));

    return completer.future;
  }

  /// 销毁此 Isolate
  void dispose() {
    _resultPort.close();
    _isolate.kill(priority: Isolate.immediate);
  }
}

/// Isolate 入口函数
void _isolateEntry(SendPort mainSendPort) {
  final receivePort = ReceivePort();
  mainSendPort.send(receivePort.sendPort);

  SendPort? resultPort;
  final ncmDump = NcmDump(); // 复用 NcmDump 实例

  receivePort.listen((message) async {
    if (message is SendPort) {
      resultPort = message;
      return;
    }

    if (message is _TaskRequest && resultPort != null) {
      final task = message.task;

      // 根据任务参数选择解密方式
      final (success, outputPath, errorMessage) = task.useStreaming
          ? await ncmDump.decodeStreaming(
              task.inputPath,
              task.outputDir,
              bufferSize: task.bufferSize,
              flushInterval: task.flushInterval,
            )
          : await ncmDump.decode(task.inputPath, task.outputDir);

      resultPort!.send(
        _TaskResponse(
          message.taskId,
          DecodeTaskResult(
            inputPath: task.inputPath,
            outputPath: outputPath,
            success: success,
            errorMessage: errorMessage,
          ),
        ),
      );
    }
  });
}

/// 任务请求
class _TaskRequest {
  final int taskId;
  final DecodeTask task;

  _TaskRequest(this.taskId, this.task);
}

/// 任务响应
class _TaskResponse {
  final int taskId;
  final DecodeTaskResult result;

  _TaskResponse(this.taskId, this.result);
}
