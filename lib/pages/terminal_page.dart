import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/agv_state.dart';
import '../services/bluetooth_service.dart';
import '../services/protocol_service.dart';

class TerminalPage extends StatefulWidget {
  const TerminalPage({super.key});

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _autoScroll = true;

  // Quick commands
  static const _quickCmds = [
    ('Q', '查询全部'),
    ('QP', '查询参数'),
    ('QS', '查询传感器'),
    ('QM', '查询模式'),
    ('C', '启停'),
    ('S', '停止'),
    ('M:0', '自动'),
    ('M:1', '手动'),
    ('AR:1', '自动上报'),
    ('AR:0', '关上报'),
    ('N', '切OLED'),
  ];

  void _send() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    context.read<ProtocolService>().sendRaw(text);
    _inputController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (!_autoScroll) return;
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AGVState>();
    final bt = context.watch<BluetoothService>();
    const cyan = Color(0xFF00D4FF);
    const surface = Color(0xFF111636);
    final connected = bt.isConnected;

    // Auto‑scroll when new entries arrive
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scrollToBottom());

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            // ── Header ──
            Row(
              children: [
                const Icon(Icons.terminal, color: cyan, size: 24),
                const SizedBox(width: 10),
                const Text('调试终端',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE0E6FF))),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    state.clearTerminal();
                  },
                  icon: const Icon(Icons.delete_outline,
                      color: Color(0xFF6B7DB3), size: 20),
                  tooltip: '清空',
                ),
                IconButton(
                  onPressed: () {
                    setState(() => _autoScroll = !_autoScroll);
                  },
                  icon: Icon(
                    _autoScroll
                        ? Icons.vertical_align_bottom
                        : Icons.vertical_align_center,
                    color: _autoScroll ? cyan : const Color(0xFF6B7DB3),
                    size: 20,
                  ),
                  tooltip: _autoScroll ? '自动滚动: 开' : '自动滚动: 关',
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Quick commands ──
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _quickCmds.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final (cmd, label) = _quickCmds[i];
                  return GestureDetector(
                    onTap: connected
                        ? () {
                            context.read<ProtocolService>().sendRaw(cmd);
                            _scrollToBottom();
                          }
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: cyan.withOpacity(0.15)),
                      ),
                      child: Center(
                        child: Text(
                          label,
                          style: TextStyle(
                            color: connected
                                ? cyan
                                : cyan.withOpacity(0.3),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),

            // ── Log area ──
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF080B1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cyan.withOpacity(0.08)),
                ),
                child: state.terminalLog.isEmpty
                    ? Center(
                        child: Text(
                          '等待数据...',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.2),
                              fontFamily: 'monospace'),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: state.terminalLog.length,
                        itemBuilder: (_, i) {
                          final entry = state.terminalLog[i];
                          final timeStr =
                              '${entry.timestamp.hour.toString().padLeft(2, '0')}:'
                              '${entry.timestamp.minute.toString().padLeft(2, '0')}:'
                              '${entry.timestamp.second.toString().padLeft(2, '0')}';
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 2),
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                                children: [
                                  TextSpan(
                                    text: '[$timeStr] ',
                                    style: TextStyle(
                                      color:
                                          Colors.white.withOpacity(0.25),
                                    ),
                                  ),
                                  TextSpan(
                                    text:
                                        entry.isSent ? '>> ' : '<< ',
                                    style: TextStyle(
                                      color: entry.isSent
                                          ? const Color(0xFF7C4DFF)
                                          : const Color(0xFF00E676),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(
                                    text: entry.message,
                                    style: TextStyle(
                                      color: entry.isSent
                                          ? const Color(0xFFB39DDB)
                                          : const Color(0xFFE0E6FF),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 10),

            // ── Input bar ──
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    enabled: connected,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: Color(0xFFE0E6FF),
                    ),
                    decoration: InputDecoration(
                      hintText: connected ? '输入命令...' : '请先连接设备',
                      hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.2),
                          fontFamily: 'monospace'),
                      filled: true,
                      fillColor: surface,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: cyan.withOpacity(0.15)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: cyan.withOpacity(0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: cyan.withOpacity(0.4)),
                      ),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: connected ? _send : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cyan.withOpacity(0.15),
                      foregroundColor: cyan,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Icon(Icons.send, size: 20),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
