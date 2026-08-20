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
  @State private pinching: boolean = false;
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

  private currentX(): number {
    return this.frameX + this.clamp(this.positionX, 0, 1) * this.availableWidth();
  }

  private currentY(): number {
    return this.frameY + this.clamp(this.positionY, 0, 1) * this.availableHeight();
  }

  private moveTo(targetX: number, targetY: number): void {
    if (!this.editable) {
      return;
    }
    const x = this.clamp(targetX - this.frameX, 0, this.availableWidth()) / this.availableWidth();
    const y = this.clamp(targetY - this.frameY, 0, this.availableHeight()) / this.availableHeight();
    this.onPositionChange(this.elementId, x, y);
  }

  private resize(gestureScale: number): void {
    if (!this.editable) {
      return;
    }
    this.onScaleChange(this.elementId, this.clamp(this.pinchStartScale * gestureScale, 0.5, 2.5));
  }

  @Builder
  private elementContent() {
    if (this.elementType === WatermarkElementType.IMAGE) {
      if (this.imageUri.length > 0) {
        Image(this.imageUri)
          .width(this.sizeValue * this.scaleFactor)
          .height(this.sizeValue * this.scaleFactor)
          .objectFit(ImageFit.Contain)
          .borderRadius(8)
      } else {
        Text('图片').fontSize(12).fontColor(Color.White)
          .width(this.sizeValue * this.scaleFactor)
          .height(this.sizeValue * this.scaleFactor)
          .textAlign(TextAlign.Center).backgroundColor('#99000000').borderRadius(8)
      }
    } else {
      Text(this.text.length > 0 ? this.text : '双击编辑文字')
        .fontSize(this.sizeValue * this.scaleFactor)
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
    .onAreaChange((_oldValue, newValue) => {
      this.contentWidth = Number(newValue.width);
      this.contentHeight = Number(newValue.height);
    })
    .onClick(() => this.onSelect(this.elementId))
    .gesture(
      GestureGroup(GestureMode.Parallel,
        PanGesture({ fingers: 1, direction: PanDirection.All, distance: 1 })
          .onActionStart(() => {
            if (!this.editable) {
              return;
            }
            this.onSelect(this.elementId);
            this.dragging = true;
            this.dragStartX = this.currentX();
            this.dragStartY = this.currentY();
          })
          .onActionUpdate((event: GestureEvent) => {
            this.moveTo(this.dragStartX + event.offsetX, this.dragStartY + event.offsetY);
          })
          .onActionEnd(() => this.dragging = false)
          .onActionCancel(() => this.dragging = false),
        PinchGesture({ fingers: 2, distance: 5 })
          .onActionStart(() => {
            if (!this.editable) {
              return;
            }
            this.onSelect(this.elementId);
            this.pinching = true;
            this.pinchStartScale = this.scaleFactor;
          })
          .onActionUpdate((event: GestureEvent) => this.resize(event.scale))
          .onActionEnd(() => this.pinching = false)
          .onActionCancel(() => this.pinching = false),
        TapGesture({ count: 2 }).onAction(() => this.onEditRequest(this.elementId))
      )
    )
  }
}
