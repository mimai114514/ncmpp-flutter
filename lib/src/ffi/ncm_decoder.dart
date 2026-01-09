/// NCM 解密器服务
/// 提供高层封装，支持 Isolate 后台解密

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/ncm_dump.dart';

/// 解密结果
class DecodeResult {
  final String inputPath;
  final String outputPath;
  final bool success;
  final String? errorMessage;

  DecodeResult({
    required this.inputPath,
    required this.outputPath,
    required this.success,
    this.errorMessage,
  });

  @override
  String toString() {
    if (success) {
      return 'DecodeResult(success: $inputPath -> $outputPath)';
    } else {
      return 'DecodeResult(failed: $inputPath, error: $errorMessage)';
    }
  }
}

/// 批量解密进度
class BatchDecodeProgress {
  final int total;
  final int completed;
  final int failed;
  final String? currentFile;

  BatchDecodeProgress({
    required this.total,
    required this.completed,
    required this.failed,
    this.currentFile,
  });

  double get progress => total > 0 ? (completed + failed) / total : 0;
  bool get isComplete => completed + failed >= total;
}

/// NCM 解密器
class NcmDecoder {
  static final NcmDecoder _instance = NcmDecoder._();
  static NcmDecoder get instance => _instance;

  NcmDecoder._();

  /// 解密单个文件（在后台 Isolate 执行）
  Future<DecodeResult> decodeFile(String inputPath, String outputDir) async {
    final result = await compute(_decodeInIsolate, [inputPath, outputDir]);
    return result;
  }

  /// 扫描目录中的所有 NCM 文件
  Future<List<String>> scanNcmFiles(String directoryPath) async {
    final dir = Directory(directoryPath);

    // 检查目录是否存在
    bool exists;
    try {
      exists = await dir.exists();
      debugPrint('[NCM扫描] 目录存在检查: $directoryPath -> $exists');
    } catch (e) {
      debugPrint('[NCM扫描] 检查目录存在时出错: $e');
      return [];
    }

    if (!exists) {
      debugPrint('[NCM扫描] 目录不存在: $directoryPath');
      return [];
    }

    final files = <String>[];
    try {
      // 使用 listSync 同步列出文件，在某些情况下更稳定
      final entities = dir.listSync(recursive: false);
      debugPrint('[NCM扫描] 找到 ${entities.length} 个文件/文件夹');

      for (final entity in entities) {
        debugPrint('[NCM扫描] 检查: ${entity.path}');
        if (entity is File) {
          final path = entity.path.toLowerCase();
          if (path.endsWith('.ncm')) {
            files.add(entity.path);
            debugPrint('[NCM扫描] 添加 NCM 文件: ${entity.path}');
          }
        }
      }
    } catch (e) {
      debugPrint('[NCM扫描] 列出目录内容时出错: $e');

      // 尝试使用异步方法作为备选
      try {
        await for (final entity in dir.list(recursive: false)) {
          if (entity is File) {
            final path = entity.path.toLowerCase();
            if (path.endsWith('.ncm')) {
              files.add(entity.path);
            }
          }
        }
      } catch (e2) {
        debugPrint('[NCM扫描] 异步列出也失败: $e2');
      }
    }

    debugPrint('[NCM扫描] 总共找到 ${files.length} 个 NCM 文件');
    return files;
  }

  /// 批量解密目录中的所有 NCM 文件
  /// 返回一个 Stream，可以监听进度和结果
  /// [concurrency] 参数指定并行解密的数量，默认为1（顺序执行）
  Stream<BatchDecodeProgress> decodeDirectory({
    required String inputDir,
    required String outputDir,
    int concurrency = 1,
    void Function(DecodeResult)? onFileComplete,
  }) async* {
    // 扫描所有 NCM 文件
    final files = await scanNcmFiles(inputDir);
    final total = files.length;
    var completed = 0;
    var failed = 0;

    if (total == 0) {
      yield BatchDecodeProgress(total: 0, completed: 0, failed: 0);
      return;
    }

    // 确保输出目录存在
    final outDir = Directory(outputDir);
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }

    // 限制并发数在合理范围内
    final effectiveConcurrency = concurrency.clamp(1, 16);
    debugPrint('[NCM解密] 使用 $effectiveConcurrency 个并行任务');

    // 使用 StreamController 来汇报进度
    final progressController = StreamController<BatchDecodeProgress>();

    // 当前正在处理的文件名
    String? currentFileName;

    // 并行处理逻辑
    () async {
      // 创建任务队列
      final futures = <Future<void>>[];
      var fileIndex = 0;

      // 处理单个文件的函数
      Future<void> processOne() async {
        while (fileIndex < files.length) {
          final idx = fileIndex++;
          final filePath = files[idx];
          final fileName = filePath.split(Platform.pathSeparator).last;

          currentFileName = fileName;
          progressController.add(
            BatchDecodeProgress(
              total: total,
              completed: completed,
              failed: failed,
              currentFile: currentFileName,
            ),
          );

          try {
            final result = await decodeFile(filePath, outputDir);
            if (result.success) {
              completed++;
            } else {
              failed++;
            }
            onFileComplete?.call(result);
          } catch (e) {
            failed++;
            onFileComplete?.call(
              DecodeResult(
                inputPath: filePath,
                outputPath: '',
                success: false,
                errorMessage: e.toString(),
              ),
            );
          }
        }
      }

      // 启动并发worker
      for (var i = 0; i < effectiveConcurrency; i++) {
        futures.add(processOne());
      }

      // 等待所有worker完成
      await Future.wait(futures);

      // 发送最终进度
      progressController.add(
        BatchDecodeProgress(total: total, completed: completed, failed: failed),
      );

      await progressController.close();
    }();

    // 转发进度事件
    await for (final progress in progressController.stream) {
      yield progress;
    }
  }

  /// 获取版本
  String getVersion() => '1.0.0';
}

/// Isolate 中执行的解密函数
Future<DecodeResult> _decodeInIsolate(List<String> args) async {
  final inputPath = args[0];
  final outputDir = args[1];

  final ncmDump = NcmDump();
  final (success, outputPath, errorMessage) = await ncmDump.decode(
    inputPath,
    outputDir,
  );

  return DecodeResult(
    inputPath: inputPath,
    outputPath: outputPath,
    success: success,
    errorMessage: errorMessage,
  );
}
