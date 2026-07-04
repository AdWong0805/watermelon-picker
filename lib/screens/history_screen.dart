import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/models.dart';
import '../core/sample_repository.dart';

class HistoryScreen extends StatefulWidget {
  final SampleRepository repository;

  const HistoryScreen({super.key, required this.repository});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _exporting = false;
  final GlobalKey _shareKey = GlobalKey();

  /// iPad/iOS 分享面板需要一个锚点矩形，否则报 sharePositionOrigin 错误。
  Rect? _shareOrigin() {
    final ctx = _shareKey.currentContext ?? context;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _export() async {
    if (widget.repository.total == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('还没有样本可导出')),
      );
      return;
    }
    final origin = _shareOrigin();
    setState(() => _exporting = true);
    try {
      final zip = await widget.repository.exportZip();
      await Share.shareXFiles(
        [XFile(zip)],
        text: '瓜熟采集数据（含 labels.csv）',
        sharePositionOrigin: origin,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _delete(String id) async {
    await widget.repository.delete(id);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final samples = widget.repository.samples;
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的采集数据'),
        actions: [
          IconButton(
            key: _shareKey,
            icon: _exporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.ios_share),
            onPressed: _exporting ? null : _export,
            tooltip: '导出 zip',
          ),
        ],
      ),
      body: SafeArea(
        child: samples.isEmpty
            ? const Center(child: Text('还没有采集样本'))
            : ListView.separated(
                itemCount: samples.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final s = samples[i];
                  final dt =
                      DateTime.fromMillisecondsSinceEpoch(s.timestampMs);
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _colorFor(s.label),
                      child: Text(s.label.labelZh.substring(0, 1),
                          style: const TextStyle(color: Colors.white)),
                    ),
                    title: Text(s.label.labelZh),
                    subtitle: Text(
                      '${dt.year}-${dt.month}-${dt.day} '
                      '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}'
                      '  ·  ${s.dominantFreq.toStringAsFixed(0)}Hz'
                      '${s.note.isNotEmpty ? '  ·  ${s.note}' : ''}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(s.id),
                    ),
                  );
                },
              ),
      ),
      bottomNavigationBar: samples.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '共 ${samples.length} 条 · 建议每类攒够 ${SampleRepository.suggestedPerClass} 条再训练',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
    );
  }

  Color _colorFor(Ripeness r) {
    switch (r) {
      case Ripeness.unripe:
        return const Color(0xFF8BC34A);
      case Ripeness.ripe:
        return const Color(0xFF2E7D32);
      case Ripeness.overripe:
        return const Color(0xFFC62828);
    }
  }
}
