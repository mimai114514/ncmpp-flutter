/// 设置页面

import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late int _threadCount;

  @override
  void initState() {
    super.initState();
    _threadCount = SettingsService.instance.threadCount;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: theme.colorScheme.inversePrimary,
      ),
      body: ListView(
        children: [
          // 性能设置
          const _SectionHeader(title: '性能'),
          ListTile(
            leading: const Icon(Icons.speed),
            title: const Text('解密线程数'),
            subtitle: Text('当前: $_threadCount 线程'),
            trailing: SizedBox(
              width: 200,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _threadCount > 1
                        ? () => _updateThreadCount(_threadCount - 1)
                        : null,
                  ),
                  Expanded(
                    child: Slider(
                      value: _threadCount.toDouble(),
                      min: 1,
                      max: 16,
                      divisions: 15,
                      label: '$_threadCount',
                      onChanged: (value) => _updateThreadCount(value.round()),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _threadCount < 16
                        ? () => _updateThreadCount(_threadCount + 1)
                        : null,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '更多线程可以加快批量解密速度，但会占用更多系统资源。'
              '建议设置为 CPU 核心数（默认: ${SettingsService.defaultThreadCount}）',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
            ),
          ),
          const SizedBox(height: 16),

          // 关于部分
          const _SectionHeader(title: '关于'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('关于本应用'),
            subtitle: const Text('查看版本信息和版权声明'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showAboutDialog(context),
          ),
        ],
      ),
    );
  }

  void _updateThreadCount(int count) {
    final clampedCount = count.clamp(1, 16);
    setState(() {
      _threadCount = clampedCount;
    });
    SettingsService.instance.setThreadCount(clampedCount);
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'NCM 解密器',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2026 NCM Decoder',
      children: [const SizedBox(height: 16), const Text('一个用于解密 NCM 音乐文件的工具。')],
    );
  }
}

/// 设置页面的分区标题组件
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
