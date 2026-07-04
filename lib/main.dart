import 'package:flutter/material.dart';

import 'core/classifier.dart';
import 'core/classifier_factory.dart';
import 'core/sample_repository.dart';
import 'core/settings.dart';
import 'core/upload_service.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final classifier = await ClassifierFactory.load();
  final repo = SampleRepository();
  await repo.load();
  final settings = await AppSettings.load();
  final uploader = UploadService();
  runApp(GuaShuApp(
    classifier: classifier,
    repository: repo,
    settings: settings,
    uploader: uploader,
  ));
}

/// 应用根。持有全局服务（分类器 + 采集仓库 + 设置 + 上传服务），向下传递。
class GuaShuApp extends StatelessWidget {
  final RipenessClassifier classifier;
  final SampleRepository repository;
  final AppSettings settings;
  final UploadService uploader;

  const GuaShuApp({
    super.key,
    required this.classifier,
    required this.repository,
    required this.settings,
    required this.uploader,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E7D32),
      brightness: Brightness.light,
    );
    return MaterialApp(
      title: '瓜熟',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF6F8F4),
        appBarTheme: const AppBarTheme(centerTitle: true),
      ),
      home: HomeScreen(
        classifier: classifier,
        repository: repository,
        settings: settings,
        uploader: uploader,
      ),
    );
  }
}
