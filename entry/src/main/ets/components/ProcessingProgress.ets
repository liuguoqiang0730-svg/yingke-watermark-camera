@Component
export struct ProcessingProgress {
  @Prop message: string = '正在处理…';

  build() {
    Column({ space: 14 }) {
      LoadingProgress().width(40).height(40).color('#365CF5')
      Text(this.message).fontSize(15).fontColor('#172033')
    }
    .padding(24).backgroundColor('#F2FFFFFF').borderRadius(20)
    .shadow({ radius: 18, color: '#33000000', offsetX: 0, offsetY: 6 })
  }
}
