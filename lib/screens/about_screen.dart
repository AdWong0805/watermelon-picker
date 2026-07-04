import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('关于 / 原理 / 隐私')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            _Section(
              title: '工作原理',
              body:
                  '西瓜成熟时内部糖度、密度和组织结构会变化，敲击产生的共振频率（可理解为西瓜的"声纹"）'
                  '也随之改变。成熟瓜通常声音更低沉。App 用麦克风录下敲击声，做傅里叶变换提取'
                  '主共振频率、频谱质心、梅尔倒谱系数(MFCC)、衰减时间等特征，再由分类器判断成熟度。',
            ),
            _Section(
              title: '两种判定模式',
              body:
                  '· 启发式模式：基于声学经验规则，无需训练数据，开箱即用。\n'
                  '· 机器学习模式：当积累到足够的"敲击声+真实结果"样本并训练出模型后，App 自动升级为更准的 ML 判定。',
            ),
            _Section(
              title: '隐私说明',
              body:
                  '· 录音与采集样本默认只保存在你的手机本地，不会自动上传。\n'
                  '· 只有你主动点"导出"分享数据时，数据才会离开设备。\n'
                  '· App 不收集任何个人身份信息。',
            ),
            _Section(
              title: '免责声明',
              body:
                  '声学判瓜受品种、成熟阶段、环境噪声、敲击手法与手机麦克风差异影响，'
                  '学术研究报告的准确率多在受控条件下取得，真实使用会有波动。'
                  '本 App 结果仅供参考，不构成任何购买或食用建议，请理性使用。',
            ),
            _Section(
              title: '参考文献（节选）',
              body:
                  '1. Zeng et al. Classifying watermelon ripeness by analysing acoustic signals using mobile devices. 2013.\n'
                  '2. MFCC + MLP 无损分类, IJCNN 2010.\n'
                  '3. 梅尔谱 + ECAPA-TDNN, ICNC-FSKD 2024.\n'
                  '4. 声学共振 + CNN, htw saar.\n'
                  '5. 多模态成熟度分类, Springer 2025.\n'
                  '6. 基于 BMV 特征的西瓜成熟度无损检测, 农业工程学报 2010.',
            ),
            SizedBox(height: 16),
            Center(child: Text('熟了吗 v1.0.0', style: TextStyle(color: Colors.black45))),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;

  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(height: 1.6)),
        ],
      ),
    );
  }
}
