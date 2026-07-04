import 'dart:convert';
import 'dart:io';

import 'models.dart';

/// 上传结果状态。
enum UploadState {
  disabled, // 用户未开启上传
  notConfigured, // 未配置服务器端点（当前默认）
  success,
  failed,
}

/// 众包数据上传服务（架构预留）。
///
/// 现在 [endpoint] 默认为空 => [isConfigured] 为 false => 一律仅本地保存，不联网。
/// 将来接后端时，只需把 [kUploadEndpoint] 填成你的服务器地址即可启用，
/// 无需改动 UI/采集流程。实现用内置 dart:io，无第三方依赖。
///
/// 合规提醒：真正启用上传前，必须有隐私政策 + 用户明确同意（见 AppSettings.consent）。
const String kUploadEndpoint = ''; // TODO: 例如 'https://api.yourserver.com/samples'

class UploadService {
  final String endpoint;

  UploadService({this.endpoint = kUploadEndpoint});

  bool get isConfigured => endpoint.trim().isNotEmpty;

  /// 上传单条样本（wav + 元数据）。当前未配置端点时直接返回 notConfigured。
  Future<UploadState> uploadSample({
    required File wav,
    required Ripeness label,
    required String note,
    required double dominantFreq,
    String? deviceModel,
  }) async {
    if (!isConfigured) return UploadState.notConfigured;
    try {
      final bytes = await wav.readAsBytes();
      final uri = Uri.parse(endpoint);
      final client = HttpClient();
      final req = await client.postUrl(uri);

      // 简单 multipart/form-data 组装（匿名，不含个人信息）
      const boundary = '----guashuBoundary7MA4YWxkTrZu0gW';
      req.headers.set(HttpHeaders.contentTypeHeader,
          'multipart/form-data; boundary=$boundary');

      final meta = json.encode({
        'label': label.labelEn,
        'note': note,
        'dominant_freq': dominantFreq,
        'device_model': deviceModel ?? 'unknown',
        'client': 'guashu',
      });

      final head = StringBuffer()
        ..write('--$boundary\r\n')
        ..write('Content-Disposition: form-data; name="meta"\r\n\r\n')
        ..write('$meta\r\n')
        ..write('--$boundary\r\n')
        ..write('Content-Disposition: form-data; name="audio"; '
            'filename="${wav.uri.pathSegments.last}"\r\n')
        ..write('Content-Type: audio/wav\r\n\r\n');
      final tail = '\r\n--$boundary--\r\n';

      req.add(utf8.encode(head.toString()));
      req.add(bytes);
      req.add(utf8.encode(tail));

      final resp = await req.close();
      client.close();
      return (resp.statusCode >= 200 && resp.statusCode < 300)
          ? UploadState.success
          : UploadState.failed;
    } catch (_) {
      return UploadState.failed;
    }
  }
}
