# 迁移验证记录 · 2026-10-14

## 原生界面改版验证

Apple 平台默认使用 SwiftUI 界面，Flutter 负责业务逻辑和数据。以下是改版后的结果；后面的初次迁移记录作为历史参考。

- Dart：`flutter analyze` 通过；桥接和业务测试共 6 项通过。
- Mac：原生 Debug 和 Release 均构建成功，Release 106.7 MB，已打开确认可进入原生首页；实际打开系统侧边栏和聊天分栏，发送本地演示消息后会话更新。
- iPhone：模拟器构建成功；实际打开系统标签栏和发帖表单，输入并提交演示帖子后首页出现新帖。
- 原生 XCTest：首次运行发现 Flutter 容器遮挡系统辅助功能的问题；已将 SwiftUI 提升为窗口根界面并手动复核。修正后未重新完成整套 XCTest，不计为自动测试通过。
- 尚未安装用户真机；没有执行学校生产环境发帖或发送消息。

预览：`previews/iphone-native-home.jpg`。原 Flutter 集成测试只覆盖备用 Flutter 界面。

## 初次 Flutter 迁移记录


环境：本机 Apple Silicon Mac，macOS 27.0，Flutter 3.47.7 / Dart 3.13.5，Xcode 27.0。源项目为下载文件夹的 Community APP v1.0。没有修改原下载目录。

| 检查 | 结果 | 覆盖和边界 |
|---|---|---|
| `flutter analyze` | 通过，无问题 | Dart 全项目检查 |
| Flutter 测试（启用本地 HTTP fixture） | 5 项全部通过 | URL 校验、日历日期/时区/修订/取消/折行、图片格式和大小、390 像素手机布局、演示发帖/回复/聊天/重开、真实 HTTP 接口兼容性 |
| Mac 集成测试 | 1 项全部通过 | 实际 Mac App 中系统钥匙串读写/删除、演示入口、首页/聊天切换、发送消息、打开编辑器、发布帖子、个人资料导航 |
| 原 Python 后端测试 | 80 项，79 通过、1 跳过 | 跳过项依赖未配置的视频工具；APNs 测试使用虚构响应，不发送真实通知 |
| macOS Debug / Release | 构建成功 | Release 约 100 MB，供本机运行；不是已公证的分发包 |
| iOS 模拟器 Debug | 构建成功 | 尚未在用户真机上安装或进行 iPhone 上的操作验证 |
| 原线上服务 `/health` | `{"ok": true}` | 只检查公开健康接口，没有登录、发验证码或写入学校数据 |
| VS Code | 已打开正确目录 | Dart/Flutter 插件已安装，Mac 启动配置已生成；当前工作区信任需要用户在编辑器里确认 |
| Android / Windows / Linux | 未构建 | Android 缺 SDK；Windows/Linux 未在对应系统测试 |
| Web 真实服务 | 未验证 | 原后端未提供 CORS；Web 定位为演示，私人 Feed 不在浏览器中连接 |

## 如何复核

`flutter test` 默认跳过 HTTP fixture 测试。启动 `test/support/contract_server.py` 后，用 `COMPASS_TEST_API=http://127.0.0.1:18764 flutter test` 可复核包含它的全部 5 项测试。

Mac 操作测试：`flutter test integration_test/smoke_test.dart -d macos`。测试只使用本地虚构演示数据，并通过唯一的临时钥匙串条目验证安全存储，结束后删除该条目。

原后端源码没有改写。系统 Python 缺少 `hashlib.scrypt`，因此原测试在单独的带 OpenSSL 的 Python 3.12 环境中运行，安装了 `backend/requirements.txt` 中的依赖。

## 构建警告

- media_kit 的 Apple 插件仍通过 CocoaPods 集成，尚未支持 Swift Package Manager；Flutter 当前版本可构建，CocoaPods 已安装。
- Xcode 输出 media_kit 头文件宏/所有权声明警告，以及本机 MetalToolchain 的旧路径警告；本次 Mac Debug/Release 与 iOS 模拟器构建均成功。

## 明确保留的边界

- 原 SwiftUI 的本机草稿、收藏、待办和登录会话没有自动复制到 Flutter，真实服务器数据通过重新登录读取。
- 备用 Flutter UI 不包含原生 Liquid Glass；Apple 默认 SwiftUI 界面已使用系统导航与玻璃效果。APNs/后台推送尚未接入。
- 未执行生产环境发帖、群消息、管理员操作或私人日历订阅同步。相关联网行为在内存本地测试服务验证，真实账号/邮箱/Feed 需要用户自己的授权和输入。
