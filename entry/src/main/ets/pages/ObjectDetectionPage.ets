import { common } from '@kit.AbilityKit';
import { AppError, AppErrorCode } from '../models/AppError';
import { DetectedObject, ObjectDetectionResult } from '../models/ObjectDetectionResult';
import { ErrorMessageUtil } from '../utils/ErrorMessageUtil';
import { AiPlayViewModel } from '../viewmodels/AiPlayViewModel';

@Entry
@Component
struct ObjectDetectionPage {
  @State private viewportWidth: number = 0;
  @State private selectedImageUri: string = '';
  @State private isRecognizing: boolean = false;
  @State private progressText: string = '';
  @State private previewUri: string = '';
  @State private imageWidth: number = 0;
  @State private imageHeight: number = 0;
  @State private previewWidth: number = 0;
  @State private previewHeight: number = 0;
  @State private detectedObjects: DetectedObject[] = [];
  @State private errorMessage: string = '';

  private readonly viewModel: AiPlayViewModel = new AiPlayViewModel();
  private readonly abilityContext: common.UIAbilityContext =
    this.getUIContext().getHostContext() as common.UIAbilityContext;

  async aboutToDisappear(): Promise<void> {
    await this.viewModel.release();
  }

  private isExpanded(): boolean {
    return this.viewportWidth >= 840;
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (_) {
    }
  }

  private clearResult(): void {
    this.previewUri = '';
    this.imageWidth = 0;
    this.imageHeight = 0;
    this.detectedObjects = [];
    this.errorMessage = '';
  }

  private async choosePhoto(): Promise<void> {
    if (this.isRecognizing) {
      return;
    }
    try {
      const uri = await this.viewModel.selectPhoto();
      this.selectedImageUri = uri;
      this.clearResult();
    } catch (error) {
      if (error instanceof AppError && error.code === AppErrorCode.USER_CANCELLED) {
        return;
      }
      this.errorMessage = ErrorMessageUtil.from(error as object, '无法读取所选图片，请重试。');
    }
  }

  private async recognizeSelectedPhoto(): Promise<void> {
    if (!this.selectedImageUri) {
      this.showToast('请先导入一张图片');
      return;
    }
    if (this.isRecognizing) {
      return;
    }
    this.isRecognizing = true;
    this.progressText = '正在设备端识别画面…';
    this.errorMessage = '';
    this.previewUri = '';
    this.detectedObjects = [];
    try {
      const result = await this.viewModel.recognizeObjects(this.abilityContext, this.selectedImageUri);
      this.applyResult(result);
    } catch (error) {
      this.errorMessage = ErrorMessageUtil.from(error as object, '画面识别失败，请重试。');
    } finally {
      this.isRecognizing = false;
      this.progressText = '';
    }
  }

  private applyResult(result: ObjectDetectionResult): void {
    this.previewUri = result.previewUri;
    this.imageWidth = result.imageWidth;
    this.imageHeight = result.imageHeight;
    this.detectedObjects = result.objects;
  }

  private imageScale(): number {
    if (this.previewWidth <= 0 || this.previewHeight <= 0 ||
      this.imageWidth <= 0 || this.imageHeight <= 0) {
      return 0;
    }
    return Math.min(this.previewWidth / this.imageWidth, this.previewHeight / this.imageHeight);
  }

  private imageOffsetX(): number {
    return (this.previewWidth - this.imageWidth * this.imageScale()) / 2;
  }

  private imageOffsetY(): number {
    return (this.previewHeight - this.imageHeight * this.imageScale()) / 2;
  }

  private boxX(item: DetectedObject): number {
    return this.imageOffsetX() + item.box.left * this.imageScale();
  }

  private boxY(item: DetectedObject): number {
    return this.imageOffsetY() + item.box.top * this.imageScale();
  }

  private boxWidth(item: DetectedObject): number {
    return Math.max(2, item.box.width * this.imageScale());
  }

  private boxHeight(item: DetectedObject): number {
    return Math.max(2, item.box.height * this.imageScale());
  }

  @Builder
  private topBar() {
    Row({ space: 12 }) {
      Button('‹').width(44).height(44).fontSize(30).type(ButtonType.Normal)
        .fontColor('#3B2117').backgroundColor('#FFF7F0').borderRadius(22)
        .enabled(!this.isRecognizing)
        .onClick(() => this.getUIContext().getRouter().back())
      Column({ space: 2 }) {
        Text('画面识别').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#3B2117')
        Text('识别图片中的人物、景物与常见物体').fontSize(12).fontColor('#9A725C')
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text('本地处理').fontSize(12).fontColor('#4F7657')
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .backgroundColor('#EAF5EA').borderRadius(14)
    }
    .width('100%').padding({ left: 18, right: 18, top: 14, bottom: 12 })
    .backgroundColor('#FFFBF7')
  }

  @Builder
  private importPanel() {
    Column({ space: 18 }) {
      Column({ space: 6 }) {
        Text(this.selectedImageUri ? '确认识别图片' : '导入一张图片').fontSize(this.isExpanded() ? 28 : 24)
          .fontWeight(FontWeight.Bold).fontColor('#3B2117')
        Text(this.selectedImageUri ? '确认画面清晰后开始识别' : '支持从系统相册选择照片，图片仅在本机处理')
          .fontSize(14).fontColor('#9B7761')
      }.width('100%').alignItems(HorizontalAlign.Start)

      if (this.selectedImageUri) {
        Image(this.selectedImageUri).width('100%').height(this.isExpanded() ? 420 : 280)
          .objectFit(ImageFit.Contain).backgroundColor('#221A16').borderRadius(18)

        Row({ space: 12 }) {
          Button('更换图片').layoutWeight(1).height(50).type(ButtonType.Normal)
            .fontSize(15).fontColor('#5A3829').backgroundColor('#FFF0E3').borderRadius(25)
            .enabled(!this.isRecognizing).onClick(() => this.choosePhoto())
          Button() {
            Row({ space: 9 }) {
              if (this.isRecognizing) {
                LoadingProgress().width(21).height(21).color(Color.White)
              }
              Text(this.isRecognizing ? '正在识别…' : '开始识别')
                .fontSize(16).fontWeight(FontWeight.Bold).fontColor(Color.White)
            }.justifyContent(FlexAlign.Center)
          }
          .layoutWeight(1).height(50).type(ButtonType.Normal).borderRadius(25)
          .backgroundColor(this.isRecognizing ? '#D7B9A7' : '#E96832')
          .enabled(!this.isRecognizing).onClick(() => this.recognizeSelectedPhoto())
        }.width('100%')

        if (this.isRecognizing) {
          Text(this.progressText).width('100%').fontSize(13).fontColor('#8A654F')
            .textAlign(TextAlign.Center)
        }
      } else {
        Column({ space: 12 }) {
          Text('▧').fontSize(48).fontColor('#E96832')
            .width(86).height(86).textAlign(TextAlign.Center)
            .backgroundColor('#FFF0DE').borderRadius(24)
          Text('点击导入图片').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#4A3025')
          Text('建议选择主体清晰、光线充足的图片').fontSize(13).fontColor('#A07A63')
        }
        .width('100%').height(this.isExpanded() ? 360 : 280)
        .justifyContent(FlexAlign.Center).backgroundColor('#FFF8EE').borderRadius(22)
        .border({ width: 1, color: '#EBCDB7', style: BorderStyle.Dashed })
        .onClick(() => this.choosePhoto())

        Button('从相册导入图片').width('100%').height(52).type(ButtonType.Normal)
          .fontSize(16).fontWeight(FontWeight.Bold).fontColor(Color.White)
          .backgroundColor('#E96832').borderRadius(26).onClick(() => this.choosePhoto())
      }

      if (this.errorMessage) {
        Row({ space: 8 }) {
          Text('!').fontSize(14).fontWeight(FontWeight.Bold).fontColor('#C94726')
            .width(24).height(24).textAlign(TextAlign.Center)
            .backgroundColor('#FFE1D8').borderRadius(12)
          Text(this.errorMessage).fontSize(13).fontColor('#A74228').layoutWeight(1)
        }
        .width('100%').padding(12).backgroundColor('#FFF2EE').borderRadius(14)
      }
    }
    .width('100%').padding(this.isExpanded() ? 28 : 18)
    .backgroundColor('#FFFDF9').borderRadius(this.isExpanded() ? 28 : 24)
    .border({ width: 1, color: '#F0D7C4' })
    .shadow({ radius: 18, color: '#12000000', offsetY: 6 })
  }

  @Builder
  private detectionBox(item: DetectedObject, index: number) {
    Stack({ alignContent: Alignment.TopStart }) {
      Text(`${index + 1}`).fontSize(11).fontWeight(FontWeight.Bold).fontColor(Color.White)
        .width(22).height(22).textAlign(TextAlign.Center).backgroundColor('#E96832').borderRadius(4)
    }
    .width(this.boxWidth(item)).height(this.boxHeight(item))
    .border({ width: 2, color: '#FF6A2B' }).backgroundColor('#0CFF6A2B')
    .position({ x: this.boxX(item), y: this.boxY(item) })
  }

  @Builder
  private resultRow(item: DetectedObject, index: number) {
    Row({ space: 12 }) {
      Text(`${index + 1}`).fontSize(13).fontWeight(FontWeight.Bold).fontColor(Color.White)
        .width(30).height(30).textAlign(TextAlign.Center).backgroundColor('#E96832').borderRadius(15)
      Column({ space: 3 }) {
        Text(item.label).fontSize(15).fontWeight(FontWeight.Bold).fontColor('#4A3025')
        Text(`区域：${Math.round(item.box.left)}, ${Math.round(item.box.top)} · ` +
          `${Math.round(item.box.width)} × ${Math.round(item.box.height)}`)
          .fontSize(11).fontColor('#A07A63')
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text(`${Math.round(item.score * 100)}%`).fontSize(14).fontWeight(FontWeight.Bold)
        .fontColor('#D95725').padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .backgroundColor('#FFF0E3').borderRadius(14)
    }
    .width('100%').padding(12).backgroundColor('#FFF8F1').borderRadius(16)
  }

  @Builder
  private resultPanel() {
    Column({ space: 16 }) {
      Row() {
        Column({ space: 4 }) {
          Text('识别完成').fontSize(this.isExpanded() ? 26 : 22)
            .fontWeight(FontWeight.Bold).fontColor('#3B2117')
          Text(this.detectedObjects.length > 0 ?
            `识别到 ${this.detectedObjects.length} 个目标` : '未识别到常见目标')
            .fontSize(13).fontColor('#9B7761')
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Text(`${this.imageWidth} × ${this.imageHeight}`).fontSize(12).fontColor('#8A654F')
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor('#FFF0E3').borderRadius(14)
      }.width('100%')

      Stack({ alignContent: Alignment.TopStart }) {
        Image(this.previewUri).width('100%').height('100%').objectFit(ImageFit.Contain)
        ForEach(this.detectedObjects, (item: DetectedObject, index: number) => {
          this.detectionBox(item, index)
        }, (item: DetectedObject): string => `${item.id}`)
      }
      .width('100%').height(this.isExpanded() ? 500 : 320)
      .backgroundColor('#221A16').borderRadius(18).clip(true)
      .onAreaChange((_oldValue, newValue) => {
        this.previewWidth = Number(newValue.width);
        this.previewHeight = Number(newValue.height);
      })

      if (this.detectedObjects.length > 0) {
        Column({ space: 10 }) {
          ForEach(this.detectedObjects, (item: DetectedObject, index: number) => {
            this.resultRow(item, index)
          }, (item: DetectedObject): string => `result_${item.id}`)
        }.width('100%')
      } else {
        Text('没有检测到系统支持的常见类别。这不代表图片异常，可以换一张主体更清晰的图片重试。')
          .width('100%').fontSize(13).lineHeight(21).fontColor('#7C5B48')
          .padding(14).backgroundColor('#FFF8F1').borderRadius(14)
      }

      Button('重新导入图片').width('100%').height(50).type(ButtonType.Normal)
        .fontSize(16).fontWeight(FontWeight.Bold).fontColor(Color.White)
        .backgroundColor('#E96832').borderRadius(25).onClick(() => this.choosePhoto())
    }
    .width('100%').padding(this.isExpanded() ? 28 : 18)
    .alignItems(HorizontalAlign.Start).backgroundColor('#FFFDF9')
    .borderRadius(this.isExpanded() ? 28 : 24).border({ width: 1, color: '#F0D7C4' })
    .shadow({ radius: 18, color: '#12000000', offsetY: 6 })
  }

  build() {
    Column() {
      this.topBar()
      Scroll() {
        Column({ space: 18 }) {
          if (this.previewUri) {
            this.resultPanel()
          } else {
            this.importPanel()
          }

          Text('识别结果来自端侧 AI 模型，仅用于画面内容提示，不作为专业判断依据。')
            .width('100%').fontSize(12).lineHeight(19).fontColor('#A18472')
            .textAlign(TextAlign.Center).padding({ left: 16, right: 16 })
        }
        .width('100%').constraintSize({ maxWidth: 980 })
        .padding({
          left: this.isExpanded() ? 40 : 16,
          right: this.isExpanded() ? 40 : 16,
          top: this.isExpanded() ? 28 : 18,
          bottom: 30
        })
      }.width('100%').layoutWeight(1).align(Alignment.TopStart)
    }
    .width('100%').height('100%').backgroundColor('#FFF8F0')
    .onAreaChange((_oldValue, newValue) => this.viewportWidth = Number(newValue.width))
  }
}
