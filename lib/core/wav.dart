import 'dart:io';
import 'dart:typed_data';

/// 极简 WAV (PCM16) 读写工具。
class WavData {
  final Float64List samples; // 归一化到 [-1, 1] 的单声道样本
  final int sampleRate;

  const WavData(this.samples, this.sampleRate);
}

class Wav {
  /// 读取 WAV 文件，转单声道 float。支持 PCM16 / PCM8。
  static WavData readFile(String path) {
    final bytes = File(path).readAsBytesSync();
    return decode(bytes);
  }

  static WavData decode(Uint8List bytes) {
    final bd = ByteData.sublistView(bytes);
    if (bytes.length < 44) {
      return WavData(Float64List(0), 22050);
    }
    // 解析 RIFF header，定位 fmt 与 data chunk
    int pos = 12; // 跳过 "RIFF"<size>"WAVE"
    int numChannels = 1;
    int sampleRate = 22050;
    int bitsPerSample = 16;
    int dataOffset = -1;
    int dataLen = 0;

    while (pos + 8 <= bytes.length) {
      final chunkId = String.fromCharCodes(bytes.sublist(pos, pos + 4));
      final chunkSize = bd.getUint32(pos + 4, Endian.little);
      final body = pos + 8;
      if (chunkId == 'fmt ') {
        numChannels = bd.getUint16(body + 2, Endian.little);
        sampleRate = bd.getUint32(body + 4, Endian.little);
        bitsPerSample = bd.getUint16(body + 14, Endian.little);
      } else if (chunkId == 'data') {
        dataOffset = body;
        dataLen = chunkSize;
      }
      pos = body + chunkSize + (chunkSize.isOdd ? 1 : 0);
    }

    if (dataOffset < 0) {
      return WavData(Float64List(0), sampleRate);
    }
    if (dataOffset + dataLen > bytes.length) {
      dataLen = bytes.length - dataOffset;
    }

    final bytesPerSample = bitsPerSample ~/ 8;
    final frameCount = dataLen ~/ (bytesPerSample * numChannels);
    final out = Float64List(frameCount);

    for (int i = 0; i < frameCount; i++) {
      double sum = 0;
      for (int c = 0; c < numChannels; c++) {
        final off = dataOffset + (i * numChannels + c) * bytesPerSample;
        double v;
        if (bitsPerSample == 16) {
          v = bd.getInt16(off, Endian.little) / 32768.0;
        } else if (bitsPerSample == 8) {
          v = (bd.getUint8(off) - 128) / 128.0;
        } else if (bitsPerSample == 32) {
          v = bd.getInt32(off, Endian.little) / 2147483648.0;
        } else {
          v = 0;
        }
        sum += v;
      }
      out[i] = sum / numChannels;
    }
    return WavData(out, sampleRate);
  }

  /// 把归一化样本编码为 PCM16 WAV 字节。
  static Uint8List encode(Float64List samples, int sampleRate) {
    final n = samples.length;
    final dataLen = n * 2;
    final buf = BytesBuilder();
    final header = ByteData(44);
    void writeStr(int off, String s) {
      for (int i = 0; i < s.length; i++) {
        header.setUint8(off + i, s.codeUnitAt(i));
      }
    }

    writeStr(0, 'RIFF');
    header.setUint32(4, 36 + dataLen, Endian.little);
    writeStr(8, 'WAVE');
    writeStr(12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little); // PCM
    header.setUint16(22, 1, Endian.little); // mono
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * 2, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    writeStr(36, 'data');
    header.setUint32(40, dataLen, Endian.little);
    buf.add(header.buffer.asUint8List());

    final pcm = ByteData(dataLen);
    for (int i = 0; i < n; i++) {
      var v = (samples[i] * 32767.0).round();
      if (v > 32767) v = 32767;
      if (v < -32768) v = -32768;
      pcm.setInt16(i * 2, v, Endian.little);
    }
    buf.add(pcm.buffer.asUint8List());
    return buf.toBytes();
  }
}
