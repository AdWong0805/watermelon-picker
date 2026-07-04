import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'feature_spec.dart';

/// 录音封装（跨平台）。录制单声道 PCM16 WAV，采样率对齐特征规范。
class AudioRecorderService {
  final AudioRecorder _rec = AudioRecorder();

  Future<bool> hasPermission() => _rec.hasPermission();

  Future<bool> isRecording() => _rec.isRecording();

  /// 开始录音，返回目标文件路径。
  Future<String> start() async {
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/tap_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _rec.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: FeatureSpec.sampleRate,
        numChannels: 1,
      ),
      path: path,
    );
    return path;
  }

  /// 停止录音，返回文件路径（可能为 null）。
  Future<String?> stop() => _rec.stop();

  Future<void> cancel() async {
    try {
      await _rec.cancel();
    } catch (_) {}
  }

  Future<void> dispose() => _rec.dispose();
}
