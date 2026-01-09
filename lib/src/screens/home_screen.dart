/// 主界面

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../ffi/ncm_decoder.dart';
import '../models/ncm_file.dart';
import '../services/settings_service.dart';
import '../../widgets/progress_card.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _inputDir;
  String? _outputDir;
  List<NcmFile> _files = [];
  bool _isProcessing = false;
  int _completed = 0;
  int _failed = 0;
  String? _currentFile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('NCM 解密器'),
        backgroundColor: theme.colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '设置',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 目录选择 - 响应式布局
            LayoutBuilder(
              builder: (context, constraints) {
                // 宽度大于 600 时并排显示
                final isWide = constraints.maxWidth > 600;

                final inputCard = _buildDirectoryCard(
                  title: '输入目录',
                  subtitle: _inputDir ?? '请选择包含 NCM 文件的文件夹',
                  icon: Icons.folder_open,
                  onTap: _isProcessing ? null : _selectInputDirectory,
                  color: theme.colorScheme.primaryContainer,
                );

                final outputCard = _buildDirectoryCard(
                  title: '输出目录',
                  subtitle: _outputDir ?? '请选择解密后文件的保存位置',
                  icon: Icons.folder_copy,
                  onTap: _isProcessing ? null : _selectOutputDirectory,
                  color: theme.colorScheme.secondaryContainer,
                );

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: inputCard),
                      const SizedBox(width: 12),
                      Expanded(child: outputCard),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      inputCard,
                      const SizedBox(height: 12),
                      outputCard,
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 16),

            // 文件列表
            Expanded(child: _buildFileList()),

            // 进度显示
            if (_isProcessing || _files.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ProgressCard(
                  total: _files.length,
                  completed: _completed,
                  failed: _failed,
                  currentFile: _currentFile,
                  isProcessing: _isProcessing,
                ),
              ),

            const SizedBox(height: 16),

            // 开始按钮
            FilledButton.icon(
              onPressed: _canStart ? _startDecoding : null,
              icon: Icon(
                _isProcessing ? Icons.hourglass_empty : Icons.play_arrow,
              ),
              label: Text(
                _isProcessing
                    ? '正在处理...'
                    : '开始解密${_files.isNotEmpty ? " (${_files.length})" : ""}',
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectoryCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback? onTap,
    required Color color,
  }) {
    return Card(
      color: color,
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _buildFileList() {
    if (_files.isEmpty) {
      return Card(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.music_note,
                size: 64,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                '选择输入目录后\n将在此显示 NCM 文件列表',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 宽度大于 600 时显示双列（与目录选择卡片判定条件一致）
          final isWide = constraints.maxWidth > 600;

          if (isWide) {
            // 双列布局
            return GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 4.5, // 调整每个项目的宽高比
                crossAxisSpacing: 0,
                mainAxisSpacing: 0,
              ),
              itemCount: _files.length,
              itemBuilder: (context, index) =>
                  _buildFileListItem(_files[index]),
            );
          } else {
            // 单列布局
            return ListView.builder(
              itemCount: _files.length,
              itemBuilder: (context, index) =>
                  _buildFileListItem(_files[index]),
            );
          }
        },
      ),
    );
  }

  /// 构建文件列表项
  Widget _buildFileListItem(NcmFile file) {
    return ListTile(
      leading: _buildStatusIcon(file.status),
      title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: file.errorMessage != null
          ? Text(
              file.errorMessage!,
              style: const TextStyle(color: Colors.red),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
    );
  }

  Widget _buildStatusIcon(NcmFileStatus status) {
    switch (status) {
      case NcmFileStatus.pending:
        return const Icon(Icons.hourglass_empty, color: Colors.grey);
      case NcmFileStatus.processing:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case NcmFileStatus.success:
        return const Icon(Icons.check_circle, color: Colors.green);
      case NcmFileStatus.failed:
        return const Icon(Icons.error, color: Colors.red);
    }
  }

  bool get _canStart =>
      !_isProcessing &&
      _inputDir != null &&
      _outputDir != null &&
      _files.isNotEmpty;

  Future<void> _selectInputDirectory() async {
    // 请求存储权限
    final hasPermission = await _requestStoragePermission();
    if (!hasPermission) {
      _showSnackBar('需要存储权限才能访问文件');
      return;
    }

    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择包含 NCM 文件的文件夹',
    );

    if (result != null) {
      setState(() {
        _inputDir = result;
        _files = [];
        _completed = 0;
        _failed = 0;
      });

      // 扫描目录
      final decoder = NcmDecoder.instance;
      final filePaths = await decoder.scanNcmFiles(result);

      setState(() {
        _files = filePaths.map((p) => NcmFile.fromPath(p)).toList();
      });

      if (_files.isEmpty) {
        _showSnackBar('该目录中没有找到 NCM 文件');
      }
    }
  }

  /// 请求存储权限
  Future<bool> _requestStoragePermission() async {
    // Android 11+ (API 30+) 需要 MANAGE_EXTERNAL_STORAGE 权限
    if (await Permission.manageExternalStorage.isGranted) {
      return true;
    }

    // 先尝试请求 MANAGE_EXTERNAL_STORAGE 权限
    var status = await Permission.manageExternalStorage.request();
    if (status.isGranted) {
      return true;
    }

    // 如果被拒绝，尝试请求普通存储权限（适用于旧版 Android）
    if (await Permission.storage.isGranted) {
      return true;
    }

    status = await Permission.storage.request();
    if (status.isGranted) {
      return true;
    }

    // 如果权限被永久拒绝，引导用户去设置页面
    if (status.isPermanentlyDenied) {
      final shouldOpenSettings = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('需要存储权限'),
          content: const Text('请在设置中授予存储权限以访问音乐文件。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('去设置'),
            ),
          ],
        ),
      );

      if (shouldOpenSettings == true) {
        await openAppSettings();
      }
    }

    return false;
  }

  Future<void> _selectOutputDirectory() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择输出目录',
    );

    if (result != null) {
      setState(() {
        _outputDir = result;
      });
    }
  }

  Future<void> _startDecoding() async {
    if (_inputDir == null || _outputDir == null) return;

    setState(() {
      _isProcessing = true;
      _completed = 0;
      _failed = 0;
      for (var file in _files) {
        file.status = NcmFileStatus.pending;
        file.errorMessage = null;
        file.outputPath = null;
      }
    });

    // 开始计时
    final stopwatch = Stopwatch()..start();

    final decoder = NcmDecoder.instance;

    await for (final progress in decoder.decodeDirectory(
      inputDir: _inputDir!,
      outputDir: _outputDir!,
      concurrency: SettingsService.instance.threadCount,
      onFileComplete: (result) {
        // 更新文件状态
        final index = _files.indexWhere((f) => f.path == result.inputPath);
        if (index >= 0) {
          setState(() {
            _files[index].status = result.success
                ? NcmFileStatus.success
                : NcmFileStatus.failed;
            _files[index].outputPath = result.outputPath;
            _files[index].errorMessage = result.errorMessage;
          });
        }
      },
    )) {
      setState(() {
        _completed = progress.completed;
        _failed = progress.failed;
        _currentFile = progress.currentFile;

        // 标记当前正在处理的文件
        if (progress.currentFile != null) {
          final index = _files.indexWhere(
            (f) => f.name == progress.currentFile,
          );
          if (index >= 0 && _files[index].status == NcmFileStatus.pending) {
            _files[index].status = NcmFileStatus.processing;
          }
        }
      });
    }

    setState(() {
      _isProcessing = false;
      _currentFile = null;
    });

    // 停止计时并显示完成对话框
    stopwatch.stop();
    final elapsedSeconds = stopwatch.elapsed.inSeconds;
    if (mounted) {
      _showCompletionDialog(elapsedSeconds);
    }
  }

  /// 显示解密完成对话框
  void _showCompletionDialog(int elapsedSeconds) {
    bool deleteSourceFiles = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('转换完成'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$_completed 成功，$_failed 失败，耗时 ${elapsedSeconds}s'),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: deleteSourceFiles,
                onChanged: (value) {
                  setDialogState(() {
                    deleteSourceFiles = value ?? false;
                  });
                },
                title: const Text('删除转换成功的 .ncm 文件'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (deleteSourceFiles) {
                  await _deleteSuccessfulSourceFiles();
                }
                await _openMusicTagEditor();
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('打开音乐标签'),
            ),
            FilledButton(
              onPressed: () async {
                if (deleteSourceFiles) {
                  await _deleteSuccessfulSourceFiles();
                }
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('完成'),
            ),
          ],
        ),
      ),
    );
  }

  /// 删除转换成功的源文件
  Future<void> _deleteSuccessfulSourceFiles() async {
    int deletedCount = 0;
    for (final file in _files) {
      if (file.status == NcmFileStatus.success) {
        try {
          final sourceFile = File(file.path);
          if (await sourceFile.exists()) {
            await sourceFile.delete();
            deletedCount++;
          }
        } catch (e) {
          debugPrint('[删除文件] 失败: ${file.path}, 错误: $e');
        }
      }
    }
    debugPrint('[删除文件] 已删除 $deletedCount 个文件');
    if (mounted) {
      _showSnackBar('已删除 $deletedCount 个源文件');
    }
  }

  /// 打开音乐标签编辑器应用
  Future<void> _openMusicTagEditor() async {
    const packageName = 'com.xjcheng.musictageditor';
    final uri = Uri.parse('android-app://$packageName');

    try {
      // 尝试使用 android-app scheme 打开
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }

      // 如果无法打开，显示失败对话框
      if (mounted) {
        _showOpenAppFailedDialog();
      }
    } catch (e) {
      debugPrint('[打开应用] 失败: $e');
      if (mounted) {
        _showOpenAppFailedDialog();
      }
    }
  }

  /// 显示打开应用失败的对话框
  void _showOpenAppFailedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('打开失败'),
        content: const Text('无法打开音乐标签应用，请确认已安装该应用。'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
