import 'package:flutter/material.dart';

import '../core/classifier.dart';
import '../core/detection_service.dart';
import '../core/sample_repository.dart';
import '../core/settings.dart';
import '../core/upload_service.dart';
import 'about_screen.dart';
import 'collect_screen.dart';
import 'detect_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  final RipenessClassifier classifier;
  final SampleRepository repository;
  final AppSettings settings;
  final UploadService uploader;

  const HomeScreen({
    super.key,
    required this.classifier,
    required this.repository,
    required this.settings,
    required this.uploader,
  });

  @override
  Widget build(BuildContext context) {
    final service = DetectionService(classifier);
    final isMl = classifier.mode == 'ml';

    return Scaffold(
      appBar: AppBar(
        title: const Text('熟了吗'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SettingsScreen(
                  settings: settings,
                  uploader: uploader,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AboutScreen())),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 8),
            Center(
              child: Column(
                children: [
                  const Text('🍉', style: TextStyle(fontSize: 72)),
                  const SizedBox(height: 8),
                  Text(
                    '听声辨瓜',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '用指关节敲西瓜，App 听声音判断成熟度',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Chip(
                avatar: Icon(
                  isMl ? Icons.psychology : Icons.rule,
                  size: 18,
                  color: isMl ? Colors.green : Colors.orange,
                ),
                label: Text(isMl ? '机器学习模式' : '启发式模式（经验规则）'),
              ),
            ),
            const SizedBox(height: 20),
            _NavCard(
              icon: Icons.mic,
              color: const Color(0xFF2E7D32),
              title: '开始检测',
              subtitle: '录一段敲击声，判断这个瓜熟不熟',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => DetectScreen(
                          service: service,
                          repository: repository,
                        )),
              ),
            ),
            _NavCard(
              icon: Icons.dataset,
              color: const Color(0xFF00897B),
              title: '贡献数据 · 帮它变准',
              subtitle: '切开后告诉它真实结果，一起训练更准的模型',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CollectScreen(
                    service: service,
                    repository: repository,
                    settings: settings,
                    uploader: uploader,
                  ),
                ),
              ),
            ),
            _NavCard(
              icon: Icons.folder_open,
              color: const Color(0xFF5D4037),
              title: '我的采集数据',
              subtitle: '查看/导出已采集样本（用于训练）',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => HistoryScreen(repository: repository)),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: const Color(0xFFFFF3E0),
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '结果仅供参考。声学判瓜受品种、环境噪声、敲击手法影响，'
                        '不保证准确，请理性使用。',
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: color.withOpacity(0.12),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
