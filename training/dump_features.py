"""特征对齐校验工具。

对同一个 wav 文件，用本脚本(Python/librosa)导出特征向量，
再用 App 里的"开发者→导出特征"功能对同一录音导出，二者应基本一致。
若差异大，说明 Dart 端特征实现与本规范不一致，需要校准，否则模型会掉点。

用法: python dump_features.py path/to/tap.wav
"""
import json
import sys

from features import extract_from_file, FEATURE_ORDER


def main():
    if len(sys.argv) < 2:
        print("用法: python dump_features.py <audio_file>")
        return
    vec = extract_from_file(sys.argv[1])
    out = {name: round(float(v), 6) for name, v in zip(FEATURE_ORDER, vec)}
    print(json.dumps(out, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
