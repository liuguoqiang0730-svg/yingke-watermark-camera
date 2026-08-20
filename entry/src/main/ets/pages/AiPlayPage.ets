import { BottomModuleSwitcher, HomeModule } from '../components/BottomModuleSwitcher';
import { AppError, AppErrorCode } from '../models/AppError';
import { ErrorMessageUtil } from '../utils/ErrorMessageUtil';
import { AiPlayViewModel } from '../viewmodels/AiPlayViewModel';

@Entry
@Component
struct AiPlayPage {
  @State private currentBreakpoint: string = 'xs';
  @State private firstImageUri: string = '';
  @State private secondImageUri: string = '';
  @State private isComparing: boolean = false;
  @State private hasResult: boolean = false;
  @State private similarity: number = 0;
  @State private isSamePerson: boolean = false;
  @State private errorMessage: string = '';
  private readonly viewModel: AiPlayViewModel = new AiPlayViewModel();

  private isExpanded(): boolean {
    return this.currentBreakpoint === 'md';
  }

  private canCompare(): boolean {
    return this.firstImageUri.length > 0 && this.secondImageUri.length > 0 && !this.isComparing;
  }

  private similarityPercent(): number {
    return this.similarity * 100;
  }

  private resultTitle(): string {
    const percent = this.similarityPercent();
    if (percent >= 85) {
      return '默契十足';
    }
    if (percent >= 70) {
      return '很有相似感';
    }
    if (percent >= 50) {
      return '有些神似';
    }
    return '各有特色';
  }

  private resultDescription(): string {
    return this.isSamePerson ? '系统判断两张照片中的最大人脸可能属于同一人' :
      '系统判断两张照片中的最大人脸更可能属于不同的人';
  }

  private switchModule(module: HomeModule): void {
    if (module === HomeModule.AI) {
      return;
    }
    if (this.isComparing) {
      this.showToast('正在进行人脸比对，请稍候');
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

  private clearResult(): void {
    this.hasResult = false;
    this.similarity = 0;
    this.isSamePerson = false;
    this.errorMessage = '';
  }

  private async choosePhoto(slot: number): Promise<void> {
    if (this.isComparing) {
      return;
    }
    try {
      const uri = await this.viewModel.selectPhoto();
      if (slot === 1) {
        this.firstImageUri = uri;
      } else {
        this.secondImageUri = uri;
      }
      this.clearResult();
    } catch (error) {
      if (error instanceof AppError && error.code === AppErrorCode.USER_CANCELLED) {
        return;
      }
      this.errorMessage = ErrorMessageUtil.from(error as object, '无法读取所选照片，请重试。');
    }
  }

  private async compareFaces(): Promise<void> {
    if (!this.canCompare()) {
      this.showToast('请先选择两张包含人脸的照片');
      return;
    }
    this.isComparing = true;
    this.hasResult = false;
    this.errorMessage = '';
    try {
      const result = await this.viewModel.compareFaces(this.firstImageUri, this.secondImageUri);
      this.similarity = result.similarity;
      this.isSamePerson = result.isSamePerson;
      this.hasResult = true;
    } catch (error) {
      this.errorMessage = ErrorMessageUtil.from(error as object,
        '识别失败，请确保两张照片中都包含清晰的正面人脸。');
    } finally {
      this.isComparing = false;
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
  private photoSlot(uri: string, label: string, slot: number) {
    Column({ space: 10 }) {
      Stack() {
        if (uri.length > 0) {
          Image(uri)
            .width('100%').height(this.isExpanded() ? 210 : 150)
            .objectFit(ImageFit.Cover).borderRadius(20)
        } else {
          Column({ space: 8 }) {
            Text('+').fontSize(this.isExpanded() ? 42 : 36)
              .fontWeight(FontWeight.Lighter).fontColor('#E85D27')
            Text('选择照片').fontSize(this.isExpanded() ? 16 : 14)
              .fontWeight(FontWeight.Medium).fontColor('#6F4C3A')
          }
          .width('100%').height(this.isExpanded() ? 210 : 150)
          .justifyContent(FlexAlign.Center)
          .backgroundColor('#FFF8EE').borderRadius(20)
        }
      }
      .width('100%').height(this.isExpanded() ? 210 : 150)
      .borderRadius(20)
      .border({ width: 1, color: uri.length > 0 ? '#F0B78E' : '#EBCDB7', style: BorderStyle.Dashed })

      Row() {
        Text(label).fontSize(this.isExpanded() ? 16 : 14)
          .fontWeight(FontWeight.Bold).fontColor('#4A3025')
        Blank()
        Text(uri.length > 0 ? '点击更换' : '待选择').fontSize(12).fontColor('#B17A5C')
      }.width('100%')
    }
    .layoutWeight(1)
    .padding(this.isExpanded() ? 16 : 10)
    .backgroundColor('#FFFDF9').borderRadius(24)
    .border({ width: 1, color: '#F2DCCB' })
    .onClick(() => this.choosePhoto(slot))
  }

  @Builder
  private compareWorkspace() {
    Column({ space: this.isExpanded() ? 22 : 16 }) {
      Row() {
        Column({ space: 5 }) {
          Text('人脸相似度趣测').fontSize(this.isExpanded() ? 24 : 21)
            .fontWeight(FontWeight.Bold).fontColor('#3B2117')
          Text('分别选择两张照片，系统将比对其中面积最大的人脸')
            .fontSize(this.isExpanded() ? 15 : 13).fontColor('#9B7761')
        }.alignItems(HorizontalAlign.Start)
        Blank()
        Text('端侧识别').fontSize(12).fontColor('#D45723')
          .padding({ left: 11, right: 11, top: 6, bottom: 6 })
          .backgroundColor('#FFE8D5').borderRadius(16)
      }.width('100%')

      Row({ space: this.isExpanded() ? 20 : 10 }) {
        this.photoSlot(this.firstImageUri, '照片 A', 1)
        Text('VS').fontSize(this.isExpanded() ? 18 : 13)
          .fontWeight(FontWeight.Bold).fontColor('#E85D27')
          .width(this.isExpanded() ? 48 : 34).textAlign(TextAlign.Center)
        this.photoSlot(this.secondImageUri, '照片 B', 2)
      }.width('100%').alignItems(VerticalAlign.Center)

      Button() {
        Row({ space: 10 }) {
          if (this.isComparing) {
            LoadingProgress().width(22).height(22).color(Color.White)
          }
          Text(this.isComparing ? '正在识别…' : '开始比对')
            .fontSize(17).fontWeight(FontWeight.Bold).fontColor(Color.White)
        }.justifyContent(FlexAlign.Center)
      }
      .width('100%').height(52).type(ButtonType.Capsule)
      .backgroundColor(this.canCompare() ? '#EC652E' : '#D7B9A7')
      .enabled(this.canCompare())
      .onClick(() => this.compareFaces())

      if (this.errorMessage.length > 0) {
        Row({ space: 8 }) {
          Text('!').fontSize(14).fontWeight(FontWeight.Bold).fontColor('#C94726')
            .width(24).height(24).textAlign(TextAlign.Center)
            .backgroundColor('#FFE1D8').borderRadius(12)
          Text(this.errorMessage).fontSize(13).fontColor('#A74228').layoutWeight(1)
        }
        .width('100%').padding(12).backgroundColor('#FFF2EE').borderRadius(14)
      }
    }
    .width('100%').padding(this.isExpanded() ? 26 : 18)
    .backgroundColor('#FFFDF9').borderRadius(this.isExpanded() ? 28 : 24)
    .border({ width: 1, color: '#F0D7C4' })
    .shadow({ radius: 18, color: '#12000000', offsetY: 6 })
  }

  @Builder
  private resultCard() {
    Row({ space: this.isExpanded() ? 28 : 18 }) {
      Stack() {
        Circle().width(this.isExpanded() ? 126 : 106).height(this.isExpanded() ? 126 : 106)
          .fill('#FFF2E7').stroke('#F39A61').strokeWidth(7)
        Column({ space: 0 }) {
          Text(this.similarityPercent().toFixed(1)).fontSize(this.isExpanded() ? 34 : 29)
            .fontWeight(FontWeight.Bold).fontColor('#E55420')
          Text('%').fontSize(14).fontWeight(FontWeight.Bold).fontColor('#B86A43')
        }
      }.width(this.isExpanded() ? 132 : 112).height(this.isExpanded() ? 132 : 112)

      Column({ space: 7 }) {
        Text(this.resultTitle()).fontSize(this.isExpanded() ? 26 : 22)
          .fontWeight(FontWeight.Bold).fontColor('#3B2117')
        Text(this.resultDescription()).fontSize(this.isExpanded() ? 15 : 13)
          .fontColor('#87624D').lineHeight(this.isExpanded() ? 23 : 20)
        Text('结果仅供娱乐，不用于身份认证或专业判断')
          .fontSize(12).fontColor('#B28B73')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }
    .width('100%').padding(this.isExpanded() ? 26 : 20)
    .linearGradient({ angle: 120, colors: [['#FFF8EE', 0.0], ['#FFE5CF', 1.0]] })
    .borderRadius(26).border({ width: 1, color: '#F3C7A7' })
  }

  @Builder
  private featureCard(icon: string, title: string, description: string) {
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
      Text('后续开放').fontSize(this.isExpanded() ? 13 : 11).fontColor('#D55A28')
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .backgroundColor('#FFE7D2').borderRadius(16)
    }
    .width('100%').height(this.isExpanded() ? 118 : 100)
    .padding({ left: this.isExpanded() ? 22 : 15, right: this.isExpanded() ? 22 : 15 })
    .backgroundColor('#FFFDF9').borderRadius(22)
    .border({ width: 1, color: '#F2DCCB' })
  }

  build() {
    Column() {
      Scroll() {
        Column({ space: this.isExpanded() ? 24 : 18 }) {
          this.header()
          Column({ space: 7 }) {
            Text('看看你们有多像').fontSize(this.isExpanded() ? 32 : 27)
              .fontWeight(FontWeight.Bold).fontColor('#3B2117')
            Text('选择清晰、正面、无遮挡的人脸照片，识别效果更好')
              .fontSize(14).fontColor('#9B7761')
          }.width('100%').alignItems(HorizontalAlign.Start)

          this.compareWorkspace()

          if (this.hasResult) {
            this.resultCard()
          }

          Column({ space: 12 }) {
            Text('更多 AI 玩法').fontSize(this.isExpanded() ? 22 : 19)
              .fontWeight(FontWeight.Bold).fontColor('#3B2117').width('100%')
            this.featureCard('▧', '画面识别', '识别照片中的人物、景物与常见物体')
            this.featureCard('◈', '风格玩法', '用本地能力生成更有趣的画面表达')
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
