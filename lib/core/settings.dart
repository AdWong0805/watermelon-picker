import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 应用设置（本地持久化）。目前主要承载"是否允许匿名上传数据"的开关与同意状态。
class AppSettings {
  bool uploadEnabled;
  int consentAcceptedMs; // 0 = 从未同意

  AppSettings({this.uploadEnabled = false, this.consentAcceptedMs = 0});

  bool get hasConsented => consentAcceptedMs > 0;

  File? _file;

  Future<File> get _settingsFile async {
    if (_file != null) return _file!;
    final base = await getApplicationDocumentsDirectory();
    _file = File('${base.path}/settings.json');
    return _file!;
  }

  static Future<AppSettings> load() async {
    final s = AppSettings();
    try {
      final f = await s._settingsFile;
      if (await f.exists()) {
        final m = json.decode(await f.readAsString()) as Map<String, dynamic>;
        s.uploadEnabled = (m['upload_enabled'] ?? false) as bool;
        s.consentAcceptedMs = (m['consent_accepted_ms'] ?? 0) as int;
      }
    } catch (_) {}
    return s;
  }

  Future<void> save() async {
    final f = await _settingsFile;
    await f.writeAsString(json.encode({
      'upload_enabled': uploadEnabled,
      'consent_accepted_ms': consentAcceptedMs,
    }));
  }
}
