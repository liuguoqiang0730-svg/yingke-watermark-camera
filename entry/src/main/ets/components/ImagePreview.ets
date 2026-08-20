@Component
export struct ImagePreview {
  @Prop sourceUri: string = '';

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.sourceUri) {
        Image(this.sourceUri).width('100%').height('100%').objectFit(ImageFit.Contain)
      } else {
        Column({ space: 12 }) {
          LoadingProgress().width(36).height(36).color('#365CF5')
          Text('正在读取图片').fontSize(14).fontColor('#667085')
        }
      }
    }.width('100%').height('100%').backgroundColor('#11151D').borderRadius(20)
  }
}
