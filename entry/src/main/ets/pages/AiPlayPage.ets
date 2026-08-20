import { BottomModuleSwitcher, HomeModule } from '../components/BottomModuleSwitcher';

@Entry
@Component
struct AiPlayPage {
  @State private currentBreakpoint: string = 'xs';

  private isExpanded(): boolean {
    return this.currentBreakpoint === 'md';
  }

  private switchModule(module: HomeModule): void {
    if (module === HomeModule.AI) {
      return;
    }
    const route = module === HomeModule.CAMERA ? 'pages/HomePage' : 'pages/ToolsPage';
    try {
      this.getUIContext().getRouter().replaceUrl({ url: route });
    } catch (_) {
    }
  }

  @Builder
  private header() {
    Row({ space: 14 }) {
      Image($r('app.media.foreground')).width(this.isExpanded() ? 58 : 52)
        .height(this.isExpanded() ? 58 : 52).borderRadius(16)
      Column({ space: 4 }) {
        Text('AI 玩法').fontSize(this.isExpanded() ? 27 : 24)
          .fontWeight(FontWeight.Bold).fontColor('#3B2117')
        Text('有趣能力，全部在设备端完成').fontSize(14).fontColor('#A07A63')
      }.alignItems(HorizontalAlign.Start)
        .padding({ top: this.isExpanded() ? 13 : 10 })
      Blank()
    }.width('100%').alignItems(VerticalAlign.Top)
  }

  @Builder
  private featureCard(icon: string, title: string, description: string) {
    Row({ space: this.isExpanded() ? 22 : 14 }) {
      Text(icon).fontSize(this.isExpanded() ? 34 : 28).fontColor('#F05A20')
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
        Text('后续开放').fontSize(this.isExpanded() ? 13 : 11).fontColor('#D55A28')
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
  }

  build() {
    Column() {
      Scroll() {
        Column({ space: 24 }) {
          this.header()
          Column({ space: 10 }) {
            Text('让照片多一点想象力').fontSize(this.isExpanded() ? 32 : 27)
              .fontWeight(FontWeight.Bold).fontColor('#3B2117')
            Text('AI 结果仅供娱乐，请勿作为专业判断依据。')
              .fontSize(15).fontColor('#9B7761')
              .textAlign(this.isExpanded() ? TextAlign.Start : TextAlign.Center)
          }.width('100%').alignItems(this.isExpanded() ? HorizontalAlign.Start : HorizontalAlign.Center)

          GridRow({
            columns: 12,
            breakpoints: { value: ['600vp', '840vp'], reference: BreakpointsReference.WindowSize }
          }) {
            GridCol({ span: 12 }) {
              Column({ space: this.isExpanded() ? 18 : 14 }) {
                this.featureCard('☺', '相似度趣测', '选择照片，体验轻松有趣的端侧分析')
                this.featureCard('▧', '画面识别', '识别照片中的人物、景物与常见物体')
                this.featureCard('◈', '风格玩法', '用本地能力生成更有趣的画面表达')
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
        selectedModule: HomeModule.AI,
        onModuleChange: (module: HomeModule) => this.switchModule(module)
      })
        .width(this.isExpanded() ? 680 : '92%').constraintSize({ maxWidth: 680 })
        .margin({ top: 8, bottom: this.isExpanded() ? 16 : 10 })
    }.width('100%').height('100%').justifyContent(FlexAlign.Start).backgroundColor('#FFF8F0')
  }
}