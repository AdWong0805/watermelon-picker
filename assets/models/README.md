# 模型目录

App 启动时会尝试加载 `model.json`：
- **存在** → 使用机器学习模式（训练管线 `training/train.py --deploy` 产出）。
- **不存在** → 自动回退到启发式（规则）模式，App 依然可用。

进阶 CNN 路线会额外放 `ripeness_model.tflite` + `labels.txt`。
