@Entry
@Component
struct AiPlayPage {
  build() {
    Column({ space: 20 }) {
      Row() {
        Button('‹').type(ButtonType.Normal).onClick(() => this.getUIContext().getRouter().back())
        Text('AI 趣玩').fontSize(24).fontWeight(FontWeight.Bold)
          .layoutWeight(1).textAlign(TextAlign.Center)
        Blank().width(52)
      }.width('100%')
      Text('AI 结果仅供娱乐').fontSize(20).fontWeight(FontWeight.Bold)
      Text('人脸相似度与多目标识别将在阶段 3 接入 Core Vision Kit。')
        .fontSize(15).fontColor('#667085').textAlign(TextAlign.Center)
    }.width('100%').height('100%').padding(24).backgroundColor('#F5F7FB')
  }
}
