import 'package:flutter/material.dart';

import '../core/audio_recorder.dart';
import '../core/detection_service.dart';
import '../core/models.dart';
import '../widgets/confidence_bar.dart';
import '../widgets/spectrum_painter.dart';

enum _Stage { idle, recording, analyzing, result }

class DetectScreen extends StatefulWidget {
  final DetectionService service;

  const DetectScreen({super.key, required this.service});

  @override
  State<DetectScreen> createState() => _DetectScreenState();
}

class _DetectScreenState extends State<DetectScreen> {
  final AudioRecorderService _recorder = AudioRecorderService();
  _Stage _stage = _Stage.idle;
  DetectionResult? _result;
  String? _error;

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    setState(() => _error = null);
    if (!await _recorder.hasPermission()) {
      setState(() => _error = '需要麦克风权限才能录音，请在系统设置中允许。');
      return;
    }
    await _recorder.start();
    setState(() {
      _stage = _Stage.recording;
      _result = null;
    });
  }

  Future<void> _stopAndAnalyze() async {
    final path = await _recorder.stop();
    if (path == null) {
      setState(() {
        _stage = _Stage.idle;
        _error = '录音失败，请重试。';
      });
      return;
    }
    setState(() => _stage = _Stage.analyzing);
    // 音频很短，直接在下一帧计算；用 Future 让加载态有机会渲染
    await Future.delayed(const Duration(milliseconds: 50));
    try {
      final r = widget.service.analyzeFile(path);
      setState(() {
        _result = r;
        _stage = _Stage.result;
      });
    } catch (e) {
      setState(() {
        _stage = _Stage.idle;
        _error = '分析出错：$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('检测西瓜')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_stage) {
      case _Stage.idle:
        return _buildIdle();
      case _Stage.recording:
        return _buildRecording();
      case _Stage.analyzing:
        return const Center(child: CircularProgressIndicator());
      case _Stage.result:
        return _buildResult(context);
    }
  }

  Widget _buildIdle() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.touch_app, size: 64, color: Color(0xFF2E7D32)),
        const SizedBox(height: 16),
        Text('操作提示', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text(
          '1. 把手机麦克风靠近西瓜\n'
          '2. 点下方按钮开始录音\n'
          '3. 用指关节均匀敲 3~5 下\n'
          '4. 再次点击结束并出结果',
          style: TextStyle(height: 1.6),
        ),
        const SizedBox(height: 28),
        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
        ],
        FilledButton.icon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
          onPressed: _startRecording,
          icon: const Icon(Icons.mic),
          label: const Text('开始录音'),
        ),
      ],
    );
  }

  Widget _buildRecording() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _PulsingMic(),
        const SizedBox(height: 24),
        const Text('正在录音…请敲西瓜 3~5 下',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 28),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
          onPressed: _stopAndAnalyze,
          icon: const Icon(Icons.stop),
          label: const Text('结束并分析'),
        ),
      ],
    );
  }

  Widget _buildResult(BuildContext context) {
    final r = _result!;
    final p = r.prediction;
    final color = p.label == Ripeness.ripe
        ? const Color(0xFF2E7D32)
        : (p.label == Ripeness.unripe
            ? const Color(0xFF8BC34A)
            : const Color(0xFFC62828));

    return ListView(
      children: [
        Center(
          child: Column(
            children: [
              Text(
                p.label == Ripeness.ripe
                    ? '🍉'
                    : (p.label == Ripeness.unripe ? '🌱' : '🥵'),
                style: const TextStyle(fontSize: 60),
              ),
              const SizedBox(height: 6),
              Text(
                p.label.labelZh,
                style: TextStyle(
                    fontSize: 30, fontWeight: FontWeight.bold, color: color),
              ),
              Text('置信度 ${(p.confidence * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConfidenceBars(scores: p.scores, highlight: p.label),
          ),
        ),
        const SizedBox(height: 8),
        if (r.taps.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('声学特征（首次敲击）',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SpectrumChart(powerSpectrum: r.taps.first.powerSpectrum),
                  const SizedBox(height: 8),
                  _kv('主共振频率',
                      '${r.taps.first.dominantFreq.toStringAsFixed(0)} Hz'),
                  _kv('频谱质心',
                      '${r.taps.first.spectralCentroid.toStringAsFixed(0)} Hz'),
                  _kv('衰减时间',
                      '${(r.taps.first.decayTime * 1000).toStringAsFixed(0)} ms'),
                  _kv('检测到敲击', '${r.tapCount} 次'),
                  _kv('判定模式', p.mode == 'ml' ? '机器学习' : '启发式规则'),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        const Card(
          color: Color(0xFFFFF3E0),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Text('结果仅供参考，不保证准确。切开后欢迎回来"贡献数据"帮它变得更准。',
                style: TextStyle(fontSize: 12.5)),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => setState(() => _stage = _Stage.idle),
          icon: const Icon(Icons.refresh),
          label: const Text('再测一次'),
        ),
      ],
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: const TextStyle(color: Colors.black54)),
            Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _PulsingMic extends StatefulWidget {
  const _PulsingMic();

  @override
  State<_PulsingMic> createState() => _PulsingMicState();
}

class _PulsingMicState extends State<_PulsingMic>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 0.9, end: 1.2).animate(
          CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: Container(
        width: 110,
        height: 110,
        decoration: const BoxDecoration(
          color: Color(0x332E7D32),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.mic, size: 56, color: Color(0xFF2E7D32)),
      ),
    );
  }
}
