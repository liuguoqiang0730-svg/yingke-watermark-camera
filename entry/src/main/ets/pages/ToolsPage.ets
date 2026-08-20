import { BottomModuleSwitcher, HomeModule } from '../components/BottomModuleSwitcher';

@Entry
@Component
struct ToolsPage {
  @State private currentBreakpoint: string = 'xs';

  private isExpanded(): boolean {
    return this.currentBreakpoint === 'md';
  }

  private switchModule(module: HomeModule): void {
    if (module === HomeModule.TOOLS) {
      return;
    }
    const route = module === HomeModule.CAMERA ? 'pages/HomePage' : 'pages/AiPlayPage';
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

  private openCollage(): void {
    try {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/CollagePage' });
    } catch (_) {
      this.showToast('暂时无法打开多图拼接。');
    }
  }

  private openTextRecognition(): void {
    try {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/TextRecognitionPage' });
    } catch (_) {
      this.showToast('暂时无法打开文字识别。');
    }
  }

  private openSubjectSegmentation(): void {
    try {
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/SubjectSegmentationPage'
      });
    } catch (_) {
      this.showToast('暂时无法打开主体分割。');
    }
  }


  @Builder
  private header() {
    Row({ space: 14 }) {
      Image($r('app.media.foreground')).width(this.isExpanded() ? 58 : 52)
        .height(this.isExpanded() ? 58 : 52).borderRadius(16)
      Column({ space: 4 }) {
        Text('图片工具').fontSize(this.isExpanded() ? 27 : 24)
          .fontWeight(FontWeight.Bold).fontColor('#3B2117')
        Text('常用图片能力，一步快速处理').fontSize(14).fontColor('#A07A63')
      }.alignItems(HorizontalAlign.Start)
        .padding({ top: this.isExpanded() ? 13 : 10 })
      Blank()
    }.width('100%').alignItems(VerticalAlign.Top)
  }

  @Builder
  private featureCard(icon: string, title: string, description: string, available: boolean = false) {
    Row({ space: this.isExpanded() ? 22 : 14 }) {
      Text(icon).fontSize(this.isExpanded() ? 30 : 24)
        .fontWeight(FontWeight.Bold).fontColor('#F05A20')
        .width(this.isExpanded() ? 88 : 68).height(this.isExpanded() ? 88 : 68)
        .textAlign(TextAlign.Center).backgroundColor('#FFF0DE')
        .borderRadius(this.isExpanded() ? 24 : 19)
      Column({ space: this.isExpanded() ? 8 : 5 }) {
        Text(title).fontSize(this.isExpanded() ? 22 : 18)
          .fontWeight(FontWeight.Bold).fontColor('#3B2117')
        Text(description).fontSize(this.isExpanded() ? 15 : 13)
          .fontColor('#9B7761').maxLines(2)
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Row({ space: this.isExpanded() ? 14 : 8 }) {
        Text(available ? '立即使用' : '后续开放')
          .fontSize(this.isExpanded() ? 13 : 11).fontColor('#D55A28')
          .padding({
            left: this.isExpanded() ? 14 : 9,
            right: this.isExpanded() ? 14 : 9,
            top: 6,
            bottom: 6
          })
          .backgroundColor('#FFE7D2').borderRadius(16)
        Text('›').fontSize(this.isExpanded() ? 32 : 26).fontColor('#6F4C3A')
      }
    }
    .width('100%').height(this.isExpanded() ? 144 : 116)
    .padding({ left: this.isExpanded() ? 24 : 16, right: this.isExpanded() ? 24 : 16 })
    .backgroundColor('#FFFDF9').borderRadius(this.isExpanded() ? 26 : 22)
    .border({ width: 1, color: '#F2DCCB' })
    .shadow({ radius: 16, color: '#10000000', offsetY: 5 })
    .onClick(() => {
      if (available) {
        if (title === '多图拼接') {
          this.openCollage();
        } else if (title === '文字识别') {
          this.openTextRecognition();
        } else {
          this.openSubjectSegmentation();
        }
      }
    })
  }


  build() {
    Column() {
      Scroll() {
        Column({ space: 24 }) {
          this.header()
          GridRow({
            columns: 12,
            breakpoints: { value: ['600vp', '840vp'], reference: BreakpointsReference.WindowSize }
          }) {
            GridCol({ span: 12 }) {
              Column({ space: this.isExpanded() ? 18 : 14 }) {
                Text('选择一个工具').fontSize(this.isExpanded() ? 26 : 22)
                  .fontWeight(FontWeight.Bold).fontColor('#3B2117').width('100%')
                this.featureCard('▦', '多图拼接', '纵向、横向与网格拼图', true)
                this.featureCard('OCR', '文字识别', '端侧 OCR 与结果复制', true)
                this.featureCard('◉', '主体分割', '透明图片与背景替换', true)
              }.width('100%')
            }
          }
          .width('100%')
          .onBreakpointChange((breakpoint: string) => this.currentBreakpoint = breakpoint)
        }
        .width('100%').constraintSize({ maxWidth: 1480 }).justifyContent(FlexAlign.Start)
        .padding({
          left: this.isExpanded() ? 40 : 20,
          right: this.isExpanded() ? 40 : 20,
          top: this.isExpanded() ? 28 : 76,
          bottom: 24
        })
      }.width('100%').layoutWeight(1).align(Alignment.TopStart)

      BottomModuleSwitcher({
        selectedModule: HomeModule.TOOLS,
        onModuleChange: (module: HomeModule) => this.switchModule(module)
      })
        .width(this.isExpanded() ? 680 : '92%').constraintSize({ maxWidth: 680 })
        .margin({ top: 8, bottom: this.isExpanded() ? 16 : 10 })
    }.width('100%').height('100%').justifyContent(FlexAlign.Start).backgroundColor('#FFF8F0')
  }
}
