import 'package:flutter/material.dart';

import '../core/settings.dart';
import '../core/upload_service.dart';

class SettingsScreen extends StatefulWidget {
  final AppSettings settings;
  final UploadService uploader;

  const SettingsScreen({
    super.key,
    required this.settings,
    required this.uploader,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _toggleUpload(bool value) async {
    if (value && !widget.settings.hasConsented) {
      final ok = await _showConsentDialog();
      if (ok != true) return;
      widget.settings.consentAcceptedMs = DateTime.now().millisecondsSinceEpoch;
    }
    widget.settings.uploadEnabled = value;
    await widget.settings.save();
    setState(() {});
  }

  Future<bool?> _showConsentDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('数据上传同意'),
        content: const SingleChildScrollView(
          child: Text(
            '开启后，你保存的"敲击声录音 + 你标注的成熟度"将被匿名上传，'
            '用于改进西瓜成熟度识别模型。\n\n'
            '• 不收集任何个人身份信息（不含姓名/账号/位置）。\n'
            '• 仅上传音频与你选择的标签、机型等技术信息。\n'
            '• 你可随时在设置里关闭。\n\n'
            '是否同意？',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('不同意')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('同意并开启')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final configured = widget.uploader.isConfigured;
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: SafeArea(
        child: ListView(
          children: [
            SwitchListTile(
              title: const Text('允许匿名上传数据帮助改进模型'),
              subtitle: Text(
                s.uploadEnabled
                    ? (configured
                        ? '已开启：保存样本时会尝试匿名上传'
                        : '已开启，但服务器尚未配置——当前仍仅本地保存')
                    : '关闭（默认）：数据只存本地，绝不上传',
              ),
              value: s.uploadEnabled,
              onChanged: _toggleUpload,
            ),
            const Divider(height: 1),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '说明：本功能为未来众包预留。目前后端尚未接入（服务器地址为空），'
                '因此即使开启，数据也不会真正上传，仅保存在本机。'
                '待正式接入服务器并提供隐私政策后，此开关才会生效。',
                style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.5),
              ),
            ),
            if (s.hasConsented)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '已于 ${DateTime.fromMillisecondsSinceEpoch(s.consentAcceptedMs)} 同意上传条款',
                  style: const TextStyle(fontSize: 12, color: Colors.black38),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
