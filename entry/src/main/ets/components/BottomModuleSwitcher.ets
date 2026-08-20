export enum HomeModule {
  CAMERA = 0,
  TOOLS = 1,
  AI = 2
}

@Component
export struct BottomModuleSwitcher {
  @Prop selectedModule: HomeModule;
  onModuleChange: (module: HomeModule) => void = () => {};

  @Builder
  private cameraIcon(selected: boolean) {
    Stack() {
      Row().width(22).height(16).border({ width: 2, color: selected ? '#D94716' : '#725846' })
        .borderRadius(5)
      Circle().width(8).height(8).fill(Color.Transparent)
        .stroke(selected ? '#D94716' : '#725846').strokeWidth(2)
      Row().width(7).height(3).backgroundColor(selected ? '#D94716' : '#725846')
        .borderRadius(2).position({ x: 4, y: 1 })
    }.width(28).height(24)
  }

  @Builder
  private toolsIcon(selected: boolean) {
    Column({ space: 4 }) {
      Row() {
        Divider().width(22).strokeWidth(2).color(selected ? '#D94716' : '#725846')
        Circle().width(6).height(6).fill(selected ? '#D94716' : '#725846')
          .position({ x: 5, y: 0 })
      }.width(28).height(6)
      Row() {
        Divider().width(22).strokeWidth(2).color(selected ? '#D94716' : '#725846')
        Circle().width(6).height(6).fill(selected ? '#D94716' : '#725846')
          .position({ x: 17, y: 0 })
      }.width(28).height(6)
      Row() {
        Divider().width(22).strokeWidth(2).color(selected ? '#D94716' : '#725846')
        Circle().width(6).height(6).fill(selected ? '#D94716' : '#725846')
          .position({ x: 10, y: 0 })
      }.width(28).height(6)
    }.width(28)
  }

  @Builder
  private moduleItem(module: HomeModule, label: string) {
    Column({ space: 5 }) {
      if (module === HomeModule.CAMERA) {
        this.cameraIcon(this.selectedModule === module)
      } else if (module === HomeModule.TOOLS) {
        this.toolsIcon(this.selectedModule === module)
      } else {
        Text('✦').fontSize(28).fontColor(this.selectedModule === module ? '#D94716' : '#725846')
      }
      Text(label).fontSize(15).fontWeight(FontWeight.Medium)
        .fontColor(this.selectedModule === module ? '#D94716' : '#725846')
    }
    .width('33.33%').height(72).justifyContent(FlexAlign.Center)
    .backgroundColor(this.selectedModule === module ? '#FFE0C5' : Color.Transparent)
    .borderRadius(24)
    .onClick(() => this.onModuleChange(module))
  }

  build() {
    Row() {
      this.moduleItem(HomeModule.CAMERA, '相机')
      this.moduleItem(HomeModule.TOOLS, '工具')
      this.moduleItem(HomeModule.AI, 'AI 玩法')
    }
    .width('100%').height(84).padding(6)
    .backgroundColor('#FFFDF9').borderRadius(30)
    .shadow({ radius: 24, color: '#26000000', offsetY: 8 })
  }
}
