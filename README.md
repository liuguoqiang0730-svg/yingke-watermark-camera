# 映刻水印相机

映刻水印相机是一款使用 HarmonyOS 原生 ArkTS/ArkUI 开发的本地水印相机。目前项目不依赖后端服务，聚焦相机拍摄、图库选图、图片处理、水印合成与本地保存等核心能力。

## 当前进度

- 已完成第一阶段应用骨架与主要页面：主页、相机、工具、AI 玩法占位页、结果页
- 已接入相机权限、相机预览与拍照流程
- 已实现图库选图、图片解码、方向纠正与压缩
- 已实现文字水印合成、处理进度、结果预览与保存到媒体库
- 当前 AI 玩法为纯本地占位入口，暂未接入后端

## 技术环境

- HarmonyOS SDK 6.1.0 / API 23
- ArkTS / ArkUI
- Stage 模型
- Hvigor 构建系统

## 构建

在已配置 HarmonyOS SDK 与 Node.js 的环境中执行：

```powershell
hvigorw.bat assembleHap --no-daemon
```

构建产物默认位于 `entry/build/default/outputs/default/`。本地 SDK 路径、依赖缓存、IDE 配置和构建产物不会提交到仓库。

## 文档

- [产品与技术开发文档](./映刻水印相机_产品与技术开发文档.md)
- [HarmonyOS 官方文档学习清单](./HarmonyOS官方文档学习清单.md)

