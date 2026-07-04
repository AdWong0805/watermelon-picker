import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';

import 'models.dart';

/// 一条采集样本。
class Sample {
  final String id;
  final String wavFilename;
  final Ripeness label;
  final String note;
  final int timestampMs;
  final double dominantFreq;
  bool uploaded; // 是否已上传到云端（架构预留；当前恒为 false）

  Sample({
    required this.id,
    required this.wavFilename,
    required this.label,
    required this.note,
    required this.timestampMs,
    required this.dominantFreq,
    this.uploaded = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'wav': wavFilename,
        'label': label.labelEn,
        'note': note,
        'timestamp_ms': timestampMs,
        'dominant_freq': dominantFreq,
        'uploaded': uploaded,
      };

  factory Sample.fromJson(Map<String, dynamic> j) => Sample(
        id: j['id'] as String,
        wavFilename: j['wav'] as String,
        label: Ripeness.fromLabel(j['label'] as String) ?? Ripeness.ripe,
        note: (j['note'] ?? '') as String,
        timestampMs: (j['timestamp_ms'] as num).toInt(),
        dominantFreq: ((j['dominant_freq'] ?? 0) as num).toDouble(),
        uploaded: (j['uploaded'] ?? false) as bool,
      );
}

/// 采集样本的本地持久化 + 导出。
///
/// 隐私：默认仅本地存储，不上传。导出 zip 由用户手动分享，用于自行训练。
class SampleRepository {
  Directory? _dir;
  final List<Sample> _samples = [];

  List<Sample> get samples => List.unmodifiable(_samples);

  Future<Directory> get _dataDir async {
    if (_dir != null) return _dir!;
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/samples');
    if (!await d.exists()) await d.create(recursive: true);
    _dir = d;
    return d;
  }

  File get _indexFileSync => File('${_dir!.path}/index.json');

  Future<void> load() async {
    await _dataDir;
    _samples.clear();
    final idx = _indexFileSync;
    if (await idx.exists()) {
      try {
        final list = json.decode(await idx.readAsString()) as List;
        for (final e in list) {
          _samples.add(Sample.fromJson(e as Map<String, dynamic>));
        }
      } catch (_) {}
    }
  }

  Future<void> _persist() async {
    await _dataDir;
    await _indexFileSync
        .writeAsString(json.encode(_samples.map((s) => s.toJson()).toList()));
  }

  /// 复制录音文件进样本库并登记标签。
  Future<Sample> add({
    required String srcWavPath,
    required Ripeness label,
    required String note,
    required double dominantFreq,
  }) async {
    final dir = await _dataDir;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final filename = '${label.labelEn}_$id.wav';
    await File(srcWavPath).copy('${dir.path}/$filename');
    final sample = Sample(
      id: id,
      wavFilename: filename,
      label: label,
      note: note,
      timestampMs: int.parse(id),
      dominantFreq: dominantFreq,
    );
    _samples.insert(0, sample);
    await _persist();
    return sample;
  }

  /// 取样本对应的 wav 文件（供上传等使用）。
  Future<File> wavFile(Sample s) async {
    final dir = await _dataDir;
    return File('${dir.path}/${s.wavFilename}');
  }

  /// 标记某样本已上传并持久化。
  Future<void> markUploaded(String id) async {
    final i = _samples.indexWhere((s) => s.id == id);
    if (i < 0) return;
    _samples[i].uploaded = true;
    await _persist();
  }

  Future<void> delete(String id) async {
    final dir = await _dataDir;
    final i = _samples.indexWhere((s) => s.id == id);
    if (i < 0) return;
    final f = File('${dir.path}/${_samples[i].wavFilename}');
    if (await f.exists()) await f.delete();
    _samples.removeAt(i);
    await _persist();
  }

  Map<Ripeness, int> countByLabel() {
    final m = {for (final r in Ripeness.values) r: 0};
    for (final s in _samples) {
      m[s.label] = (m[s.label] ?? 0) + 1;
    }
    return m;
  }

  /// 导出全部样本为 zip（含 labels.csv + 所有 wav），返回 zip 文件路径。
  /// 生成的 labels.csv 直接兼容 training/train.py。
  Future<String> exportZip() async {
    final dir = await _dataDir;
    final encoder = ZipFileEncoder();
    final base = await getTemporaryDirectory();
    final zipPath =
        '${base.path}/guashu_samples_${DateTime.now().millisecondsSinceEpoch}.zip';
    encoder.create(zipPath);

    final csv = StringBuffer('filepath,label\n');
    for (final s in _samples) {
      csv.write('${s.wavFilename},${s.label.labelEn}\n');
      final f = File('${dir.path}/${s.wavFilename}');
      if (await f.exists()) {
        await encoder.addFile(f);
      }
    }
    final csvFile = File('${base.path}/labels.csv');
    await csvFile.writeAsString(csv.toString());
    await encoder.addFile(csvFile);
    encoder.closeSync();
    return zipPath;
  }

  int get total => _samples.length;

  /// 各类是否已达到建议的最小训练量。
  static const int suggestedPerClass = 60;
  bool get readyToTrain =>
      countByLabel().values.every((c) => c >= suggestedPerClass) &&
      Ripeness.values.length <= countByLabel().keys.length;
}
