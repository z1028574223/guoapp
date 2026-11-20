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

## 功能覆盖

界面层用 SwiftUI 复刻了 guoapp 的完整能力，后端全部复用 Go 核心（单个 `DuanjuRequest` C 函数）：

- **内置真实站源**：打包时通过 `build_ios.py --bundle` 把 5 个非成人站源模块（红果、韩小圈、爱看机器人、青空、鬼片）编进 Go 核心，打开即有真实内容，离线可用。文件来自 guoapp 官方模块仓库，已校验 SHA256。
- **发现**：真实站源切换、分类、网络封面、下拉刷新。
- **搜索**：关键词搜索 + 联想 + 搜索历史（走 catalog query / suggestions）。
- **模块管理**：已安装 / 在线仓库两栏；从在线仓库安装（Go 核心自动下载校验）、卸载、域名权限确认弹框。在线仓库共 15 个站源。
- **下载**：批量选集下载、进度/状态、暂停继续移除、下载目录（enqueueDownloads / controlDownloads / downloads）。
- **多用户**：本地隔离追剧/历史/搜索/设置（Go 核心无用户概念，Swift 本地实现）。
- **追剧 / 观看记录**：有更新、按日期分段、搜索。
- **播放**：AVPlayer + 真实地址解析（Go 核心 HLS 改写/鉴权头）、倍速、选集、弹幕滚动渲染、投屏入口（iOS 上游未提供投屏，为预留）、玻璃播控浮层。
- **设置**：代理（自动/直连/手动）、缓存清理、存储统计、播放偏好、液态玻璃透明度。
- **iOS 27 液态玻璃**：全部界面用原生 `.glassEffect()`，含暗化边缘/高光/透明度无级滑块/滚动收缩胶囊导航。

Repository.swift 已封装 Go 核心全部 40+ action（ rankings/seasons/metadata/cover/preload/localPlayback/cast/sourceAccount 等均已接入或预留）。

### 已知限制

- **投屏**：guoapp 上游在 iOS 端不提供投屏，此功能仅为入口预留。
- **转码/备份恢复**：Go 核心有 beginConversion/finishConversion/deleteAllData 能力，Swift 侧未做完整 UI。
- **红果分季逻辑**（原 `hongguo_series.dart`）：分季聚合/新季提醒属本地纯逻辑，尚未在 Swift 复刻。
- 图片素材：真实站源封面走网络加载，失败回退内置占位图。

**编译验证**：本机只有 Windows 版 Swift 6.4.1，无 iOS SDK，只能做语法解析（全部 Swift 文件通过 `swiftc -frontend -parse`）。真正的类型检查/打包以 GitHub Actions 为准，CI 报错会据日志逐个修。

## 需要你确认/配合

1. 提供或新建一个 GitHub 仓库放这个工程（我不能替你推送——按约定，代码改动等你明确说"同步到 git"才提交）。
2. 确认接受 iOS 26+ 的最低系统要求。
3. 侧载 IPA 的工具你这边是否已有。
