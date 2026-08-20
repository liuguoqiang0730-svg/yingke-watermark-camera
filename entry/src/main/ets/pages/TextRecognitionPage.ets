import { AppError, AppErrorCode } from '../models/AppError';
import { ErrorMessageUtil } from '../utils/ErrorMessageUtil';
import { TextRecognitionViewModel } from '../viewmodels/TextRecognitionViewModel';

@Entry
@Component
struct TextRecognitionPage {
  @State private viewportWidth: number = 0;
  @State private initializing: boolean = true;
  @State private processing: boolean = false;
  @State private progressMessage: string = '正在准备文字识别…';
  @State private selectedImageUri: string = '';
  @State private recognizedText: string = '';
  @State private errorMessage: string = '';
  private readonly viewModel: TextRecognitionViewModel = new TextRecognitionViewModel();

  async aboutToAppear(): Promise<void> {
    this.initializing = true;
    try {
      await this.viewModel.initialize();
    } catch (error) {
      this.errorMessage = ErrorMessageUtil.from(error as object, '文字识别服务暂不可用。');
    } finally {
      this.initializing = false;
    }
  }

  async aboutToDisappear(): Promise<void> {
    await this.viewModel.release();
  }

  private isExpanded(): boolean {
    return this.viewportWidth >= 840;
  }

  private async chooseAndRecognize(): Promise<void> {
    if (this.processing || this.initializing) {
      return;
    }
    this.processing = true;
    this.progressMessage = '正在打开相册…';
    this.errorMessage = '';
    try {
      const uri = await this.viewModel.selectPhoto();
      this.selectedImageUri = uri;
      this.recognizedText = '';
      this.progressMessage = '正在识别图片中的文字…';
      const text = await this.viewModel.recognize(uri);
      if (!text) {
        this.errorMessage = '未识别到文字，请选择文字清晰、画面端正的图片重试。';
        return;
      }
      this.recognizedText = text;
    } catch (error) {
      if (error instanceof AppError && error.code === AppErrorCode.USER_CANCELLED) {
        return;
      }
      this.errorMessage = ErrorMessageUtil.from(error as object, '文字识别失败，请重试。');
    } finally {
      this.processing = false;
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

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (_) {
    }
  }

  @Builder
  private topBar() {
    Row({ space: 12 }) {
      Button('‹').width(44).height(44).fontSize(30).type(ButtonType.Normal)
        .fontColor('#3B2117').backgroundColor('#FFF7F0').borderRadius(22)
        .enabled(!this.processing)
        .onClick(() => this.getUIContext().getRouter().back())
      Column({ space: 2 }) {
        Text('文字识别').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#3B2117')
        Text('从图片中提取可复制文字').fontSize(12).fontColor('#9A725C')
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text('本地处理').fontSize(12).fontColor('#4F7657')
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .backgroundColor('#EAF5EA').borderRadius(14)
    }
    .width('100%').padding({ left: 18, right: 18, top: 14, bottom: 12 })
    .backgroundColor('#FFFBF7')
  }

  @Builder
  private imagePanel() {
    Column({ space: 16 }) {
      Row() {
        Column({ space: 3 }) {
          Text(this.selectedImageUri ? '待识别图片' : '选择一张图片')
            .fontSize(this.isExpanded() ? 21 : 18).fontWeight(FontWeight.Bold).fontColor('#3B2117')
          Text('建议使用清晰、端正、光线充足的印刷文字图片')
            .fontSize(12).fontColor('#9B7761')
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        if (this.selectedImageUri) {
          Button('更换图片').height(38).type(ButtonType.Normal)
            .enabled(!this.processing && !this.initializing).fontSize(13)
            .fontColor('#D95F2D').backgroundColor('#FFE9D8').borderRadius(19)
            .onClick(() => this.chooseAndRecognize())
        }
      }.width('100%')

      if (this.selectedImageUri) {
        Image(this.selectedImageUri).width('100%').height(this.isExpanded() ? 390 : 250)
          .objectFit(ImageFit.Contain).backgroundColor('#FFF8F0').borderRadius(20)
      } else {
        Column({ space: 12 }) {
          Text('OCR').fontSize(this.isExpanded() ? 42 : 34)
            .fontWeight(FontWeight.Bold).fontColor('#E96832')
          Text('图片仅在设备本地处理').fontSize(13).fontColor('#8B6854')
          Button(this.initializing ? '正在准备识别服务…' : '选择图片并识别')
            .width(this.isExpanded() ? 300 : '82%').height(50).type(ButtonType.Normal)
            .enabled(!this.initializing && !this.processing)
            .fontSize(16).fontWeight(FontWeight.Bold).fontColor(Color.White)
            .backgroundColor(this.initializing ? '#D7B9A7' : '#E96832').borderRadius(25)
            .onClick(() => this.chooseAndRecognize())
        }
        .width('100%').height(this.isExpanded() ? 360 : 280)
        .justifyContent(FlexAlign.Center).backgroundColor('#FFF8EE').borderRadius(20)
        .border({ width: 1, color: '#EBCDB7', style: BorderStyle.Dashed })
      }

      if (this.processing) {
        Row({ space: 10 }) {
          LoadingProgress().width(24).height(24).color('#E96832')
          Text(this.progressMessage).fontSize(14).fontColor('#6F4C3A')
        }.width('100%').justifyContent(FlexAlign.Center).padding(10)
      }

      if (this.errorMessage) {
        Row({ space: 8 }) {
          Text('!').fontSize(14).fontWeight(FontWeight.Bold).fontColor('#C94726')
            .width(24).height(24).textAlign(TextAlign.Center)
            .backgroundColor('#FFE1D8').borderRadius(12)
          Text(this.errorMessage).fontSize(13).fontColor('#A74228').layoutWeight(1)
        }.width('100%').padding(12).backgroundColor('#FFF2EE').borderRadius(14)
      }
    }
    .width('100%').padding(this.isExpanded() ? 26 : 18)
    .backgroundColor('#FFFDF9').borderRadius(this.isExpanded() ? 28 : 24)
    .border({ width: 1, color: '#F0D7C4' })
    .shadow({ radius: 18, color: '#12000000', offsetY: 6 })
  }

  @Builder
  private resultPanel() {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 3 }) {
          Text('识别结果').fontSize(this.isExpanded() ? 21 : 18)
            .fontWeight(FontWeight.Bold).fontColor('#3B2117')
          Text(`${this.recognizedText.length} 个字符，可长按选择文字`)
            .fontSize(12).fontColor('#9B7761')
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Button('复制全部').height(38).type(ButtonType.Normal)
          .fontSize(13).fontColor(Color.White).backgroundColor('#E96832').borderRadius(19)
          .onClick(() => this.copyRecognizedText())
      }.width('100%')

      Text(this.recognizedText).width('100%').fontSize(15).lineHeight(24)
        .fontColor('#4A3025').copyOption(CopyOptions.LocalDevice)
        .padding(16).backgroundColor('#FFF8F1').borderRadius(16)
    }
    .width('100%').padding(this.isExpanded() ? 26 : 18)
    .alignItems(HorizontalAlign.Start).backgroundColor('#FFFDF9')
    .borderRadius(this.isExpanded() ? 28 : 24).border({ width: 1, color: '#F0D7C4' })
  }

  build() {
    Column() {
      this.topBar()
      Scroll() {
        Column({ space: this.isExpanded() ? 24 : 18 }) {
          this.imagePanel()
          if (this.recognizedText) {
            this.resultPanel()
          }
        }
        .width('100%').constraintSize({ maxWidth: 1080 })
        .padding({
          left: this.isExpanded() ? 40 : 16,
          right: this.isExpanded() ? 40 : 16,
          top: this.isExpanded() ? 28 : 20,
          bottom: 28
        })
      }.width('100%').layoutWeight(1)
    }
    .width('100%').height('100%').backgroundColor('#FFF8F0')
    .onAreaChange((_oldValue, newValue) => this.viewportWidth = Number(newValue.width))
  }
}
