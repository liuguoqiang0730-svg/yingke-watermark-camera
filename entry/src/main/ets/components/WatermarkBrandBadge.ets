@Component
export struct WatermarkBrandBadge {
  @Prop iconSize: number = 24;
  @Prop badgeWidth: number = 92;
  @Prop badgeHeight: number = 62;
  @Prop opacityValue: number = 0.78;
  @Prop labelSizeValue: number = 0;
  @Prop paddingValue: number = 6;
  @Prop gapValue: number = 4;

  private labelSize(): number {
    return this.labelSizeValue > 0 ? this.labelSizeValue :
      Math.max(9, Math.min(12, this.iconSize * 0.38));
  }

  build() {
    Column({ space: this.gapValue }) {
      Image($r('app.media.startIcon'))
        .width(this.iconSize)
        .height(this.iconSize)
        .borderRadius(this.iconSize * 0.22)
      Text($r('app.string.EntryAbility_label'))
        .fontSize(this.labelSize())
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .maxLines(1)
    }
    .width(this.badgeWidth)
    .height(this.badgeHeight)
    .padding(this.paddingValue)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#9E38281F')
    .borderRadius(Math.min(12, this.badgeHeight * 0.2))
    .border({ width: 1, color: '#55FFFFFF', radius: Math.min(12, this.badgeHeight * 0.2) })
    .opacity(this.opacityValue)
  }
}