import 'package:audioplayers/audioplayers.dart';
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
  final AudioPlayer _player = AudioPlayer();
  String? _playingId;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingId = null);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay(Sample s) async {
    if (_playingId == s.id) {
      await _player.stop();
      setState(() => _playingId = null);
      return;
    }
    final file = await widget.repository.wavFile(s);
    if (!await file.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('录音文件不存在')),
        );
      }
      return;
    }
    await _player.stop();
    await _player.play(DeviceFileSource(file.path));
    setState(() => _playingId = s.id);
  }

  Future<void> _edit(Sample s) async {
    final ctrl = TextEditingController(text: s.name);
    Ripeness label = s.label;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('编辑样本'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: ctrl,
                  decoration: const InputDecoration(
                    labelText: '名称（可选）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                const Text('成熟度标签',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                ...Ripeness.values.map((rp) => RadioListTile<Ripeness>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: rp,
                      groupValue: label,
                      onChanged: (v) => setDialog(() => label = v!),
                      title: Text(rp.labelZh),
                    )),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('保存')),
          ],
        ),
      ),
    );
    if (ok == true) {
      await widget.repository
          .update(s.id, name: ctrl.text.trim(), label: label);
      setState(() {});
    }
  }

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
    if (_playingId == id) {
      await _player.stop();
      _playingId = null;
    }
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
            ? const _EmptyHint()
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: samples.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 76),
                itemBuilder: (context, i) => _tile(samples[i]),
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

  Widget _tile(Sample s) {
    final playing = _playingId == s.id;
    final dt = DateTime.fromMillisecondsSinceEpoch(s.timestampMs);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: GestureDetector(
        onTap: () => _togglePlay(s),
        child: CircleAvatar(
          radius: 24,
          backgroundColor: _colorFor(s.label),
          child: Icon(
            playing ? Icons.stop : Icons.play_arrow,
            color: Colors.white,
          ),
        ),
      ),
      title: Text(s.displayName,
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        '${s.label.labelZh} · ${dt.year}-${dt.month}-${dt.day} '
        '${dt.hour}:${dt.minute.toString().padLeft(2, '0')} · '
        '${s.dominantFreq.toStringAsFixed(0)}Hz'
        '${s.note.isNotEmpty ? ' · ${s.note}' : ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'edit') _edit(s);
          if (v == 'delete') _delete(s.id);
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: 'edit',
            child: ListTile(
                leading: Icon(Icons.edit), title: Text('编辑')),
          ),
          PopupMenuItem(
            value: 'delete',
            child: ListTile(
                leading: Icon(Icons.delete_outline), title: Text('删除')),
          ),
        ],
      ),
    );
  }

  Color _colorFor(Ripeness r) {
    switch (r) {
      case Ripeness.unripe:
        return const Color(0xFF7CB342);
      case Ripeness.ripe:
        return const Color(0xFF2E7D32);
      case Ripeness.overripe:
        return const Color(0xFFC62828);
    }
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.black26),
          SizedBox(height: 12),
          Text('还没有采集样本', style: TextStyle(color: Colors.black54)),
          SizedBox(height: 4),
          Text('去"检测"或"贡献数据"录一段吧',
              style: TextStyle(fontSize: 12, color: Colors.black38)),
        ],
      ),
    );
  }
}
