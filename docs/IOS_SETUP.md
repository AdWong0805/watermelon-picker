# iOS 端从零跑起来（在 Mac 上操作）

> iOS 的编译、真机运行、上架**只能在 macOS + Xcode 上完成**，Windows 无法。
> 代码本身已跨平台（`ios/` 目录、麦克风权限均已就绪），无需重写。

## 步骤总览

1. 把项目代码从 Windows 弄到 Mac
2. Mac 上装 Flutter + Xcode + CocoaPods
3. `flutter pub get` + `pod install`
4. Xcode 配签名
5. 跑模拟器 / 真机

---

## 1. 把代码弄到 Mac（三选一）

### 方式 A：Gitee（推荐，国内不用 VPN）
Windows 上：
```powershell
cd "C:\Users\AD Wang\watermelon"
git init
git add .
git commit -m "init: 瓜熟 MVP"
# 在 gitee.com 建一个空仓库，拿到地址后：
git remote add origin https://gitee.com/<你的用户名>/watermelon.git
git branch -M main
git push -u origin main
```
Mac 上：
```bash
git clone https://gitee.com/<你的用户名>/watermelon.git
```

### 方式 B：GitHub（需要 VPN 稳定）
同上，把 gitee 换成 github。

### 方式 C：直接拷贝（不想用 git）
Windows 上先清掉构建产物再拷，避免拷进无用大文件：
```powershell
cd "C:\Users\AD Wang\watermelon"
flutter clean
```
然后把整个 `watermelon` 文件夹通过 U 盘 / 网盘（OneDrive、百度网盘等）拷到 Mac。
> 到 Mac 后会重新 `flutter pub get` / `pod install` 生成依赖，无需拷 `build/`、`.dart_tool/`、`ios/Pods/`。

---

## 2. Mac 上装工具

### Xcode
App Store 搜 Xcode 安装（较大，耐心）。装完打开一次同意协议，并跑：
```bash
sudo xcodebuild -license accept
xcode-select --install   # 命令行工具（若未装）
```

### Flutter（Apple Silicon / Intel 通用）
```bash
# 下 SDK（也可去 flutter.dev 下 zip）
cd ~/development 2>/dev/null || mkdir -p ~/development && cd ~/development
# 解压 flutter_macos_*.zip 到这里，得到 ~/development/flutter
# 然后把 PATH 写进 shell 配置：
echo 'export PATH="$HOME/development/flutter/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
flutter --version
```
> Apple Silicon (M 系列) 还需装 Rosetta（部分工具依赖）：
```bash
sudo softwareupdate --install-rosetta --agree-to-license
```

### CocoaPods（iOS 依赖管理）
```bash
sudo gem install cocoapods
# 若报权限/版本问题，可用 brew: brew install cocoapods
```

### 体检
```bash
flutter doctor -v
```
让 `[✓] Xcode` 变绿。缺什么按提示补。

---

## 3. 拉依赖

```bash
cd watermelon
flutter pub get
cd ios
pod install
cd ..
```
> 若 `pod install` 慢或报 CDN 错，可换清华镜像源（网上搜 "CocoaPods 清华镜像"），或重试。

---

## 4. 配签名（真机 / 上架必需，模拟器可跳过）

```bash
open ios/Runner.xcworkspace
```
在 Xcode 里：
- 左侧选 `Runner` → 中间 `Signing & Capabilities`
- 勾 `Automatically manage signing`
- `Team` 选你的 Apple ID
  - 免费 Apple ID：可真机调试（证书 7 天有效，到期重签）
  - 上架 App Store：需 Apple Developer Program（$99/年）
- Bundle Identifier 已是 `com.guashu.guashu`，如与他人冲突就改成唯一的（如 `com.你的名字.guashu`）

---

## 5. 运行

### 模拟器
```bash
open -a Simulator
flutter run
```
> 注意：模拟器**没有真实麦克风**，录不到敲击声，只能看 UI / 走流程。测检测要用真机。

### 真机 iPhone
- 插 USB，iPhone 上"信任此电脑"
- 首次需在 iPhone：设置 → 通用 → VPN与设备管理 → 信任你的开发者证书
```bash
flutter devices     # 确认认到 iPhone
flutter run
```
App 首次用麦克风会弹权限，点允许。

---

## 常见坑

- **CocoaPods 报错 / pod not found**：确认 `pod --version` 能用；`cd ios && pod repo update && pod install`。
- **签名失败 "No profiles"**：Xcode 里选对 Team；Bundle ID 改唯一。
- **最低 iOS 版本**：如报版本过低，改 `ios/Podfile` 顶部 `platform :ios, '12.0'`（或更高）后 `pod install`。
- **Apple Silicon pod 架构问题**：`cd ios && arch -x86_64 pod install`（少数情况）。

---

## 上架 App Store（将来）
见 `docs/DESIGN.md` 的合规清单。核心：开发者账号、App 图标、隐私政策 URL、App Privacy 表单、`NSMicrophoneUsageDescription`（已配）、用 Xcode Archive → 上传 App Store Connect。
