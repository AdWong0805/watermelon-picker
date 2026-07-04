"""把任意图片居中裁成正方形 1024x1024，输出为 App 图标源图。

用法：
  pip install pillow
  python tools/prepare_icon.py [源图路径]

默认源图: assets/icon/source.png
输出:     assets/icon/app_icon.png   （供 flutter_launcher_icons 使用）
"""
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_SRC = os.path.join(HERE, "assets", "icon", "source.png")
OUT = os.path.join(HERE, "assets", "icon", "app_icon.png")
SIZE = 1024


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_SRC
    if not os.path.exists(src):
        print(f"找不到源图: {src}")
        print("请先把西瓜图片放到该路径，或作为参数传入。")
        return

    img = Image.open(src).convert("RGB")
    w, h = img.size
    side = min(w, h)
    left = (w - side) // 2
    top = (h - side) // 2
    img = img.crop((left, top, left + side, top + side))
    img = img.resize((SIZE, SIZE), Image.LANCZOS)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT, "PNG")
    print(f"已生成正方形图标: {OUT} ({SIZE}x{SIZE})")
    print("下一步: dart run flutter_launcher_icons")


if __name__ == "__main__":
    main()
