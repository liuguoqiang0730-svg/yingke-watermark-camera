import { BottomModuleSwitcher, HomeModule } from '../components/BottomModuleSwitcher';
import { AppError, AppErrorCode } from '../models/AppError';
import { ErrorMessageUtil } from '../utils/ErrorMessageUtil';
import { ToolsViewModel } from '../viewmodels/ToolsViewModel';

@Entry
@Component
struct ToolsPage {
  @State private currentBreakpoint: string = 'xs';
  @State private ocrInitializing: boolean = true;
  @State private ocrBusy: boolean = false;
  @State private ocrProgress: string = '正在准备文字识别…';
  @State private selectedImageUri: string = '';
  @State private recognizedText: string = '';
  @State private ocrError: string = '';
  private readonly viewModel: ToolsViewModel = new ToolsViewModel();

  async aboutToAppear(): Promise<void> {
    this.ocrInitializing = true;
    try {
      await this.viewModel.initializeOcr();
    } catch (error) {
      this.ocrError = ErrorMessageUtil.from(error as object, '文字识别服务暂不可用。');
    } finally {
      this.ocrInitializing = false;
    }
  }

  async aboutToDisappear(): Promise<void> {
    await this.viewModel.release();
  }

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

  private async startTextRecognition(): Promise<void> {
    if (this.ocrBusy) {
      return;
    }
    this.ocrBusy = true;
    this.ocrProgress = '正在打开相册…';
    this.ocrError = '';
    try {
      const uri = await this.viewModel.selectPhoto();
      this.selectedImageUri = uri;
      this.recognizedText = '';
      this.ocrProgress = '正在识别图片中的文字…';
      const text = await this.viewModel.recognizeText(uri);
      if (!text) {
        this.ocrError = '未识别到文字，请选择文字清晰、画面端正的图片重试。';
        return;
      }
      this.recognizedText = text;
    } catch (error) {
      const appError = error as AppError;
      if (appError.code !== AppErrorCode.USER_CANCELLED) {
        this.ocrError = ErrorMessageUtil.from(error as object, '文字识别失败。');
      }
    } finally {
      this.ocrBusy = false;
    }
  }

  private async copyRecognizedText(): Promise<void> {
    if (!this.recognizedText) {
      return;
    }
    try {
      await this.viewModel.copyText(this.recognizedText);
      this.showToast('识别文字已复制');
    } catch (error) {
      this.showToast(ErrorMessageUtil.from(error as object, '复制失败，请长按文字手动复制。'));
    }
  }

  private openCollage(): void {
    try {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/CollagePage' });
    } catch (_) {
      this.showToast('暂时无法打开多图拼接。');
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
        Text(available ? (title === '文字识别' && this.ocrInitializing ? '准备中' : '立即使用') : '后续开放')
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
        } else {
          this.startTextRecognition();
        }
      }
    })
  }

  @Builder
  private ocrResultCard() {
    Column({ space: 14 }) {
      Row({ space: 12 }) {
        Column({ space: 3 }) {
          Text('文字识别结果').fontSize(this.isExpanded() ? 22 : 18)
            .fontWeight(FontWeight.Bold).fontColor('#3B2117')
          Text(this.recognizedText ? `${this.recognizedText.length} 个字符，可长按选择或一键复制` : '识别结果将在这里显示')
            .fontSize(12).fontColor('#9B7761')
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        if (this.recognizedText) {
          Button('复制全部').height(38).type(ButtonType.Normal)
            .fontSize(13).fontColor(Color.White).backgroundColor('#E96832').borderRadius(19)
            .onClick(() => this.copyRecognizedText())
        }
      }.width('100%')

      if (this.selectedImageUri) {
        Image(this.selectedImageUri).width('100%').height(this.isExpanded() ? 260 : 190)
          .objectFit(ImageFit.Contain).backgroundColor('#FFF8F0').borderRadius(16)
      }

      if (this.recognizedText) {
        Scroll() {
          Text(this.recognizedText).width('100%').fontSize(15).lineHeight(24)
            .fontColor('#4A3025').copyOption(CopyOptions.LocalDevice)
        }.width('100%').height(this.isExpanded() ? 260 : 210)
          .padding(14).backgroundColor('#FFF8F1').borderRadius(16)
      }

      if (this.ocrError) {
        Text(this.ocrError).width('100%').fontSize(13).lineHeight(20).fontColor('#9B3A20')
          .padding(12).backgroundColor('#FFFFE9E3').borderRadius(12)
      }

      if (this.selectedImageUri || this.ocrError) {
        Button(this.ocrBusy ? '正在识别…' : '重新选择图片').width('100%').height(48)
          .enabled(!this.ocrBusy).type(ButtonType.Normal).fontSize(15)
          .fontColor('#5A3829').backgroundColor('#FFF0E3').borderRadius(24)
          .onClick(() => this.startTextRecognition())
      }
    }
    .width('100%').padding(this.isExpanded() ? 24 : 18)
    .alignItems(HorizontalAlign.Start).backgroundColor('#FFFDF9')
    .borderRadius(this.isExpanded() ? 26 : 22).border({ width: 1, color: '#F2DCCB' })
    .shadow({ radius: 16, color: '#10000000', offsetY: 5 })
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
                this.featureCard('◉', '主体分割', '透明图片与背景替换')
                if (this.ocrBusy) {
                  Row({ space: 12 }) {
                    LoadingProgress().width(24).height(24).color('#E96832')
                    Text(this.ocrProgress).fontSize(14).fontColor('#6F4C3A')
                  }.width('100%').justifyContent(FlexAlign.Center).padding(16)
                }
                if (this.selectedImageUri || this.recognizedText || this.ocrError) {
                  this.ocrResultCard()
                }
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