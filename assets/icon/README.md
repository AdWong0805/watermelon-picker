# App 图标

- `source.png`：原始西瓜图（任意尺寸/比例，可非正方形）。
- `app_icon.png`：由 `tools/prepare_icon.py` 居中裁成 1024×1024 的正方形图标，供 `flutter_launcher_icons` 使用。

## 更换图标流程
1. 把新图放为 `assets/icon/source.png`
2. `python tools/prepare_icon.py`（需 `pip install pillow`）
3. `dart run flutter_launcher_icons`（生成安卓+iOS 全套尺寸）
4. `flutter run` 查看
