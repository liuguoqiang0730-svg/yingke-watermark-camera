# MarkCamDemo：马克相机领域官方文档学习清单

> 仅学习工程水印相机相关领域，不包含 ArkTS、ArkUI、Stage 模型等通用入门内容。  
> 路线：`Camera Kit → 相机控制 → 水印合成 → 图库保存 → 定位地址 → 上传恢复`

## 第一阶段：Camera Kit 核心链路

现在只学这一阶段。目标是独立画出并实现“打开相机—预览—拍照—释放”的完整链路。

### 1. Camera Kit 简介

- 官方文档：[Camera Kit 简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-overview)
- 重点：`CameraManager`、`CameraInput`、`PhotoSession`、`PreviewOutput`、`PhotoOutput` 的职责。
- 学完标准：能画出 `CameraManager → CameraInput → PhotoSession → PreviewOutput + PhotoOutput`。

### 2. 开发相机应用必选能力（ArkTS）

- 官方文档：[开发相机应用必选能力](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-best-practices-arkts)
- 重点：初始化、`beginConfig()`、添加输入输出、`commitConfig()`、`start()`、`stop()`、资源释放。
- 学完标准：不用复制文档，写出完整调用链伪代码，并解释配置顺序为什么不能乱。

### 3. 相机管理、设备输入、会话管理

- [相机管理（ArkTS）](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-manager)
- [设备输入（ArkTS）](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-device-input)
- [会话管理（ArkTS）](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-session-management)
- 重点：查询前后摄像头、选择 Profile、创建并打开输入、创建会话、监听错误。
- 学完标准：能解释前后摄像头切换为什么通常需要重建输入或会话。

### 4. 相机预览（ArkTS）

- 官方文档：[预览（ArkTS）](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-preview)
- 重点：`XComponent/Surface`、Surface ID、Preview Profile、`PreviewOutput`、宽高比和旋转。
- 学完标准：能写出 Surface 创建到预览启动的事件顺序，并解释黑屏、拉伸和旋转异常的常见原因。

### 5. 拍照与拍照实践（ArkTS）

- [拍照（ArkTS）](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-shooting)
- [拍照实践（ArkTS）](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-shooting-case)
- 重点：`PhotoOutput`、拍照参数、方向、质量、`photoAvailable/captureEnd/error` 回调以及 JPEG/PixelMap 数据流。
- 学完标准：能画出“点击快门 → 获取图像 → 合成水印 → 编码 → 保存图库”的时序图。

### 6. 对焦、变焦、闪光灯与前后摄像头

- [对焦（ArkTS）](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-focus)
- [Camera Kit ArkTS API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-camera)
- 重点：任何控制功能先查询设备能力，再读取取值范围，最后设置。
- 学完标准：能设计 `supportsFlash`、`zoomRange`、`supportsFocusPoint` 三种能力状态，不能把设备能力写死。

### 7. 旋转、比例与坐标映射

- [适配相机旋转角度（ArkTS）](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-rotation-arkts)
- 重点：传感器方向、设备方向、预览方向、JPEG 方向、预览裁切和坐标映射。
- 学完标准：能解释为什么预览水印位置正确，保存后的水印仍可能偏移或旋转。

## 第二阶段：图片与真实水印合成

完成相机预览和拍照后再读。

### 8. PixelMap 位图操作

- [使用 PixelMap 完成位图操作](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/image-pixelmap-operation)
- 重点：像素格式、尺寸、密度、内存占用和像素读写。
- 用途：把拍照结果转换为可绘制、可编码的图像对象。

### 9. 离屏 Canvas/ArkGraphics 2D 绘制

- [画布的获取与绘制结果的显示（ArkTS）](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/canvas-get-result-draw-arkts)
- 重点：离屏画布、图片绘制、文字绘制、图形变换。
- 用途：把时间、地址、经纬度、项目名称、图标真正画到原图上。

### 10. ImagePacker 图片编码

- [Image Kit 图片开发指导](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/image-overview)
- 在目录中继续读：`图片编码 → 使用ImagePacker完成图片编码`。
- 重点：把合成后的 PixelMap 编码成 JPEG/PNG，控制格式、质量和输出位置。
- 注意：预览层显示一个水印组件不等于照片已经带水印。

## 第三阶段：保存、定位与工程业务

### 11. 保存照片到系统图库

- [保存媒体库资源](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/photoaccesshelper-savebutton)
- 重点：应用沙箱文件、媒体库 URI、安全控件/弹窗授权和保存流程。

### 12. 获取经纬度与地址

- [Location Kit 文档目录](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/location-overview)
- 依次读：`申请位置权限 → 获取设备位置信息（ArkTS） → 正地理编码与逆地理编码`。
- 重点：`getLastLocation()`、`getCurrentLocation()`、定位超时、精度、缓存、逆地理编码和失败降级。

### 13. 上传、断点续传和弱网恢复

- [Remote Communication Kit 文档目录](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/remote-communication-overview)
- 依次读：`文件上传下载 → 快速实现上传下载 → 暂停、恢复与断点续传`。
- [Background Tasks Kit 简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/background-task-overview)
- 重点：上传状态、进度、重试、断点、网络恢复和退后台后的系统约束。

## 当前学习顺序

只按以下顺序推进，不同时学习水印、定位和上传：

1. Camera Kit 简介。
2. 开发相机应用必选能力。
3. 相机管理、设备输入、会话管理。
4. 相机预览。
5. 拍照与拍照实践。

## 每读完一篇发给 AI

```text
我已经读完《文档标题》，正在开发 E:\Codex-AI-Coding\cameraDemo。

我理解的核心对象是：
我理解的调用顺序是：
我认为必须释放的资源是：
我不明白的地方是：
我的伪代码或流程图是：

请只围绕工程水印相机场景检查我的理解，纠正错误并追问我 3 个问题。不要给我通用 ArkTS/ArkUI 入门内容，也不要直接实现后续功能。
```