import { BottomModuleSwitcher, HomeModule } from '../components/BottomModuleSwitcher';
import { WatermarkPreset } from '../models/WatermarkTemplate';

@Entry
@Component
struct HomePage {
  @State private currentBreakpoint: string = 'xs';
  @State private selectedWatermark: WatermarkPreset = WatermarkPreset.CUSTOM;

  private isExpanded(): boolean {
    return this.currentBreakpoint === 'md';
  }

  private switchModule(module: HomeModule): void {
    if (module === HomeModule.CAMERA) {
      return;
    }
    const route = module === HomeModule.TOOLS ? 'pages/ToolsPage' : 'pages/AiPlayPage';
    try {
      this.getUIContext().getRouter().replaceUrl({ url: route });
    } catch (_) {
      this.showToast('暂时无法切换模块');
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (_) {
    }
  }

  private startCapture(): void {
    try {
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/CameraPage',
        params: { watermarkPreset: this.selectedWatermark, editorMode: true }
      });
    } catch (_) {
      this.showToast('暂时无法打开相机');
    }
  }

  private selectWatermark(preset: WatermarkPreset): void {
    this.selectedWatermark = preset;
  }
  @Builder
  private settingsGlyph() {
    Column({ space: 4 }) {
      Row() {
        Divider().width(22).strokeWidth(2).color('#725846')
        Circle().width(6).height(6).fill('#E96832').position({ x: 4, y: 0 })
      }.width(28).height(6)
      Row() {
        Divider().width(22).strokeWidth(2).color('#725846')
        Circle().width(6).height(6).fill('#E96832').position({ x: 16, y: 0 })
      }.width(28).height(6)
      Row() {
        Divider().width(22).strokeWidth(2).color('#725846')
        Circle().width(6).height(6).fill('#E96832').position({ x: 9, y: 0 })
      }.width(28).height(6)
    }.width(28)
  }
  @Builder
  private appHeader() {
    Row({ space: 14 }) {
      Image($r('app.media.foreground')).width(this.isExpanded() ? 58 : 52)
        .height(this.isExpanded() ? 58 : 52).borderRadius(16)
      Text('映刻水印相机').fontSize(this.isExpanded() ? 27 : 24)
        .fontWeight(FontWeight.Bold).fontColor('#3B2117')
      Blank()
      Button() {
        this.settingsGlyph()
      }
      .type(ButtonType.Circle).width(52).height(52).padding(0)
      .focusable(false).focusOnTouch(false)
      .border({ width: 2, color: '#D9AA83' })
      .backgroundColor('#FFF1E3').borderRadius(26)
      .onClick(() => this.getUIContext().getRouter().pushUrl({
        url: 'pages/CameraPage',
        params: { watermarkPreset: WatermarkPreset.CUSTOM, editorMode: true }
      }))
    }.width('100%')
  }

  @Builder
  private greeting() {
    Column({ space: 8 }) {
      Row({ space: 10 }) {
        Text('⌁').fontSize(26).fontColor('#F68A45')
        Text('今天，想怎么记录？').fontSize(this.isExpanded() ? 30 : 28)
          .fontWeight(FontWeight.Bold).fontColor('#3B2117')
      }
      Text('拍下此刻，让时间与地点留在画面里')
        .fontSize(this.isExpanded() ? 17 : 15).fontColor('#A07A63')
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private apertureGraphic() {
    Stack() {
      Circle().width(this.isExpanded() ? 176 : 126).height(this.isExpanded() ? 176 : 126)
        .fill(Color.Transparent).stroke('#45FFFFFF').strokeWidth(10)
      Circle().width(this.isExpanded() ? 128 : 92).height(this.isExpanded() ? 128 : 92)
        .fill(Color.Transparent).stroke('#E8FFFFFF').strokeWidth(5)
      Circle().width(this.isExpanded() ? 92 : 66).height(this.isExpanded() ? 92 : 66)
        .fill('#20FFFFFF').stroke(Color.White).strokeWidth(6)
      Circle().width(this.isExpanded() ? 24 : 18).height(this.isExpanded() ? 24 : 18)
        .fill(Color.White)
    }.width(this.isExpanded() ? 192 : 140).height(this.isExpanded() ? 192 : 140)
  }

  @Builder
  private quickCaptureCard() {
    Row({ space: this.isExpanded() ? 34 : 16 }) {
      this.apertureGraphic()
      Column({ space: this.isExpanded() ? 18 : 12 }) {
        Text('快速拍摄').fontSize(this.isExpanded() ? 34 : 27)
          .fontWeight(FontWeight.Bold).fontColor(Color.White)
        Text('打开相机，拍摄后立即添加水印').fontSize(this.isExpanded() ? 17 : 14)
          .fontColor('#F8FFFFFF').lineHeight(this.isExpanded() ? 25 : 21)
        Button('开始拍摄').height(this.isExpanded() ? 54 : 48)
          .padding({ left: 30, right: 30 }).fontSize(17).fontWeight(FontWeight.Bold)
          .fontColor('#E54A18').backgroundColor('#FFF9F2').borderRadius(26)
          .onClick(() => this.startCapture())
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }
    .width('100%').height(this.isExpanded() ? 356 : 260)
    .padding(this.isExpanded() ? 38 : 24)
    .linearGradient({ angle: 130, colors: [['#FF4F16', 0.0], ['#FF9844', 1.0]] })
    .borderRadius(28).shadow({ radius: 24, color: '#32E85B20', offsetY: 10 })
  }

  @Builder
  private quickActionCard(icon: string, title: string, subtitle: string, action: () => void) {
    Column({ space: 12 }) {
      Row() {
        Text(icon).fontSize(28).width(54).height(54).textAlign(TextAlign.Center)
          .backgroundColor('#FFF0DE').borderRadius(16)
        Blank()
        Text('›').fontSize(28).fontColor('#E65A25')
      }.width('100%')
      Text(title).fontSize(this.isExpanded() ? 20 : 17).fontWeight(FontWeight.Bold)
        .fontColor('#3B2117').width('100%')
      Text(subtitle).fontSize(14).fontColor('#A07A63').width('100%')
    }
    .layoutWeight(1).height(this.isExpanded() ? 150 : 142).padding(20)
    .alignItems(HorizontalAlign.Start).backgroundColor('#FFFDF9').borderRadius(24)
    .border({ width: 1, color: '#F2DCCB' })
    .onClick(action)
  }

  @Builder
  private watermarkPreset(preset: WatermarkPreset, icon: string, label: string) {
    Row({ space: 8 }) {
      Text(icon).fontSize(20).width(34).height(34).textAlign(TextAlign.Center)
        .backgroundColor(this.selectedWatermark === preset ? '#FFD7B3' : '#F3E7DA').borderRadius(17)
      Text(label).fontSize(this.isExpanded() ? 15 : 13).fontWeight(FontWeight.Medium)
        .fontColor('#4A3025').maxLines(1)
    }
    .layoutWeight(1).height(62).padding({ left: 8, right: 8 })
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.selectedWatermark === preset ? '#FFF0E2' : '#FFFDF9')
    .borderRadius(18).border({ width: 1, color: this.selectedWatermark === preset ? '#F5A36D' : '#EEDBCB' })
    .onClick(() => this.selectWatermark(preset))
  }

  @Builder
  private sidePanel() {
    Column({ space: 18 }) {
      Row({ space: 16 }) {
        this.quickActionCard('▧', '相册加水印', '选择已有照片', () => {
          this.getUIContext().getRouter().pushUrl({ url: 'pages/GalleryWatermarkPage' });
        })
        this.quickActionCard('◷', '最近作品', '查看本地记录', () => {
          this.showToast('最近作品将在保存首张照片后显示');
        })
      }.width('100%')

      Column({ space: 16 }) {
        Text('常用水印').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#3B2117').width('100%')
        Row({ space: 10 }) {
          this.watermarkPreset(WatermarkPreset.TIME_LOCATION, '●', '时间地点')
          this.watermarkPreset(WatermarkPreset.MINIMAL_DATE, '▣', '极简日期')
          this.watermarkPreset(WatermarkPreset.CUSTOM, '✎', '自定义')
        }.width('100%')
        Row({ space: 7 }) {
          Text('♙').fontSize(15).fontColor('#9A765F')
          Text('照片仅在本机处理').fontSize(13).fontColor('#9A765F')
        }.width('100%').justifyContent(FlexAlign.Center)
      }
      .width('100%').padding(20).backgroundColor('#FFFDF9').borderRadius(24)
      .border({ width: 1, color: '#F2DCCB' })
    }.width('100%')
  }

  @Builder
  private responsiveContent() {
    GridRow({
      columns: 12,
      gutter: 22,
      breakpoints: { value: ['600vp', '840vp'], reference: BreakpointsReference.WindowSize }
    }) {
      GridCol({ span: { xs: 12, sm: 12, md: 7 } }) {
        this.quickCaptureCard()
      }.padding({ bottom: this.isExpanded() ? 0 : 18 })
      GridCol({ span: { xs: 12, sm: 12, md: 5 } }) {
        this.sidePanel()
      }
    }
    .width('100%')
    .onBreakpointChange((breakpoint: string) => this.currentBreakpoint = breakpoint)
  }

  build() {
    Column() {
      Scroll() {
        Column({ space: this.isExpanded() ? 24 : 20 }) {
          this.appHeader()
          this.greeting()
          this.responsiveContent()
        }
        .width('100%').constraintSize({ maxWidth: 1520 })
        .padding({
          left: this.isExpanded() ? 40 : 20,
          right: this.isExpanded() ? 40 : 20,
          top: this.isExpanded() ? 28 : 22,
          bottom: 24
        })
      }.width('100%').layoutWeight(1)

      BottomModuleSwitcher({
        selectedModule: HomeModule.CAMERA,
        onModuleChange: (module: HomeModule) => this.switchModule(module)
      })
        .width(this.isExpanded() ? 680 : '92%')
        .constraintSize({ maxWidth: 680 })
        .margin({ top: 8, bottom: this.isExpanded() ? 16 : 10 })
    }
    .width('100%').height('100%').backgroundColor('#FFF8F0')
  }
}