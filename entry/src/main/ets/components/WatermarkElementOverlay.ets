import { WatermarkElementType } from '../models/WatermarkTemplate';

@Component
export struct WatermarkElementOverlay {
  @Prop elementId: string = '';
  @Prop elementType: WatermarkElementType = WatermarkElementType.TEXT;
  @Prop text: string = '';
  @Prop imageUri: string = '';
  @Prop opacityValue: number = 0.88;
  @Prop sizeValue: number = 18;
  @Prop scaleFactor: number = 1;
  @Prop positionX: number = 0;
  @Prop positionY: number = 0;
  @Prop frameX: number = 0;
  @Prop frameY: number = 0;
  @Prop frameWidth: number = 0;
  @Prop frameHeight: number = 0;
  @Prop selected: boolean = false;
  @Prop editable: boolean = true;
  onSelect: (id: string) => void = () => {};
  onPositionChange: (id: string, x: number, y: number) => void = () => {};
  onScaleChange: (id: string, scale: number) => void = () => {};
  onEditRequest: (id: string) => void = () => {};

  @State private contentWidth: number = 120;
  @State private contentHeight: number = 48;
  @State private dragging: boolean = false;
  @State private dragOffsetX: number = 0;
  @State private dragOffsetY: number = 0;
  @State private pinching: boolean = false;
  @State private pinchGestureScale: number = 1;
  private dragStartX: number = 0;
  private dragStartY: number = 0;
  private pinchStartScale: number = 1;

  private clamp(value: number, min: number, max: number): number {
    return Math.min(max, Math.max(min, value));
  }

  private textMaxWidth(): number {
    return Math.max(120, this.frameWidth * 0.72);
  }

  private availableWidth(): number {
    return Math.max(1, this.frameWidth - this.contentWidth);
  }

  private availableHeight(): number {
    return Math.max(1, this.frameHeight - this.contentHeight);
  }

  private currentScale(): number {
    return this.pinching ?
      this.clamp(this.pinchStartScale * this.pinchGestureScale, 0.5, 2.5) : this.scaleFactor;
  }

  private currentX(): number {
    if (this.dragging) {
      return this.clamp(this.dragStartX + this.dragOffsetX,
        this.frameX, this.frameX + this.availableWidth());
    }
    return this.frameX + this.clamp(this.positionX, 0, 1) * this.availableWidth();
  }

  private currentY(): number {
    if (this.dragging) {
      return this.clamp(this.dragStartY + this.dragOffsetY,
        this.frameY, this.frameY + this.availableHeight());
    }
    return this.frameY + this.clamp(this.positionY, 0, 1) * this.availableHeight();
  }

  private updateDrag(offsetX: number, offsetY: number): void {
    if (!this.editable || !this.dragging) {
      return;
    }
    const targetX = this.clamp(this.dragStartX + offsetX,
      this.frameX, this.frameX + this.availableWidth());
    const targetY = this.clamp(this.dragStartY + offsetY,
      this.frameY, this.frameY + this.availableHeight());
    this.dragOffsetX = targetX - this.dragStartX;
    this.dragOffsetY = targetY - this.dragStartY;
  }

  private commitDrag(): void {
    if (!this.dragging) {
      return;
    }
    const x = this.clamp(this.currentX() - this.frameX, 0, this.availableWidth()) / this.availableWidth();
    const y = this.clamp(this.currentY() - this.frameY, 0, this.availableHeight()) / this.availableHeight();
    this.onPositionChange(this.elementId, x, y);
    this.dragging = false;
    this.dragOffsetX = 0;
    this.dragOffsetY = 0;
  }

  private cancelDrag(): void {
    this.dragging = false;
    this.dragOffsetX = 0;
    this.dragOffsetY = 0;
  }

  private updatePinch(gestureScale: number): void {
    if (!this.editable || !this.pinching) {
      return;
    }
    this.pinchGestureScale = gestureScale;
  }

  private commitPinch(): void {
    if (!this.pinching) {
      return;
    }
    const scale = this.currentScale();
    this.onScaleChange(this.elementId, scale);
    this.pinching = false;
    this.pinchGestureScale = 1;
  }

  private cancelPinch(): void {
    this.pinching = false;
    this.pinchGestureScale = 1;
  }

  @Builder
  private elementContent() {
    if (this.elementType === WatermarkElementType.IMAGE) {
      if (this.imageUri.length > 0) {
        Image(this.imageUri)
          .width(this.sizeValue * this.currentScale())
          .height(this.sizeValue * this.currentScale())
          .objectFit(ImageFit.Contain)
          .borderRadius(8)
      } else {
        Text('图片').fontSize(12).fontColor(Color.White)
          .width(this.sizeValue * this.currentScale())
          .height(this.sizeValue * this.currentScale())
          .textAlign(TextAlign.Center).backgroundColor('#99000000').borderRadius(8)
      }
    } else {
      Text(this.text.length > 0 ? this.text : '双击编辑文字')
        .fontSize(this.sizeValue * this.currentScale())
        .fontWeight(FontWeight.Bold).fontColor(Color.White)
        .constraintSize({ maxWidth: this.textMaxWidth() })
        .maxLines(6).textOverflow({ overflow: TextOverflow.Ellipsis })
        .padding({ left: 8, right: 8, top: 5, bottom: 5 })
        .backgroundColor('#8A1E1510').borderRadius(7)
        .textShadow({ radius: 2, color: '#66000000', offsetX: 0, offsetY: 1 })
    }
  }

  build() {
    Stack() {
      this.elementContent()
    }
    .opacity(this.opacityValue)
    .padding(4)
    .border({
      width: this.selected || this.dragging || this.pinching ? 2 : 1,
      color: this.selected || this.dragging || this.pinching ? '#FFF3A066' : '#99FFFFFF',
      radius: 10
    })
    .position({ x: this.currentX(), y: this.currentY() })
    .zIndex(10)
    .hitTestBehavior(HitTestMode.Block)
    .onAreaChange((_oldValue, newValue) => {
      this.contentWidth = Number(newValue.width);
      this.contentHeight = Number(newValue.height);
    })
    .onClick(() => this.onSelect(this.elementId))
    .priorityGesture(
      GestureGroup(GestureMode.Parallel,
        PanGesture({ fingers: 1, direction: PanDirection.All, distance: 1 })
          .onActionStart(() => {
            if (!this.editable) {
              return;
            }
            this.onSelect(this.elementId);
            this.dragStartX = this.currentX();
            this.dragStartY = this.currentY();
            this.dragOffsetX = 0;
            this.dragOffsetY = 0;
            this.dragging = true;
          })
          .onActionUpdate((event: GestureEvent) => this.updateDrag(event.offsetX, event.offsetY))
          .onActionEnd(() => this.commitDrag())
          .onActionCancel(() => this.cancelDrag()),
        PinchGesture({ fingers: 2, distance: 5 })
          .onActionStart(() => {
            if (!this.editable) {
              return;
            }
            this.onSelect(this.elementId);
            this.pinchStartScale = this.scaleFactor;
            this.pinchGestureScale = 1;
            this.pinching = true;
          })
          .onActionUpdate((event: GestureEvent) => this.updatePinch(event.scale))
          .onActionEnd(() => this.commitPinch())
          .onActionCancel(() => this.cancelPinch()),
        TapGesture({ count: 2 }).onAction(() => this.onEditRequest(this.elementId))
      )
    )
  }
}
