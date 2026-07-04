import 'package:flutter/material.dart';

import '../core/audio_recorder.dart';
import '../core/detection_service.dart';
import '../core/models.dart';
import '../core/sample_repository.dart';
import '../core/settings.dart';
import '../core/upload_service.dart';

enum _Stage { idle, recording, labeling }

class CollectScreen extends StatefulWidget {
  final DetectionService service;
  final SampleRepository repository;
  final AppSettings settings;
  final UploadService uploader;

  const CollectScreen({
    super.key,
    required this.service,
    required this.repository,
    required this.settings,
    required this.uploader,
  });

  @override
  State<CollectScreen> createState() => _CollectScreenState();
}

class _CollectScreenState extends State<CollectScreen> {
  final AudioRecorderService _recorder = AudioRecorderService();
  final TextEditingController _note = TextEditingController();
  _Stage _stage = _Stage.idle;
  String? _wavPath;
  double _dominantFreq = 0;
  Ripeness _label = Ripeness.ripe;
  String? _error;

  @override
  void dispose() {
    _recorder.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _error = null);
    if (!await _recorder.hasPermission()) {
      setState(() => _error = '需要麦克风权限。');
      return;
    }
    await _recorder.start();
    setState(() => _stage = _Stage.recording);
  }

  Future<void> _stop() async {
    final path = await _recorder.stop();
    if (path == null) {
      setState(() {
        _stage = _Stage.idle;
        _error = '录音失败。';
      });
      return;
    }
    double freq = 0;
    try {
      final r = widget.service.analyzeFile(path);
      if (r.taps.isNotEmpty) freq = r.taps.first.dominantFreq;
    } catch (_) {}
    setState(() {
      _wavPath = path;
      _dominantFreq = freq;
      _stage = _Stage.labeling;
    });
  }

  Future<void> _save() async {
    if (_wavPath == null) return;
    final sample = await widget.repository.add(
      srcWavPath: _wavPath!,
      label: _label,
      note: _note.text.trim(),
      dominantFreq: _dominantFreq,
    );
    _note.clear();

    // 云端上传（架构预留）：仅当用户开启且服务器已配置时才尝试；否则纯本地。
    String msg = '已保存到本地样本库';
    if (widget.settings.uploadEnabled && widget.uploader.isConfigured) {
      final wav = await widget.repository.wavFile(sample);
      final state = await widget.uploader.uploadSample(
        wav: wav,
        label: sample.label,
        note: sample.note,
        dominantFreq: sample.dominantFreq,
      );
      if (state == UploadState.success) {
        await widget.repository.markUploaded(sample.id);
        msg = '已保存并上传';
      } else {
        msg = '已本地保存（上传失败，稍后可重试）';
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    setState(() {
      _stage = _Stage.idle;
      _wavPath = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final counts = widget.repository.countByLabel();
    return Scaffold(
      appBar: AppBar(title: const Text('贡献数据')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Card(
                color: const Color(0xFFE8F5E9),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: Ripeness.values.map((r) {
                      return Column(
                        children: [
                          Text('${counts[r] ?? 0}',
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold)),
                          Text(r.labelZh,
                              style: const TextStyle(fontSize: 12)),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_stage) {
      case _Stage.idle:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '录一段敲击声，切开后选择真实结果保存。\n'
              '数据仅存本地，可在"我的采集数据"里导出用于训练。',
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 24),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: _start,
              icon: const Icon(Icons.mic),
              label: const Text('开始录音'),
            ),
          ],
        );
      case _Stage.recording:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fiber_manual_record,
                color: Colors.red, size: 48),
            const SizedBox(height: 16),
            const Text('录音中…敲 3~5 下'),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: _stop,
              icon: const Icon(Icons.stop),
              label: const Text('结束录音'),
            ),
          ],
        );
      case _Stage.labeling:
        return ListView(
          children: [
            const Text('这个瓜切开后实际是？',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...Ripeness.values.map((r) => RadioListTile<Ripeness>(
                  value: r,
                  groupValue: _label,
                  onChanged: (v) => setState(() => _label = v!),
                  title: Text(r.labelZh),
                )),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: '备注（可选：品种/甜度/产地等）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _stage = _Stage.idle),
                    child: const Text('丢弃'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save),
                    label: const Text('保存样本'),
                  ),
                ),
              ],
            ),
          ],
        );
    }
  }
}
