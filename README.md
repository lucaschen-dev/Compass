# Compass · Buckley Community (Flutter + 原生 Apple 界面)

从本机 `Downloads/Community APP v1.0` 的 SwiftUI 客户端迁移而来。原项目保留，Python 后端源码放在 `backend/`，接口保持兼容。当前开发环境：Flutter 3.47.7 / Dart 3.13.5。

**Apple 界面已重做**：iPhone 使用 SwiftUI 的系统标签栏、导航栏与表单；Mac 使用 SwiftUI 的系统侧边栏、工具栏和分栏。Flutter 继续持有业务状态并执行原服务器接口请求，两端通过 MethodChannel 通信。

## 在这台 Mac 的 VS Code 运行

1. 打开此文件夹（包含 `pubspec.yaml` 的这一层）。
2. 左侧打开「运行和调试」，选择 **Compass · Mac**。
3. 按 **F5**，在 App 中选择 **Explore the demo**，或 **Join your school** 登录原账号。
4. 业务逻辑在 `lib/`，可用 Flutter 调试。Apple 界面在 `apple/`，修改 SwiftUI 后需要停止并重新运行；Flutter Hot Reload 不会重新编译 Swift。

VS Code 的 Dart、Flutter 扩展已安装。此电脑的 Flutter SDK 路径已写入 `.vscode/settings.json`。换电脑时请调整或删除该路径。

终端也可运行：

```sh
flutter pub get
flutter run -d macos
```

真实服务器默认地址：`https://api.buckley.community`。开发者可在登录页修改；HTTP 仅允许 localhost。迁移不包含原 SwiftUI App 的本地草稿、待办或钥匙串登录状态，需要在新版重新登录和连接作业 Feed。账号、帖子、聊天等服务器数据仍由原服务器提供。

## 已迁移

- 学校邮箱验证码、密码登录、重设密码和初次个人资料填写；系统安全存储保存会话。
- 首页、重要帖子、搜索、分类、收藏、匿名发帖、优先级申请、指定回答者、回复、举报、屏蔽和自己的帖子管理。
- 照片帖子（最多 20 张）：图片自动转为 JPEG，匹配后端 1600 像素 / 512 KiB 限制。
- 私聊、群聊、成员选择、群信息、退群、引用回复、消息撤回、图片和短视频附件。
- 个人资料、Instagram 链接、账户分隔的本地待办。
- My Buckley iCalendar 私人订阅导入、课程分组、测验筛选、搜索、缓存、作业加入待办。订阅凭证仅保存在系统安全存储；不发送给社区后端；拒绝重定向。重复事件保留提示并链接回学校平台，不自动展开。
- 管理员帖子查询、分页、作者识别、发布/驳回/删除、评论删除和举报处理。后端仍执行权限检查。
- 演示数据、草稿和收藏在本机保存；示例人物沿用原版，不冒充真实学生。

## 平台和差异

- **macOS 14+**：使用 SwiftUI 的 NavigationSplitView、原生工具栏、原生表单与系统菜单；需要 CocoaPods（本机已安装）。网络与文件选择权限已配置。安全存储使用 macOS 系统钥匙串，按插件官方说明关闭 data protection keychain，不要求额外的 Keychain Sharing provisioning profile。
- **iOS 17+**：使用真正 SwiftUI 系统控件。iOS 26+ 使用系统提供的现代玻璃导航、标签栏和玻璃按钮；早期系统提供原生回退样式。发布和真机安装仍使用 Xcode 的签名；尚未在用户 iPhone 上安装。
- **Android**：项目和网络权限已生成；本机尚无 Android SDK，未编译或验证。
- **Windows / Linux**：工程已生成，尚未在对应系统构建或验证。Linux 还需按安全存储和视频插件文档安装系统依赖。
- **Web**：适合演示。原后端没有浏览器 CORS 支持，私有学校 Feed 也受浏览器限制；未声称网页版能登录真实服务。不要为绕过浏览器限制公开私人订阅地址。
- Apple 平台使用 SwiftUI，适应系统深浅色。iPhone 使用 Home / To Do / Chat / Assignments 四个系统标签，发帖位于原生工具栏；Mac 使用侧边栏与工具栏，聊天采用左右分栏。系统自带控件负责材质、焦点、弹窗和键盘行为。Android / Windows / Linux / Web 暂保留 Flutter Material 界面。
- 前台每 8 秒刷新。**Flutter 客户端尚未接入 APNs/后台通知注册**；原后端的 APNs 能力与源码仍保留。关闭 App 后不会由 Flutter 客户端收到新推送。
- 视频由跨平台 media_kit 播放；后端仍限制文件体积、时长和审核。没有新增视频转码流程。
- 真实学校邮箱发送、AI 审核、生产账号登录和私人作业订阅需要用户自己的账号完成；没有替用户发送验证码、发布帖子或修改生产数据。

## 源码结构

- `lib/main.dart`：启动、依赖初始化，以及 Apple 原生界面 / Flutter 界面的入口选择。
- `lib/src/native_bridge.dart`：SwiftUI 与 Dart 业务状态和操作之间的桥接。
- `apple/`：iPhone 与 Mac 的 SwiftUI 页面、原生媒体预览，以及原生界面操作测试。
- `macos/Runner/MainFlutterWindow.swift`、`ios/Runner/AppDelegate.swift`：保留 Flutter 引擎，同时承载 SwiftUI。
- `lib/src/api.dart`：原服务接口、会话请求和错误处理。
- `lib/src/store.dart`：账号、帖子、聊天、演示和管理员操作。
- `lib/src/planner.dart`：作业 Feed 的地址校验、iCalendar 解析、缓存和待办。
- `lib/src/photos.dart`：后台图片压缩。
- `lib/src/ui.dart`、`*_ui.dart`：页面、导航与交互。
- `backend/`：原 Python 后端与原测试，未修改协议。
- `docs/original-swiftui/`：保留的原 SwiftUI 文档，仅供溯源。其 Xcode 工程名和更新脚本步骤不适用于此 Flutter 项目。
- `docs/VERIFICATION.md`：本次迁移验证记录。

## 验证与本地后端

```sh
flutter analyze
flutter test
flutter test integration_test/smoke_test.dart -d macos
# 上面只测试保留的 Flutter 界面；Apple 原生界面使用 Xcode 的 CompassNativeUI 测试 Scheme。
```

`test/contract_test.dart` 默认跳过真实 HTTP 测试。可启动内存测试服务，再运行它。以下服务仅绑定本机，测试邮箱、审核器和数据均为虚构：

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r backend/requirements.txt
.venv/bin/python test/support/contract_server.py
# 在另一个终端
COMPASS_TEST_API=http://127.0.0.1:18764 flutter test test/contract_test.dart
```

后端单独测试：

```sh
cd backend
../.venv/bin/python -m unittest discover -q
```

Python 必须带 OpenSSL 的 `hashlib.scrypt`。这台 Mac 的系统 Python 缺少它，因此本次验证使用独立 Python 3.12 环境；没有改写密码算法。真实后端部署配置请参照原文档，并使用已有服务器配置，不要把服务端密钥放进 Flutter。

## 实现参考

- [Flutter / VS Code](https://docs.flutter.dev/tools/editors)
- [Flutter 网络请求与平台权限](https://docs.flutter.dev/cookbook/networking/fetch-data)
- [ChangeNotifier](https://api.flutter.dev/flutter/foundation/ChangeNotifier-class.html)
- [安全存储及 macOS 钥匙串配置](https://pub.dev/packages/flutter_secure_storage)
- [本地非敏感偏好存储](https://pub.dev/packages/shared_preferences)
- [文件选择器](https://pub.dev/packages/file_picker)
- [时区数据](https://pub.dev/packages/timezone)
- [图片处理](https://pub.dev/packages/image)
- [视频播放器](https://pub.dev/packages/media_kit)

## Apple 界面测试与调试

在 Xcode 打开 `ios/Runner.xcworkspace` 或 `macos/Runner.xcworkspace`，选择 **CompassNativeUI** Scheme 执行原生 UI 测试。测试使用 Demo，不访问真实学校账号或向别人发送消息。

原生界面与 Dart 的状态/操作契约测试：`flutter test test/native_bridge_test.dart`。

如需查看保留的纯 Flutter 界面，可运行 `flutter run -d macos --dart-define=FLUTTER_UI=true`。正常运行默认显示原生 Apple 界面。

原生界面参考：
- [Flutter 平台消息通信](https://docs.flutter.dev/platform-integration/platform-channels)
- [Apple NavigationSplitView](https://developer.apple.com/documentation/swiftui/navigationsplitview)
- [Apple TabView](https://developer.apple.com/documentation/swiftui/tabview)
- [Apple Liquid Glass](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)
