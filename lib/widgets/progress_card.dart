/// 进度卡片组件

import 'package:flutter/material.dart';

class ProgressCard extends StatelessWidget {
  final int total;
  final int completed;
  final int failed;
  final String? currentFile;
  final bool isProcessing;

  const ProgressCard({
    super.key,
    required this.total,
    required this.completed,
    required this.failed,
    this.currentFile,
    this.isProcessing = false,
  });

  double get progress => total > 0 ? (completed + failed) / total : 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '处理进度',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStatItem(
                      context,
                      icon: Icons.check_circle,
                      label: '成功',
                      value: completed,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 16),
                    _buildStatItem(
                      context,
                      icon: Icons.error,
                      label: '失败',
                      value: failed,
                      color: Colors.red,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 进度条
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerLow,
              ),
            ),

            // 当前处理文件
            if (currentFile != null && isProcessing)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  currentFile!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int value,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text('$label: $value', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
