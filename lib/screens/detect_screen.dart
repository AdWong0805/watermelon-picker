import 'package:flutter/material.dart';

import '../core/audio_recorder.dart';
import '../core/detection_service.dart';
import '../core/models.dart';
import '../core/sample_repository.dart';
import '../widgets/confidence_bar.dart';
import '../widgets/spectrum_painter.dart';

enum _Stage { idle, recording, analyzing, result }

const _brandGreen = Color(0xFF2E7D32);
const _brandLight = Color(0xFF66BB6A);

class DetectScreen extends StatefulWidget {
  final DetectionService service;
  final SampleRepository repository;

  const DetectScreen({
    super.key,
    required this.service,
    required this.repository,
  });

  @override
  State<DetectScreen> createState() => _DetectScreenState();
}

class _DetectScreenState extends State<DetectScreen> {
  final AudioRecorderService _recorder = AudioRecorderService();
  _Stage _stage = _Stage.idle;
  DetectionResult? _result;
  String? _error;
  bool _saved = false;

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
      _saved = false;
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

  /// 把这次录音保存为训练样本：让用户确认切开后的真实结果 + 起名。
  Future<void> _saveSample() async {
    final r = _result;
    if (r == null) return;
    Ripeness chosen = r.prediction.label;
    final nameCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('保存为训练样本'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('这个瓜切开后实际是？（如实标注才能帮模型变准）',
                    style: TextStyle(fontSize: 13.5)),
                const SizedBox(height: 8),
                ...Ripeness.values.map((rp) => RadioListTile<Ripeness>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: rp,
                      groupValue: chosen,
                      onChanged: (v) => setDialog(() => chosen = v!),
                      title: Text(rp.labelZh),
                    )),
                const SizedBox(height: 4),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '名称（可选）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
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

    if (ok != true) return;
    await widget.repository.add(
      srcWavPath: r.wavPath,
      label: chosen,
      note: '',
      name: nameCtrl.text.trim(),
      dominantFreq: r.taps.isNotEmpty ? r.taps.first.dominantFreq : 0,
    );
    if (!mounted) return;
    setState(() => _saved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已保存到"我的采集数据"')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('检测西瓜'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF6EC), Color(0xFFF6F8F4)],
          ),
        ),
        child: SafeArea(child: _buildBody(context)),
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
        return _buildAnalyzing();
      case _Stage.result:
        return _buildResult(context);
    }
  }

  Widget _buildIdle() {
    return Column(
      children: [
        const SizedBox(height: 12),
        // 主视觉
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Column(
              children: [
                Container(
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [Color(0xFFDCF2E1), Color(0xFFB8E2C0)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _brandGreen.withOpacity(0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('🍉', style: TextStyle(fontSize: 72)),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '听声辨瓜',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold, color: _brandGreen),
                ),
                const SizedBox(height: 4),
                const Text(
                  '敲一敲，听听这个瓜熟没熟',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 24),
                _instructionCard(),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  _errorBox(_error!),
                ],
              ],
            ),
          ),
        ),
        _bottomButton(
          label: '开始录音',
          icon: Icons.mic,
          onTap: _startRecording,
        ),
      ],
    );
  }

  Widget _instructionCard() {
    final steps = [
      '把手机麦克风靠近西瓜',
      '点下方按钮开始录音',
      '用指关节均匀敲 3~5 下',
      '再次点击结束并出结果',
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.lightbulb_outline, size: 20, color: _brandGreen),
              SizedBox(width: 6),
              Text('操作步骤',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < steps.length; i++) ...[
            _stepRow(i + 1, steps[i]),
            if (i != steps.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _stepRow(int n, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [_brandGreen, _brandLight]),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text('$n',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14.5))),
      ],
    );
  }

  Widget _buildRecording() {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                _PulseMic(),
                SizedBox(height: 36),
                Text('正在聆听…',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('对着西瓜用指关节敲 3~5 下',
                    style: TextStyle(color: Colors.black54)),
              ],
            ),
          ),
        ),
        _bottomButton(
          label: '结束并分析',
          icon: Icons.stop,
          onTap: _stopAndAnalyze,
          danger: true,
        ),
      ],
    );
  }

  Widget _buildAnalyzing() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: _brandGreen),
          SizedBox(height: 16),
          Text('正在分析声音…', style: TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildResult(BuildContext context) {
    final r = _result!;
    final p = r.prediction;
    final color = _colorFor(p.label);
    final emoji = p.label == Ripeness.ripe
        ? '🍉'
        : (p.label == Ripeness.unripe ? '🌱' : '🥵');

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              children: [
                // 结果横幅
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 26),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [color, color.withOpacity(0.72)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.35),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 56)),
                      const SizedBox(height: 6),
                      Text(
                        p.label.labelZh,
                        style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '置信度 ${(p.confidence * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _card(child: ConfidenceBars(scores: p.scores, highlight: p.label)),
                const SizedBox(height: 12),
                if (r.taps.isNotEmpty)
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('声学特征（首次敲击）',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        SpectrumChart(
                            powerSpectrum: r.taps.first.powerSpectrum),
                        const SizedBox(height: 10),
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
                const SizedBox(height: 12),
                _saveSampleButton(),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 18, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '结果仅供参考。切开后欢迎回来"贡献数据"帮它变得更准。',
                          style: TextStyle(fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _bottomButton(
          label: '再测一次',
          icon: Icons.refresh,
          onTap: () => setState(() => _stage = _Stage.idle),
        ),
      ],
    );
  }

  // ---- 复用小组件 ----

  Widget _saveSampleButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: _brandGreen,
          side: const BorderSide(color: _brandGreen),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: _saved ? null : _saveSample,
        icon: Icon(_saved ? Icons.check_circle : Icons.save_alt),
        label: Text(_saved ? '已保存为训练样本' : '保存这次录音（用于训练）'),
      ),
    );
  }

  Widget _bottomButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final colors = danger
        ? [const Color(0xFFE53935), const Color(0xFFEF5350)]
        : [_brandGreen, _brandLight];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: colors.first.withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 10),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _errorBox(String msg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(msg, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: const TextStyle(color: Colors.black54)),
            Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );

  static Color _colorFor(Ripeness r) {
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

/// 录音时的水波脉冲麦克风。
class _PulseMic extends StatefulWidget {
  const _PulseMic();

  @override
  State<_PulseMic> createState() => _PulseMicState();
}

class _PulseMicState extends State<_PulseMic>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              for (int i = 0; i < 3; i++) _ring(i),
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [_brandGreen, _brandLight]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic, size: 46, color: Colors.white),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _ring(int i) {
    final t = (_c.value + i / 3) % 1.0;
    final size = 96 + t * 104;
    final opacity = (1 - t) * 0.35;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: _brandGreen.withOpacity(opacity.clamp(0.0, 1.0)),
          width: 2,
        ),
      ),
    );
  }
}
