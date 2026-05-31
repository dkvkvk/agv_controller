import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/recorded_path.dart';
import '../services/bluetooth_service.dart';
import '../services/path_recorder_service.dart';
import '../services/protocol_service.dart';

class PathPage extends StatefulWidget {
  const PathPage({super.key});

  @override
  State<PathPage> createState() => _PathPageState();
}

class _PathPageState extends State<PathPage> with TickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _formatDuration(int ms) {
    final seconds = ms ~/ 1000;
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes > 0) return '${minutes}m ${secs}s';
    return '${secs}s';
  }

  String _formatDate(DateTime dt) {
    return '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  void _showDeleteConfirm(BuildContext context, PathRecorderService recorder,
      int index, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('确认删除', style: TextStyle(color: AppColors.textPrimary)),
        content: Text('确定要删除路径 "$name" 吗？',
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('取消', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              recorder.deletePath(index);
              Navigator.pop(ctx);
            },
            child:
                const Text('删除', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, PathRecorderService recorder,
      int index, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('重命名', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: '输入新名称',
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: AppColors.primary.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('取消', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                recorder.renamePath(index, name);
              }
              Navigator.pop(ctx);
            },
            child:
                const Text('确定', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recorder = context.watch<PathRecorderService>();
    final bt = context.watch<BluetoothService>();
    final connected = bt.isConnected;

    return SafeArea(
      child: Column(
        children: [
          // ── Header with import/export buttons ──
          _buildHeader(context, recorder),

          // ── Playback status panel ──
          if (recorder.isPlaying) _buildPlaybackPanel(recorder),

          // ── Path list ──
          Expanded(
            child: recorder.paths.isEmpty
                ? _buildEmptyState()
                : _buildPathList(recorder, connected),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, PathRecorderService recorder) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.route, color: AppColors.primary, size: 24),
          const SizedBox(width: 10),
          const Text(
            '路径管理',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          // Import button
          _headerButton(
            icon: Icons.file_download_outlined,
            label: '导入',
            onTap: () => _handleImport(context, recorder),
          ),
          const SizedBox(width: 8),
          // Export all button
          _headerButton(
            icon: Icons.file_upload_outlined,
            label: '导出',
            onTap: recorder.paths.isEmpty
                ? null
                : () => _handleExportAll(context, recorder),
          ),
        ],
      ),
    );
  }

  Widget _headerButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled
                ? AppColors.primary.withOpacity(0.3)
                : Colors.white.withOpacity(0.05),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: enabled ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color:
                    enabled ? AppColors.primary : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaybackPanel(PathRecorderService recorder) {
    final progress = recorder.playbackProgress;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (_, __) => Icon(
                  Icons.play_circle_fill,
                  color: AppColors.primary
                      .withOpacity(0.5 + _pulseController.value * 0.5),
                  size: 22,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '正在回放  ${recorder.playbackIndex}/${recorder.playbackTotal}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => recorder.stopPlayback(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: AppColors.danger.withOpacity(0.4)),
                  ),
                  child: const Text('停止',
                      style: TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      )),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 6,
            ),
          ),
          if (recorder.playbackCurrentCmd.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '当前指令: ${recorder.playbackCurrentCmd}',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.route, size: 64, color: AppColors.textSecondary.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text(
            '暂无录制路径',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '请在控制页手动模式下录制路径\n或点击右上角导入路径文件',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPathList(PathRecorderService recorder, bool connected) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      itemCount: recorder.paths.length,
      itemBuilder: (context, index) {
        final path = recorder.paths[index];
        return _buildPathCard(context, recorder, path, index, connected);
      },
    );
  }

  Widget _buildPathCard(BuildContext context, PathRecorderService recorder,
      RecordedPath path, int index, bool connected) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: name + actions
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        _showRenameDialog(context, recorder, index, path.name),
                    child: Text(
                      path.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // Export single
                _iconBtn(
                  Icons.file_upload_outlined,
                  AppColors.primary,
                  () => _handleExportSingle(context, recorder, path),
                ),
                const SizedBox(width: 4),
                // Delete
                _iconBtn(
                  Icons.delete_outline,
                  AppColors.danger,
                  () => _showDeleteConfirm(context, recorder, index, path.name),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Info row
            Row(
              children: [
                _infoChip(Icons.access_time, _formatDate(path.createdAt)),
                const SizedBox(width: 12),
                _infoChip(Icons.list_alt, '${path.commands.length} 条指令'),
                const SizedBox(width: 12),
                _infoChip(
                    Icons.timer_outlined, _formatDuration(path.totalDurationMs)),
              ],
            ),
            const SizedBox(height: 10),
            // Play button
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton.icon(
                onPressed: connected && !recorder.isPlaying
                    ? () {
                        final proto = context.read<ProtocolService>();
                        recorder.startPlayback(path, proto);
                      }
                    : null,
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: const Text('播放',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: AppColors.primary.withOpacity(0.15),
                  disabledForegroundColor: AppColors.textSecondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // ── Import / Export handlers ──

  Future<void> _handleImport(
      BuildContext context, PathRecorderService recorder) async {
    final count = await recorder.importPaths();
    if (!context.mounted) return;

    if (count > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('成功导入 $count 条路径'),
          backgroundColor: AppColors.success,
        ),
      );
    } else if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('未选择文件或文件中无路径数据'),
          backgroundColor: AppColors.warning,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('导入失败：文件格式错误'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _handleExportSingle(BuildContext context,
      PathRecorderService recorder, RecordedPath path) async {
    final filePath = await recorder.exportPath(path);
    if (!context.mounted) return;

    if (filePath != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已导出到: $filePath'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('导出失败'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _handleExportAll(
      BuildContext context, PathRecorderService recorder) async {
    final filePath = await recorder.exportAllPaths();
    if (!context.mounted) return;

    if (filePath != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已导出 ${recorder.paths.length} 条路径到:\n$filePath'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('导出失败'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
}
