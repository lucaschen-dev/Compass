# Community v1.0 — 账户、聊天及帖子管理更新

手机桌面名称和提示标题为 **Community**；项目正式名称仍为 **The Buckley School Community Program**。图标为红底白色学校标志。内部 Commons 项目名、Bundle ID、签名设置和钥匙串标识保留。

## 此次新增：Administrator

按你确认的“自己是第一个注册用户”，本版 `Update-Server.command` 会在更新时把数据库中最早保存的已验证账号设为 **Administrator**。这一步只能从服务器命令行执行，App 用户不能自行申请或修改角色。脚本重复运行不会新增管理员。

### 在 Mac 上更新服务器

1. 下载并解压本次 ZIP，打开里面的 `Commons` 文件夹。
2. 打开 Mac 的 **Terminal（终端）**。
3. 输入 `bash `，注意末尾有一个空格。
4. 把 **这个新包里的 `Update-Server.command`** 拖进终端，按回车。
5. 等待安装完成。输出应同时包括：
   - `Administrator: 你的学校邮箱 (用户名)`
   - `Community backend is running`
6. 再运行 **Update-Existing.command**，选择原来的 Xcode 项目文件夹。回 Xcode，选手机，按 **Command+R**。
7. 第一次升级若出现设置密码流程，先完成它。登录后在 **Home → Administrator** 或 **个人资料 → Administrator** 进入管理页。

只有下载 ZIP 不会更新远程服务器。本次聊天环境没有你的 Mac SSH 私钥，以上步骤需要在保存该密钥的 Mac 上运行。

若看到 `SSH key not found`，服务器没有被更新。先检查之前连接服务器用的密钥是否为 `~/.ssh/compass_server`；如果你用的是其他文件，在脚本顶部修改 `SSH_KEY` 为原来的密钥路径。不要重新生成或把私钥发给别人。

若首次 SSH 询问是否信任主机，先与 DigitalOcean 控制台确认这是你之前的服务器；不要忽略主机密钥变更警告。若脚本报错，保留终端中的报错信息。

### 管理功能

- **Posts**：分页查看所有现存帖子，包括匿名、分组、待审核和已拒绝帖子；按标题、内容、作者或学校邮箱搜索。
- 管理详情显示真实作者、学校邮箱、年级。普通 Home/帖子接口继续隐藏匿名作者身份；匿名开关旁已说明管理员可识别作者。
- 可发布/拒绝待审核帖子、删除任何帖子和评论。删除帖子会同时删除其评论及附件。
- **Reports**：查看举报人、举报理由、关联帖子；筛选 Open / Resolved / All；填写处理备注，Dismiss 或 Delete post & resolve。
- 删除帖子后，举报仍有处理记录；被举报者自己删帖也不能悄悄清除未处理举报。举报原因和处理记录按 30 天清理，不复制已删除帖子的正文。已过期/删除的帖子不会被恢复。
- Home 显示未处理举报数量；App 在前台同步时更新。已配置 APNs 的管理员手机会收到新举报提醒，点击打开管理页。未配置 APNs 时仍可在管理页查看全部现存举报。
- 管理员权限每次请求都由服务器检查；管理操作记录操作者、对象和时间。

本次权限用于帖子/评论和举报管理，没有开放读取其他人的私聊。

需要按具体邮箱调整时，仅在服务器终端执行（替换邮箱，不保留尖括号）：
```bash
/opt/compass/.venv/bin/python /opt/compass/admin.py --db /var/lib/compass/commons.sqlite role 你的邮箱@buckley.org Administrator
```
通常无需手动执行：新版更新脚本已经包含首次账号设置。若已经存在另一个管理员，自动设置会停止，不会擅自替换。

## 原有功能的安装说明：先后台，再 App

1. 解压完整更新包。不要删除原 Xcode 项目，也不要卸载手机里的 App。
2. 在 Mac 上双击 **Update-Server.command**。它使用已有的 `~/.ssh/compass_server`，连接 `165.227.31.227`，更新 `/opt/compass/server.py`，安装依赖及视频处理工具 ffmpeg，然后重启 `compass` 服务。
   - 如果 macOS 阻止脚本：打开 Terminal，输入 `bash `，把脚本拖进去，按回车。
   - 邮箱、OpenAI 密钥、数据库路径和 COMMONS_SECRET 保持原值。邮件发件人改成 `Community <login@buckley.community>`。
   - 不会把你本地测试数据库上传到线上。数据库新增表，不会重建用户账号。
   - **启动后启用 30 天清理**，已超过期限的普通帖子和聊天会删除，不能恢复。只备份旧服务代码，不另存包含已删除内容的数据库副本。已有云快照或其他人为备份不会被此脚本删除。
3. 双击 **Update-Existing.command**，选择你原来的 Commons 项目文件夹（包含 Commons.xcodeproj），不要选择刚下载的包。
4. 回原来的 Xcode，选 iPhone，按 Command+R。不要重新生成项目，不用重设 Team。
5. 老账号第一次升级使用 **Sign up / Reset password**：输入邮箱前缀 → 邮箱验证码 → 设置至少 10 位密码。原来的帖子、聊天和资料仍属于同一账号。未填写姓名/年级的账号会接着设置资料。
6. 此后可直接用邮箱前缀和密码登录。忘记密码用同一邮件验证入口。

如果 SSH 连接失败，在 Mac Terminal 手动检查：
```bash
ssh -i ~/.ssh/compass_server root@165.227.31.227
```
服务器检查：
```bash
systemctl status compass --no-pager
journalctl -u compass -n 40 --no-pager
curl -fsS https://api.buckley.community/health
```
不要把 `/etc/compass.env` 或密钥完整内容发到聊天里。

## 本次功能

- 启动先恢复会话，不闪出未登录主页；断网时显示重试入口。
- 注册：邮箱验证 → 密码 → 用户名和年级。密码以独立随机盐的 scrypt 摘要存储；重设密码撤销其他会话。
- 提示名称 Community；发送按钮大小固定，加载与文字互斥；发送成功清空输入并关闭键盘，失败保留草稿。
- Home → **My posts**：管理自己已发布和审核中的帖子，切换匿名、删除。匿名作者身份不会返回给其他账号。
- 自己的评论可删除；删帖连同评论、图片、举报记录一起清除。
- 私聊和群聊支持图片、视频、emoji。长按消息 → Reply / Unsend。撤回限服务器记录的发送后两分钟内；不会抹去接收者已看过或自行保存的内容。
- 图片会压缩和去除元数据；视频在手机导出为 720p MP4，限 60 秒、15 MB。选择附件后点发送才发送。
- 视频最多 150 MB 的源文件可进入本地压缩；每账号每天约 150 MB 上传上限、保留媒体约 250 MB 上限，全站聊天媒体约 10 GB 上限，保护现有小服务器。
- 图片由现有图片审核检查；视频检查 5 个抽样画面，**不等于完整视频/音频审核**。这些检查使用现有审核提供商配置。
- 普通帖子、评论和聊天消息保留 **30 天**。Important/Urgent 按服务器审核通过的优先级保留帖子；关联照片随帖子保留。聊天附件随消息删除。清理在服务启动、定时任务和请求入口运行，正常运行时最多约 5 分钟延迟。To Do 和 Assignment 不受影响。
- 手机上的聊天视频临时文件在离开视图、退出登录或下次启动时清理；线上帖子和聊天正文不建立长期离线数据库。

## 手机通知：还需要 Apple 配置

代码已接入通知授权、APNs token 注册、发送队列、重试、点击通知进入对应聊天。**没有 Apple 配置不会收到后台通知**；前台仍能刷新聊天。APNs 接受请求也不保证每一条一定送达，系统网络、专注模式、用户通知设置均会影响显示。

1. 在原 Xcode 项目，选 App target → **Signing & Capabilities → + Capability → Push Notifications**。使用有此能力的 Apple Developer Team。不要改 Bundle Identifier。
2. 到 Apple Developer → Certificates, Identifiers & Profiles → Keys，创建启用 APNs 的 key。保留 Key ID、Team ID 和下载的 `.p8` 文件。**不要将 `.p8` 或密钥发给我。**
3. 将 `.p8` 从 Mac 上传到服务器，下面路径替换成你实际下载的文件：
```bash
scp -i ~/.ssh/compass_server /实际路径/AuthKey_你的KeyID.p8 root@165.227.31.227:/root/community-apns.p8
ssh -i ~/.ssh/compass_server root@165.227.31.227
```
4. 在服务器安装到服务可读的私有目录：
```bash
install -d -o compass -g compass -m 700 /var/lib/compass/keys
install -o compass -g compass -m 600 /root/community-apns.p8 /var/lib/compass/keys/apns.p8
rm /root/community-apns.p8
nano /etc/compass.env
```
在原配置末尾添加四行，用你自己的值替换尖括号：
```dotenv
APNS_KEY_PATH=/var/lib/compass/keys/apns.p8
APNS_KEY_ID=<Apple Key ID>
APNS_TEAM_ID=<Apple Team ID>
APNS_TOPIC=<Xcode 中原来的 Bundle Identifier>
```
保存后：
```bash
systemctl restart compass
```
5. Xcode 正常 Debug 真机安装使用 sandbox；Release/TestFlight 使用 production。当前代码按 DEBUG 编译条件选择，如果你的自定义签名方式不同，需要同步调整 `CommunityAppDelegate.pushEnvironment`。
6. 重新安装运行，登录后允许通知。用第二个真实账号给第一台锁屏手机发消息；检查横幅、声音，再点击进入对应对话。若未收到，检查 iPhone Settings → Notifications → Community、Apple capability/描述文件、Key/Team/Topic，及服务日志 APNs 状态码。

只需要 Push Notifications capability。本版发送普通提示通知，不要求开启后台静默推送模式。更新器不会覆盖你添加的 capability 或签名设置。

## 验证范围与真机检查

`Test-Backend.command` 运行隔离数据的本地测试，邮箱及 AI 为模拟提供商，不会操作线上数据。视频测试在装有 ffmpeg 时运行。Apple 推送测试是接口模拟，不是实际送达测试。

这次提供源码包，未在此环境执行 Xcode 编译或 iPhone UI 测试。安装后依次检查：
1. 杀掉 App 再打开；断网重开后点重试。
2. 新邮箱验证后设置密码和年级；退出后用密码登录；重设密码后旧设备会话失效。
3. 发布/评论/聊天时反复点击不会重复提交；成功清空输入、键盘收起；失败保留文字。
4. 两个真实账号验证匿名切换、仅能删除自己的内容、两分钟内外撤回。
5. 私聊与群聊分别发送照片、短视频、emoji，长按回复。
6. 配置 Apple 后进行锁屏通知和通知跳转测试。

学校标志沿用现有素材，此次红底图标通过图像编辑生成并导出为 1024×1024。应用正式发布前仍需在真机确认显示及校方对名称/标志的使用安排。
