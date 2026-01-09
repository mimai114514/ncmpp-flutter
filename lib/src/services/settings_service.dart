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

  /// 默认线程数（基于CPU核心数，最小1，最大16）
  static int get defaultThreadCount {
    final cpuCount = Platform.numberOfProcessors;
    return cpuCount.clamp(1, 16);
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
    final clampedCount = count.clamp(1, 16);
    await _prefs?.setInt(_keyThreadCount, clampedCount);
    debugPrint('[设置服务] 线程数已设置为: $clampedCount');
  }
}
