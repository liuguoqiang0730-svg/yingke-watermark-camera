@Component
export struct DraggableWatermarkOverlay {
  @Prop text: string = '';
  @Prop showText: boolean = true;
  @Prop showLogo: boolean = true;
  @Prop watermarkOpacity: number = 0.8;
  @Prop textSize: number = 16;
  @Prop logoSize: number = 64;
  @Prop scaleFactor: number = 1;
  @Prop positionX: number = 0.82;
  @Prop positionY: number = 0.76;
  @Prop frameX: number = 0;
  @Prop frameY: number = 0;
  @Prop frameWidth: number = 0;
  @Prop frameHeight: number = 0;
  onPositionChange: (x: number, y: number) => void = () => {};
  onScaleChange: (scale: number) => void = () => {};
  onEditRequest: () => void = () => {};

  @State private watermarkWidth: number = 180;
  @State private watermarkHeight: number = 100;
  @State private dragging: boolean = false;
  @State private pinching: boolean = false;
  private dragStartX: number = 0;
  private dragStartY: number = 0;
  private pinchStartScale: number = 1;

  private clamp(value: number, min: number, max: number): number {
    return Math.min(max, Math.max(min, value));
  }

  private availableWidth(): number {
    return Math.max(1, this.frameWidth - this.watermarkWidth);
  }

  private availableHeight(): number {
    return Math.max(1, this.frameHeight - this.watermarkHeight);
  }

  private currentX(): number {
    return this.frameX + this.clamp(this.positionX, 0, 1) * this.availableWidth();
  }

  private currentY(): number {
    return this.frameY + this.clamp(this.positionY, 0, 1) * this.availableHeight();
  }

  private updatePosition(targetX: number, targetY: number): void {
    const x = this.clamp(targetX - this.frameX, 0, this.availableWidth()) / this.availableWidth();
    const y = this.clamp(targetY - this.frameY, 0, this.availableHeight()) / this.availableHeight();
    this.onPositionChange(x, y);
  }

  private maxScale(): number {
    const widthScale = this.scaleFactor * this.frameWidth / Math.max(1, this.watermarkWidth);
    const heightScale = this.scaleFactor * this.frameHeight / Math.max(1, this.watermarkHeight);
    return Math.max(0.5, Math.min(2.5, widthScale, heightScale));
  }

  private updateScale(gestureScale: number): void {
    this.onScaleChange(this.clamp(this.pinchStartScale * gestureScale, 0.5, this.maxScale()));
  }

  build() {
    Column({ space: 5 }) {
      if (this.showLogo) {
        Image($r('app.media.startIcon'))
          .width(this.logoSize * this.scaleFactor).height(this.logoSize * this.scaleFactor)
          .borderRadius(this.logoSize * this.scaleFactor * 0.22)
      }
      if (this.showText && this.text.length > 0) {
        Text(this.text).fontSize(this.textSize * this.scaleFactor)
          .fontWeight(FontWeight.Bold).fontColor(Color.White)
          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          .padding({ left: 8, right: 8, top: 5, bottom: 5 })
          .backgroundColor('#99000000').borderRadius(6)
      }
    }
    .opacity(this.watermarkOpacity)
    .padding(5)
    .border({
      width: this.dragging || this.pinching ? 2 : 1,
      color: this.dragging || this.pinching ? '#FFF0A45D' : '#CCFFFFFF',
      radius: 10
    })
    .position({ x: this.currentX(), y: this.currentY() })
    .onAreaChange((_oldValue, newValue) => {
      this.watermarkWidth = Number(newValue.width);
      this.watermarkHeight = Number(newValue.height);
    })
    .gesture(
      GestureGroup(GestureMode.Parallel,
        PanGesture({ fingers: 1, direction: PanDirection.All, distance: 1 })
          .onActionStart(() => {
            this.dragging = true;
            this.dragStartX = this.currentX();
            this.dragStartY = this.currentY();
          })
          .onActionUpdate((event: GestureEvent) => {
            this.updatePosition(this.dragStartX + event.offsetX, this.dragStartY + event.offsetY);
          })
          .onActionEnd(() => this.dragging = false)
          .onActionCancel(() => this.dragging = false),
        PinchGesture({ fingers: 2, distance: 5 })
          .onActionStart(() => {
            this.pinching = true;
            this.pinchStartScale = this.scaleFactor;
          })
          .onActionUpdate((event: GestureEvent) => this.updateScale(event.scale))
          .onActionEnd(() => this.pinching = false)
          .onActionCancel(() => this.pinching = false),
        TapGesture({ count: 2 })
          .onAction(() => this.onEditRequest())
      )
    )
  }
}
