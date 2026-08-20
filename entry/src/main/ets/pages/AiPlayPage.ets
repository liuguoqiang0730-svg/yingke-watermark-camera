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
      this.showToast('暂时无法切换模块');
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (_) {
    }
  }

  private openFaceSimilarity(): void {
    try {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/FaceSimilarityPage' });
    } catch (_) {
      this.showToast('暂时无法打开相似度趣测');
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
  private featureCard(icon: string, title: string, description: string, badge: string, action: () => void) {
    Row({ space: this.isExpanded() ? 22 : 14 }) {
      Text(icon).fontSize(this.isExpanded() ? 30 : 25).fontColor('#F05A20')
        .width(this.isExpanded() ? 76 : 62).height(this.isExpanded() ? 76 : 62)
        .textAlign(TextAlign.Center).backgroundColor('#FFF0DE')
        .borderRadius(this.isExpanded() ? 22 : 18)
      Column({ space: 5 }) {
        Text(title).fontSize(this.isExpanded() ? 20 : 17)
          .fontWeight(FontWeight.Bold).fontColor('#3B2117')
        Text(description).fontSize(this.isExpanded() ? 14 : 12)
          .fontColor('#9B7761').maxLines(2)
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Row({ space: 7 }) {
        Text(badge).fontSize(this.isExpanded() ? 13 : 11).fontColor('#D55A28')
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor('#FFE7D2').borderRadius(16)
        Text('›').fontSize(26).fontColor('#6F4C3A')
      }
    }
    .width('100%').height(this.isExpanded() ? 118 : 100)
    .padding({ left: this.isExpanded() ? 22 : 15, right: this.isExpanded() ? 22 : 15 })
    .backgroundColor('#FFFDF9').borderRadius(22)
    .border({ width: 1, color: '#F2DCCB' })
    .onClick(action)
  }

  build() {
    Column() {
      Scroll() {
        Column({ space: this.isExpanded() ? 24 : 18 }) {
          this.header()
          Column({ space: 7 }) {
            Text('让照片多一点想象力').fontSize(this.isExpanded() ? 32 : 27)
              .fontWeight(FontWeight.Bold).fontColor('#3B2117')
            Text('选择一个玩法，进入独立空间导入并处理图片')
              .fontSize(14).fontColor('#9B7761')
          }.width('100%').alignItems(HorizontalAlign.Start)

          Column({ space: 12 }) {
            Text('AI 玩法').fontSize(this.isExpanded() ? 22 : 19)
              .fontWeight(FontWeight.Bold).fontColor('#3B2117').width('100%')
            this.featureCard('☺', '相似度趣测', '选择两张人脸照片，看看你们有多像', '立即使用',
              () => this.openFaceSimilarity())
            this.featureCard('▧', '画面识别', '识别照片中的人物、景物与常见物体', '后续开放', () => {})
            this.featureCard('◈', '风格玩法', '用本地能力生成更有趣的画面表达', '后续开放', () => {})
          }.width('100%')
        }
        .width('100%').constraintSize({ maxWidth: 1080 })
        .padding({
          left: this.isExpanded() ? 40 : 16,
          right: this.isExpanded() ? 40 : 16,
          top: this.isExpanded() ? 28 : 24,
          bottom: 28
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
