/// 设置服务
/// 提供应用设置的持久化存储和读取

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 设置服务单例
class SettingsService {
  static final SettingsService _instance = SettingsService._();
  static SettingsService get instance => _instance;

  SettingsService._();

  SharedPreferences? _prefs;

  /// 设置键名
  static const String _keyThreadCount = 'thread_count';
  static const String _keyBufferSize = 'buffer_size';
  static const String _keyFlushInterval = 'flush_interval';

  /// 默认线程数（基于CPU核心数，最小1，最大16）
  /// 最大允许线程数
  static const int maxThreadCount = 32;

  /// 缓冲区大小范围（64KB - 1MB）
  static const int minBufferSize = 64 * 1024; // 64KB
  static const int maxBufferSize = 1024 * 1024; // 1MB
  static const int defaultBufferSize = 256 * 1024; // 256KB

  /// 刷新间隔范围（每 N 个缓冲区块刷新一次）
  static const int minFlushInterval = 1;
  static const int maxFlushInterval = 32;
  static const int defaultFlushInterval = 8; // 每 8 个块刷新一次

  static int get defaultThreadCount {
    final cpuCount = Platform.numberOfProcessors;
    return cpuCount.clamp(1, maxThreadCount);
  }

  /// 初始化设置服务
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    debugPrint('[设置服务] 初始化完成');
  }

  /// 获取线程数设置
  int get threadCount {
    return _prefs?.getInt(_keyThreadCount) ?? defaultThreadCount;
  }

  /// 设置线程数
  Future<void> setThreadCount(int count) async {
    final clampedCount = count.clamp(1, maxThreadCount);
    await _prefs?.setInt(_keyThreadCount, clampedCount);
    debugPrint('[设置服务] 线程数已设置为: $clampedCount');
  }

  /// 获取缓冲区大小（字节）
  int get bufferSize {
    return _prefs?.getInt(_keyBufferSize) ?? defaultBufferSize;
  }

  /// 设置缓冲区大小
  Future<void> setBufferSize(int size) async {
    final clampedSize = size.clamp(minBufferSize, maxBufferSize);
    await _prefs?.setInt(_keyBufferSize, clampedSize);
    debugPrint('[设置服务] 缓冲区大小已设置为: ${clampedSize ~/ 1024}KB');
  }

  /// 获取刷新间隔（每 N 个块）
  int get flushInterval {
    return _prefs?.getInt(_keyFlushInterval) ?? defaultFlushInterval;
  }

  /// 设置刷新间隔
  Future<void> setFlushInterval(int interval) async {
    final clampedInterval = interval.clamp(minFlushInterval, maxFlushInterval);
    await _prefs?.setInt(_keyFlushInterval, clampedInterval);
    debugPrint('[设置服务] 刷新间隔已设置为: 每 $clampedInterval 块');
  }

  /// 获取格式化的缓冲区大小显示文本
  String get bufferSizeText {
    final sizeKB = bufferSize ~/ 1024;
    if (sizeKB >= 1024) {
      return '${sizeKB ~/ 1024}MB';
    }
    return '${sizeKB}KB';
  }
}
