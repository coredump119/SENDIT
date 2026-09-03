# SENDIT

微信「扣号」分发助手：把一批编号图片 + 一段群聊记录，变成按人拆好的文件夹 / 相册分组。

发送仍走微信本身，工具不碰微信客户端。**纯本地，零网络。**

## 能做什么

1. 导入编号图片（拖文件夹 / 选文件 / 从相册多选）
2. 粘贴微信群聊「多选 → 复制」的文本
3. 按先到先得 + 每人限量 + 作者自留，算出每个编号归谁
4. 支持取消、换号、待确认、手动改归属、多轮补发
5. 导出：
   - **macOS**：按人拆成子文件夹，可直接在 Finder 里发给微信
   - **iOS / Android**：一人一卡，保存原图到相册后再在微信里选图发送
   - **Web**：打包 ZIP 下载（方便 Windows 等环境）

## 平台

| 平台 | 状态 |
|------|------|
| macOS | 桌面版 |
| iOS / Android | 手机版 |
| Web | 浏览器版（ZIP 导出） |

在线试用（Web）：https://sendit-73d.pages.dev

## 快速开始

需要本机已安装 [Flutter](https://docs.flutter.dev/get-started/install)（建议 3.x）。

```bash
git clone https://github.com/coredump119/SENDIT.git
cd SENDIT
flutter pub get
flutter test                 # 核心引擎单测
flutter run -d macos         # 桌面
flutter run                  # 连着的手机 / 模拟器
flutter run -d chrome        # 网页
```

Release 构建示例：

```bash
flutter build macos --release
flutter build apk --release
flutter build ipa --release
flutter build web --release
```

## 怎么用

1. **图片**：拖入或选择编号好的图片（如 `001.png` …）；也可按顺序自动编号，并拖动缩略图调整。
2. **聊天**：从微信多选消息复制，粘贴进 App，点解析；可设起点、每人限量、作者自留。
3. **归属**：核对网格，点编号可改人；处理待确认项。
4. **拆分 / 导出**：选输出目录，或保存到相册，或下载 ZIP；可复制「分配公告」贴回群里。

示例聊天文本见 [`samples/chat_sample.txt`](samples/chat_sample.txt)。

## 隐私

- 不联网、不上传、不需要账号。
- macOS 沙盒仅申请「用户选择的文件」读写，不申请网络权限。
- Android 主清单不申请 `INTERNET`。
- 示例与测试仅使用虚构昵称。

## 项目结构

```
lib/
  core/       # 解析、编号、分配、报告（纯 Dart，可单测）
  platform/   # 桌面 / 手机 / Web 平台差异
  ui/         # 界面与状态
samples/      # 示例聊天文本与演示图
test/         # 单测与 golden
```

## 贡献

Issue / PR 欢迎。改核心逻辑时请先跑：

```bash
flutter test
```

## License

[MIT](LICENSE)
