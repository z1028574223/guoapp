# 小果影视 · iOS 27 液态玻璃版

原生 SwiftUI 界面 + 复用 guoapp Go 核心的 iOS App 工程。界面用 iOS 26/27 的原生 Liquid Glass（`.glassEffect()`）渲染，不是 CSS 模拟。

## 为什么是这个架构

guoapp 的完整功能（站源脚本、网络、缓存、搜索、详情、播放地址解析、下载、弹幕、投屏）全在 Go 核心里，通过单个 C 函数 `DuanjuRequest(char*)` 暴露（JSON 进 / JSON 出）。本工程：

- **后端 100% 复用** Go 核心，Swift 直接调 C ABI；
- **界面用 SwiftUI 重写**，全部走原生液态玻璃材质；
- **播放用 AVPlayer** 替代 libmpv，地址由 Go 核心的 `resolve` 解析（含 HLS 改写、鉴权头、线路回退）。

这样既保住完整功能，又能用真正的 iOS 27 玻璃材质——这是 Flutter 做不到的（Flutter 只能自绘模拟）。

## 目录结构

```
GuoAppiOS27/
├─ project.yml                     XcodeGen 工程定义（部署目标 iOS 26）
├─ GuoAppiOS27/
│  ├─ GuoAppiOS27App.swift         入口 + 启动初始化
│  ├─ Core/
│  │  ├─ BridgingHeader.h          C ABI 声明
│  │  ├─ DuanjuCore.swift          Go 桥接（DuanjuRequest / DuanjuFree）
│  │  ├─ Repository.swift          业务 action 封装（对齐 Dart AppRepository）
│  │  ├─ LocalStore.swift          追剧/历史/设置（Go 核心不负责这部分）
│  │  └─ Glass.swift               液态玻璃材质封装 + token
│  ├─ Models/Models.swift          数据模型
│  ├─ Views/                       发现 / 追剧 / 我的 / 详情 / 播放
│  └─ Resources/                   演示用图片
└─ .github/workflows/build-ios.yml 云构建打包 IPA
```

## 打包 IPA（GitHub Actions）

**本机是 Windows，编译不了 iOS。** 打包链路已对齐监理 App（jianliapp）验证跑通的方式：`macos-latest` runner + XcodeGen + `xcodebuild build`（未签名）+ Payload zip。相比最初稿改了三处关键点：

- runner 从 `xcode-27` 改为 `macos-latest`（后者是实际跑出过 IPA 的编译环境，Xcode 26.6 + SDK 26.5）；
- 归档 `archive` 改为 `xcodebuild build -sdk iphoneos`，与跑通链路一致；
- Swift 语言版本 5.0 → 5.9，与跑通工程一致。

1. 把本目录推到你的一个 GitHub **私有仓库**（例如 `guoapp-ios27`）。
2. 在仓库的 Actions 页手动触发 **Build iOS 27 Liquid Glass IPA**（`workflow_dispatch`，只在手动时跑，避免烧 macOS runner 计费额度）。
3. 工作流会：
   - 自动选中机器上最新的 Xcode（要求 ≥26，提供 `glassEffect`）；
   - 拉取 Xanerix/guoapp 的 Go 核心源码，用 Go 1.26.10 编译出 `DuanjuCore.xcframework`；
   - 用 XcodeGen 生成工程，`xcodebuild build` 未签名编译；
   - 打包成未签名 IPA + 上传 build.log，作为 artifact 下载即可。

> 相比 jianliapp，本工程多一步 Go 核心静态库编译（站源/播放/下载都依赖它），这是唯一未经云端验证的环节。若该步报错，把 Actions 日志发我。

### 未签名 IPA 怎么装

未签名 IPA 不能直接点开安装，需侧载（altstore / Sideloadly / 爱思助手等），或用你自己的 Apple ID 签名后安装。部署目标 iOS 26+，低于 iOS 26 的系统装不了——液态玻璃材质无法向下兼容，这是硬性限制。

## 当前状态与已知限制

这是**第一阶段**：架构打通 + 五个核心界面 + 能打包。以下还没做（属于后续阶段）：

- 未安装真实站源模块时，界面显示的是**演示内容**（UI 里已明确标注）；装了模块后自动切真实数据。
- 下载、站源模块管理、多用户、备份恢复、投屏等界面尚未实现（Go 核心能力已就绪，只差 Swift 界面）。
- 弹幕只预留了 Go 侧数据接口，播放页未渲染弹幕。
- 图片素材是 Unsplash 免版权图，仅作演示。

**未在本机编译验证**：本机只有 Windows 版 Swift 6.4.1，无 iOS SDK，无法做 SwiftUI 类型检查。已通过的验证是：12 个 Swift 文件全部通过 `swiftc -frontend -parse` 语法解析；关键 iOS 26 API 签名已对照 Apple 官方文档核实。真正的编译结果以 GitHub Actions 为准。若 CI 报错，把日志发我，我逐个修。

## 需要你确认/配合

1. 提供或新建一个 GitHub 仓库放这个工程（我不能替你推送——按约定，代码改动等你明确说"同步到 git"才提交）。
2. 确认接受 iOS 26+ 的最低系统要求。
3. 侧载 IPA 的工具你这边是否已有。
