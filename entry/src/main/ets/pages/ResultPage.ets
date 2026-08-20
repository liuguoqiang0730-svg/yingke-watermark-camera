import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { DraggableWatermarkOverlay } from '../components/DraggableWatermarkOverlay';
import { ProcessingProgress } from '../components/ProcessingProgress';
import { WatermarkConfig, WatermarkPosition } from '../models/WatermarkConfig';
import { PreviewImageResult, ResultViewModel } from '../viewmodels/ResultViewModel';
import { ErrorMessageUtil } from '../utils/ErrorMessageUtil';
import { AppLogger } from '../utils/AppLogger';

const TAG: string = 'ResultPage';

class ResultParams {
  sourceUri: string = '';
  resultOnly?: boolean;
  watermarkText?: string;
  watermarkOpacity?: number;
  textSizePercent?: number;
  logoSizePercent?: number;
  scaleFactor?: number;
  showText?: boolean;
  showLogo?: boolean;
  positionX?: number;
  positionY?: number;
}

@Entry
@Component
struct ResultPage {
  @State private previewUri: string = '';
  @State private imageWidth: number = 0;
  @State private imageHeight: number = 0;
  @State private viewportWidth: number = 0;
  @State private viewportHeight: number = 0;
  @State private text: string = '映刻 · 记录此刻';
  @State private watermarkOpacity: number = 80;
  @State private textSize: number = 4;
  @State private logoSize: number = 5;
  @State private watermarkScale: number = 1;
  @State private showText: boolean = true;
  @State private showLogo: boolean = true;
  @State private positionX: number = 0.82;
  @State private positionY: number = 0.76;
  @State private resultOnly: boolean = false;
  @State private showSettings: boolean = false;
  @State private processing: boolean = false;
  @State private progressMessage: string = '正在处理…';
  @State private errorMessage: string = '';

  private readonly viewModel: ResultViewModel = new ResultViewModel();
  private readonly abilityContext: common.UIAbilityContext =
    this.getUIContext().getHostContext() as common.UIAbilityContext;

  aboutToAppear(): void {
    AppLogger.info(TAG, '结果页开始加载');
    this.setImmersive(true);
    this.loadSource();
  }

  aboutToDisappear(): void {
    this.setImmersive(false);
    this.viewModel.release();
  }

  private async setImmersive(enabled: boolean): Promise<void> {
    try {
      const mainWindow = await window.getLastWindow(this.abilityContext);
      await mainWindow.setWindowLayoutFullScreen(enabled);
      await mainWindow.setWindowSystemBarEnable(enabled ? [] : ['status', 'navigation']);
    } catch (error) {
      AppLogger.warn(TAG, `切换沉浸式显示失败：${JSON.stringify(error)}`);
    }
  }

  private async loadSource(): Promise<void> {
    this.processing = true;
    this.progressMessage = '正在准备全屏预览…';
    this.errorMessage = '';
    try {
      const params = this.getUIContext().getRouter().getParams() as ResultParams;
      if (!params || !params.sourceUri) {
        throw new Error('没有收到可编辑的图片。');
      }
      this.applyRouteConfig(params);
      const result: PreviewImageResult = await this.viewModel.load(
        this.abilityContext, params.sourceUri);
      this.previewUri = this.resultOnly ? await this.viewModel.prepareOutput(
        this.abilityContext, this.createConfig(), $r('app.media.startIcon')) : result.uri;
      this.imageWidth = result.width;
      this.imageHeight = result.height;
    } catch (error) {
      this.errorMessage = ErrorMessageUtil.from(error as object, '图片加载失败。');
      AppLogger.error(TAG, `结果页加载失败：${this.errorMessage}`);
    } finally {
      this.processing = false;
    }
  }

  private applyRouteConfig(params: ResultParams): void {
    this.resultOnly = params.resultOnly ?? false;
    if (params.watermarkText !== undefined) {
      this.text = params.watermarkText;
    }
    if (params.watermarkOpacity !== undefined) {
      this.watermarkOpacity = params.watermarkOpacity;
    }
    if (params.textSizePercent !== undefined) {
      this.textSize = params.textSizePercent;
    }
    if (params.logoSizePercent !== undefined) {
      this.logoSize = params.logoSizePercent;
    }
    if (params.scaleFactor !== undefined) {
      this.watermarkScale = params.scaleFactor;
    }
    if (params.showText !== undefined) {
      this.showText = params.showText;
    }
    if (params.showLogo !== undefined) {
      this.showLogo = params.showLogo;
    }
    if (params.positionX !== undefined) {
      this.positionX = params.positionX;
    }
    if (params.positionY !== undefined) {
      this.positionY = params.positionY;
    }
  }

  private createConfig(): WatermarkConfig {
    const config = new WatermarkConfig();
    config.text = this.text.trim();
    config.position = WatermarkPosition.CUSTOM;
    config.positionX = this.positionX;
    config.positionY = this.positionY;
    config.opacity = this.watermarkOpacity / 100;
    config.textSizePercent = this.textSize;
    config.logoSizePercent = this.logoSize;
    config.scaleFactor = this.watermarkScale;
    config.showText = this.showText;
    config.showLogo = this.showLogo;
    return config;
  }

  private markChanged(): void {
    this.errorMessage = '';
    this.viewModel.invalidateOutput();
  }

  private updatePosition(x: number, y: number): void {
    this.positionX = x;
    this.positionY = y;
    this.markChanged();
  }

  private updateScale(scale: number): void {
    this.watermarkScale = scale;
    this.markChanged();
  }

  private async save(): Promise<void> {
    if (!this.previewUri || this.processing) {
      return;
    }
    this.processing = true;
    this.progressMessage = '正在生成高清水印照片…';
    try {
      await this.viewModel.save(
        this.abilityContext, this.createConfig(), $r('app.media.startIcon'));
      this.getUIContext().getPromptAction().showToast({ message: '已另存为新的相册图片，原图未修改。' });
    } catch (error) {
      this.errorMessage = ErrorMessageUtil.from(error as object, '保存失败。');
    } finally {
      this.processing = false;
    }
  }

  private async share(): Promise<void> {
    if (!this.previewUri || this.processing) {
      return;
    }
    this.processing = true;
    this.progressMessage = '正在准备系统分享…';
    try {
      await this.viewModel.share(
        this.abilityContext, this.createConfig(), $r('app.media.startIcon'));
    } catch (error) {
      this.errorMessage = ErrorMessageUtil.from(error as object, '分享失败。');
    } finally {
      this.processing = false;
    }
  }

  private contentWidth(): number {
    if (this.imageWidth <= 0 || this.imageHeight <= 0 || this.viewportHeight <= 0) {
      return this.viewportWidth;
    }
    const imageRatio = this.imageWidth / this.imageHeight;
    const viewportRatio = this.viewportWidth / this.viewportHeight;
    return viewportRatio > imageRatio ? this.viewportHeight * imageRatio : this.viewportWidth;
  }

  private contentHeight(): number {
    if (this.imageWidth <= 0 || this.imageHeight <= 0 || this.viewportWidth <= 0) {
      return this.viewportHeight;
    }
    const imageRatio = this.imageWidth / this.imageHeight;
    const viewportRatio = this.viewportWidth / this.viewportHeight;
    return viewportRatio > imageRatio ? this.viewportHeight : this.viewportWidth / imageRatio;
  }

  private contentX(): number {
    return Math.max(0, (this.viewportWidth - this.contentWidth()) / 2);
  }

  private contentY(): number {
    return Math.max(0, (this.viewportHeight - this.contentHeight()) / 2);
  }

  private watermarkMargin(): number {
    return Math.min(this.contentWidth(), this.contentHeight()) * 0.04;
  }

  private watermarkFrameX(): number {
    return this.contentX() + this.watermarkMargin();
  }

  private watermarkFrameY(): number {
    return this.contentY() + this.watermarkMargin();
  }

  private watermarkFrameWidth(): number {
    return Math.max(1, this.contentWidth() - this.watermarkMargin() * 2);
  }

  private watermarkFrameHeight(): number {
    return Math.max(1, this.contentHeight() - this.watermarkMargin() * 2);
  }

  private isWide(): boolean {
    return this.viewportWidth >= 700;
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (_) {
    }
  }

  private toggleText(value: boolean): void {
    if (!value && !this.showLogo) {
      this.showToast('文字和 Logo 至少保留一种。');
      return;
    }
    this.showText = value;
    this.markChanged();
  }

  private toggleLogo(value: boolean): void {
    if (!value && !this.showText) {
      this.showToast('文字和 Logo 至少保留一种。');
      return;
    }
    this.showLogo = value;
    this.markChanged();
  }

  @Builder
  private settingsPanel() {
    Stack({ alignContent: Alignment.End }) {
      Column().width('100%').height('100%').backgroundColor('#77000000')
        .onClick(() => this.showSettings = false)

      Column() {
        Row() {
          Column({ space: 3 }) {
            Text('水印设置').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#3B2117')
            Text('调整会即时显示在照片上').fontSize(12).fontColor('#9A725C')
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Button('×').width(42).height(42).fontSize(24).type(ButtonType.Normal)
            .fontColor('#5A3829').backgroundColor('#FFF0E3').borderRadius(21)
            .onClick(() => this.showSettings = false)
        }.width('100%').padding({ left: 22, right: 18, top: 20, bottom: 14 })

        Scroll() {
          Column({ space: 18 }) {
            Column({ space: 8 }) {
              Text('水印文字').fontSize(14).fontWeight(FontWeight.Medium)
                .fontColor('#5A3829').width('100%')
              TextInput({ text: this.text, placeholder: '输入水印文字' })
                .width('100%').height(46).maxLength(40).backgroundColor('#FFF8F1')
                .onChange((value: string) => {
                  this.text = value;
                  this.markChanged();
                })
            }.width('100%')

            Row() {
              Text('文字水印').fontSize(15).fontColor('#4A3025').layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.showText })
                .onChange((value: boolean) => this.toggleText(value))
            }.width('100%')

            Row() {
              Text('Logo 水印').fontSize(15).fontColor('#4A3025').layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.showLogo })
                .onChange((value: boolean) => this.toggleLogo(value))
            }.width('100%')

            Column({ space: 6 }) {
              Text(`透明度 ${Math.round(this.watermarkOpacity)}%`).fontSize(14)
                .fontColor('#5A3829').width('100%')
              Slider({ value: this.watermarkOpacity, min: 20, max: 100, step: 5 })
                .selectedColor('#E96832').onChange((value: number) => {
                  this.watermarkOpacity = value;
                  this.markChanged();
                })
            }.width('100%')

            Column({ space: 6 }) {
              Text(`文字大小 ${this.textSize.toFixed(1)}%`).fontSize(14)
                .fontColor('#5A3829').width('100%')
              Slider({ value: this.textSize, min: 2, max: 8, step: 0.5 })
                .selectedColor('#E96832').onChange((value: number) => {
                  this.textSize = value;
                  this.markChanged();
                })
            }.width('100%')

            Column({ space: 6 }) {
              Text(`Logo 大小 ${Math.round(this.logoSize)}%`).fontSize(14)
                .fontColor('#5A3829').width('100%')
              Slider({ value: this.logoSize, min: 3, max: 12, step: 1 })
                .selectedColor('#E96832').onChange((value: number) => {
                  this.logoSize = value;
                  this.markChanged();
                })
            }.width('100%')

            Column({ space: 6 }) {
              Text(`整体缩放 ${Math.round(this.watermarkScale * 100)}%`).fontSize(14)
                .fontColor('#5A3829').width('100%')
              Slider({ value: this.watermarkScale, min: 0.5, max: 2.5, step: 0.05 })
                .selectedColor('#E96832').onChange((value: number) => this.updateScale(value))
            }.width('100%')

            Column({ space: 10 }) {
              Text('快速定位').fontSize(14).fontColor('#5A3829').width('100%')
              Row({ space: 10 }) {
                Button('居中').layoutWeight(1).height(42).type(ButtonType.Normal)
                  .fontColor('#5A3829').backgroundColor('#FFF0E3').onClick(() => {
                    this.updatePosition(0.5, 0.5);
                  })
                Button('右下').layoutWeight(1).height(42).type(ButtonType.Normal)
                  .fontColor(Color.White).backgroundColor('#E96832').onClick(() => {
                    this.updatePosition(1, 1);
                  })
              }.width('100%')
            }.width('100%')

            Text('也可拖动、双指缩放或双击照片上的水印编辑。')
              .fontSize(12).fontColor('#9A725C').width('100%').textAlign(TextAlign.Center)
          }.width('100%').padding({ left: 22, right: 22, bottom: 28 })
        }.layoutWeight(1).width('100%')
      }
      .width(this.isWide() ? 390 : '92%').height('100%')
      .backgroundColor('#FFFFFBF7')
      .shadow({ radius: 24, color: '#44000000', offsetX: -8 })
    }.width('100%').height('100%')
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.previewUri) {
        Image(this.previewUri).width('100%').height('100%').objectFit(ImageFit.Contain)

        if (!this.resultOnly) {
          DraggableWatermarkOverlay({
            text: this.text,
            showText: this.showText,
            showLogo: this.showLogo,
            watermarkOpacity: this.watermarkOpacity / 100,
            textSize: Math.max(13, this.contentWidth() * this.textSize / 100),
            logoSize: Math.max(24, this.contentWidth() * this.logoSize / 100),
            scaleFactor: this.watermarkScale,
            positionX: this.positionX,
            positionY: this.positionY,
            frameX: this.watermarkFrameX(),
            frameY: this.watermarkFrameY(),
            frameWidth: this.watermarkFrameWidth(),
            frameHeight: this.watermarkFrameHeight(),
            onPositionChange: (x: number, y: number) => this.updatePosition(x, y),
            onScaleChange: (scale: number) => this.updateScale(scale),
            onEditRequest: () => this.showSettings = true
          })
        }
      } else {
        Column({ space: 14 }) {
          LoadingProgress().width(42).height(42).color('#F08A54')
          Text('正在读取照片').fontSize(14).fontColor('#CCFFFFFF')
        }
      }

      Row() {
        Button('‹').width(48).height(48).fontSize(28).type(ButtonType.Normal)
          .fontColor(Color.White).backgroundColor('#66000000').borderRadius(24)
          .onClick(() => this.getUIContext().getRouter().back())
        Column({ space: 2 }) {
          Text(this.resultOnly ? '拍摄完成' : '水印预览')
            .fontSize(18).fontWeight(FontWeight.Bold).fontColor(Color.White)
          Text(this.resultOnly ? '照片已生成，可保存或分享' : '拖动移动 · 双指缩放 · 双击编辑')
            .fontSize(11).fontColor('#CCFFFFFF')
        }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 12 })
        if (!this.resultOnly) {
          Button('⚙').width(48).height(48).fontSize(21).type(ButtonType.Normal)
            .fontColor(Color.White).backgroundColor('#66000000').borderRadius(24)
            .onClick(() => this.showSettings = true)
        }
      }
      .width('100%').padding({ left: 18, right: 18, top: 18, bottom: 16 })
      .backgroundColor('#55000000').position({ x: 0, y: 0 })

      Column({ space: 10 }) {
        Row({ space: 12 }) {
          Column() {
            SaveButton({
              icon: SaveIconStyle.LINES,
              text: SaveDescription.SAVE_TO_GALLERY,
              buttonType: ButtonType.Capsule
            })
              .width('100%').height(52).enabled(!this.processing && !!this.previewUri)
              .fontSize(16).fontWeight(FontWeight.Bold).fontColor('#3B2117')
              .iconSize(18).iconColor('#3B2117').textIconSpace(6)
              .backgroundColor('#FFF4E8').borderRadius(26)
              .onClick((_event: ClickEvent, result: SaveButtonOnClickResult) => {
                if (result === SaveButtonOnClickResult.SUCCESS) {
                  this.save();
                  return;
                }
                this.showToast('未获得保存授权，请重试。');
              })
          }.layoutWeight(1)
          Button('分享').width(112).height(52).type(ButtonType.Normal)
            .enabled(!this.processing && !!this.previewUri).fontSize(16).fontColor(Color.White)
            .backgroundColor('#E96832').borderRadius(26).onClick(() => this.share())
        }.width('100%')
        Text(this.resultOnly ? '高清水印照片已生成' : '水印仅为实时预览，保存时生成高清照片').fontSize(11)
          .fontColor('#CCFFFFFF').textAlign(TextAlign.Center).width('100%')
      }
      .width(this.isWide() ? 620 : '92%').padding(14)
      .backgroundColor('#66000000').borderRadius(28)
      .position({ x: Math.max(0, (this.viewportWidth - (this.isWide() ? 620 : this.viewportWidth * 0.92)) / 2),
        y: Math.max(90, this.viewportHeight - 108) })

      if (this.errorMessage) {
        Text(this.errorMessage).fontSize(13).fontColor('#7A271A')
          .padding(12).backgroundColor('#FFFFE9E3').borderRadius(12)
          .position({ x: 20, y: 92 }).constraintSize({ maxWidth: 420 })
      }

      if (this.processing) {
        ProcessingProgress({ message: this.progressMessage })
      }

      if (!this.resultOnly && this.showSettings) {
        this.settingsPanel()
      }
    }
    .width('100%').height('100%').backgroundColor('#0B0E14')
    .onAreaChange((_oldValue, newValue) => {
      this.viewportWidth = Number(newValue.width);
      this.viewportHeight = Number(newValue.height);
    })
  }
}