@Entry
@Component
struct HomePage {
  @Builder
  private entranceCard(icon: string, title: string, summary: string, route: string, color: ResourceColor) {
    Row({ space: 18 }) {
      Text(icon).fontSize(34).width(64).height(64).textAlign(TextAlign.Center)
        .backgroundColor(color).borderRadius(20)
      Column({ space: 6 }) {
        Text(title).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#172033')
        Text(summary).fontSize(14).fontColor('#667085').maxLines(2)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Text('›').fontSize(30).fontColor('#A1A8B3')
    }
    .width('100%').padding(18).backgroundColor('#FFFFFF').borderRadius(24)
    .onClick(() => this.getUIContext().getRouter().pushUrl({ url: route }))
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Column({ space: 8 }) {
          Text('映刻水印相机').fontSize(32).fontWeight(FontWeight.Bold).fontColor('#172033')
          Text('拍下，读懂，再创作。').fontSize(16).fontColor('#667085')
        }.width('100%').alignItems(HorizontalAlign.Start).margin({ bottom: 10 })

        this.entranceCard('📷', '相机', '原生预览、拍照与拍后水印', 'pages/CameraPage', '#E9EEFF')
        this.entranceCard('🖼️', '图片工具', '从相册选图并添加可调水印', 'pages/ToolsPage', '#E7F8F0')
        this.entranceCard('✨', 'AI 趣玩', '端侧识别能力将在后续阶段开放', 'pages/AiPlayPage', '#FFF2E1')

        Row({ space: 8 }) {
          Text('🔒').fontSize(16)
          Text('纯本地运行 · 不上传照片 · 不需要账号').fontSize(13).fontColor('#4F5A6D')
        }.width('100%').justifyContent(FlexAlign.Center).margin({ top: 12 })
      }.width('100%').padding({ left: 22, right: 22, top: 48, bottom: 32 })
    }.width('100%').height('100%').backgroundColor('#F5F7FB')
  }
}
