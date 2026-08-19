import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { ImagePreview } from '../components/ImagePreview';
import { ProcessingProgress } from '../components/ProcessingProgress';
import { WatermarkConfig, WatermarkPosition } from '../models/WatermarkConfig';
import { ResultViewModel } from '../viewmodels/ResultViewModel';
import { ErrorMessageUtil } from '../utils/ErrorMessageUtil';

class ResultParams {
  sourceUri: string = '';
}

@Entry
@Component
struct ResultPage {
  @State private previewPixelMap: image.PixelMap | undefined = undefined;
  @State private text: string = '映刻 · 记录此刻';
  @State private watermarkPosition: WatermarkPosition = WatermarkPosition.BOTTOM_RIGHT;
  @State private watermarkOpacity: number = 80;
  @State private textSize: number = 4;
  @State private logoSize: number = 12;
  @State private showText: boolean = true;
  @State private showLogo: boolean = true;
  @State private processing: boolean = false;
  @State private progressMessage: string = '正在处理…';
  @State private errorMessage: string = '';
  @State private dirty: boolean = true;

  private readonly viewModel: ResultViewModel = new ResultViewModel();
  private readonly abilityContext: common.UIAbilityContext =
    this.getUIContext().getHostContext() as common.UIAbilityContext;
  private sourcePixelMap: image.PixelMap | undefined = undefined;

  aboutToAppear(): void {
    this.loadSource();
  }

  aboutToDisappear(): void {
    this.viewModel.release();
  }

  private async loadSource(): Promise<void> {
    const params = this.getUIContext().getRouter().getParams() as ResultParams;
    if (!params || !params.sourceUri) {
      this.errorMessage = '没有收到可编辑的图片。';
      return;
    }
    this.processing = true;
    this.progressMessage = '正在读取图片并校正方向…';
    try {
      const result = await this.viewModel.load(params.sourceUri);
      this.sourcePixelMap = result.pixelMap;
      this.previewPixelMap = result.pixelMap;
      await this.applyWatermark();
    } catch (error) {
      this.errorMessage = ErrorMessageUtil.from(error as object, '图片加载失败。');
    } finally {
      this.processing = false;
    }
  }

  private createConfig(): WatermarkConfig {
    const config = new WatermarkConfig();
    config.text = this.text.trim();
    config.position = this.watermarkPosition;
    config.opacity = this.watermarkOpacity / 100;
    config.textSizePercent = this.textSize;
    config.logoSizePercent = this.logoSize;
    config.showText = this.showText;
    config.showLogo = this.showLogo;
    return config;
  }

  private async applyWatermark(): Promise<void> {
    if (!this.sourcePixelMap || this.processing && !this.previewPixelMap) {
      return;
    }
    if (!this.showText && !this.showLogo) {
      this.errorMessage = '请至少保留文字或 Logo 中的一种水印。';
      return;
    }
    this.processing = true;
    this.progressMessage = '正在本地合成水印…';
    this.errorMessage = '';
    this.previewPixelMap = this.sourcePixelMap;
    try {
      this.previewPixelMap = await this.viewModel.apply(
        this.abilityContext, this.createConfig(), $r('app.media.foreground'));
      this.dirty = false;
    } catch (error) {
      this.errorMessage = ErrorMessageUtil.from(error as object, '水印合成失败。');
    } finally {
      this.processing = false;
    }
  }

  private async ensureLatest(): Promise<boolean> {
    if (this.dirty) {
      await this.applyWatermark();
    }
    return !this.dirty && !this.errorMessage;
  }

  private async save(): Promise<void> {
    if (!await this.ensureLatest()) {
      return;
    }
    this.processing = true;
    this.progressMessage = '正在编码并保存到相册…';
    try {
      await this.viewModel.save(this.abilityContext);
      this.getUIContext().getPromptAction().showToast({ message: '已另存为新的相册图片，原图未修改。' });
    } catch (error) {
      this.errorMessage = ErrorMessageUtil.from(error as object, '保存失败。');
    } finally {
      this.processing = false;
    }
  }

  private async share(): Promise<void> {
    if (!await this.ensureLatest()) {
      return;
    }
    this.processing = true;
    this.progressMessage = '正在准备系统分享…';
    try {
      await this.viewModel.share(this.abilityContext);
    } catch (error) {
      this.errorMessage = ErrorMessageUtil.from(error as object, '分享失败。');
    } finally {
      this.processing = false;
    }
  }

  private markDirty(): void {
    this.dirty = true;
    this.errorMessage = '';
  }

  @Builder
  private positionButton(label: string, value: WatermarkPosition) {
    Button(label).height(36).type(ButtonType.Normal)
      .fontSize(13).fontColor(this.watermarkPosition === value ? Color.White : '#344054')
      .backgroundColor(this.watermarkPosition === value ? '#365CF5' : '#EEF1F6')
      .onClick(() => {
        this.watermarkPosition = value;
        this.markDirty();
      })
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        Row() {
          Button('‹').type(ButtonType.Normal).onClick(() => this.getUIContext().getRouter().back())
          Text('水印出片').fontSize(22).fontWeight(FontWeight.Bold)
            .layoutWeight(1).textAlign(TextAlign.Center)
          Blank().width(52)
        }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 10 })

        Scroll() {
          Column({ space: 18 }) {
            ImagePreview({ pixelMap: this.previewPixelMap })
              .height(360)

            if (this.errorMessage) {
              Text(this.errorMessage).width('100%').fontSize(14).fontColor('#C4320A')
                .padding(12).backgroundColor('#FFF1ED').borderRadius(12)
            }

            Column({ space: 14 }) {
              Text('水印内容').fontSize(18).fontWeight(FontWeight.Bold).width('100%')
              TextInput({ text: this.text, placeholder: '输入水印文字' })
                .width('100%').maxLength(40)
                .onChange((value: string) => {
                  this.text = value;
                  this.markDirty();
                })

              Row() {
                Text('文字水印').fontSize(15).layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: this.showText })
                  .onChange((value: boolean) => {
                    this.showText = value;
                    this.markDirty();
                  })
              }.width('100%')

              Row() {
                Text('Logo 水印').fontSize(15).layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: this.showLogo })
                  .onChange((value: boolean) => {
                    this.showLogo = value;
                    this.markDirty();
                  })
              }.width('100%')

              Text(`透明度 ${Math.round(this.watermarkOpacity)}%`).fontSize(14).width('100%')
              Slider({ value: this.watermarkOpacity, min: 20, max: 100, step: 5 })
                .onChange((value: number) => {
                  this.watermarkOpacity = value;
                  this.markDirty();
                })

              Text(`文字大小 ${this.textSize.toFixed(1)}%`).fontSize(14).width('100%')
              Slider({ value: this.textSize, min: 2, max: 8, step: 0.5 })
                .onChange((value: number) => {
                  this.textSize = value;
                  this.markDirty();
                })

              Text(`Logo 大小 ${Math.round(this.logoSize)}%`).fontSize(14).width('100%')
              Slider({ value: this.logoSize, min: 6, max: 24, step: 1 })
                .onChange((value: number) => {
                  this.logoSize = value;
                  this.markDirty();
                })

              Text('位置').fontSize(14).width('100%')
              Row({ space: 6 }) {
                this.positionButton('左上', WatermarkPosition.TOP_LEFT)
                this.positionButton('右上', WatermarkPosition.TOP_RIGHT)
                this.positionButton('居中', WatermarkPosition.CENTER)
                this.positionButton('左下', WatermarkPosition.BOTTOM_LEFT)
                this.positionButton('右下', WatermarkPosition.BOTTOM_RIGHT)
              }.width('100%').justifyContent(FlexAlign.SpaceBetween)

              Button(this.dirty ? '应用水印并刷新预览' : '预览已是最新')
                .width('100%').height(48).enabled(this.dirty && !this.processing)
                .onClick(() => this.applyWatermark())
            }.width('100%').padding(18).backgroundColor('#FFFFFF').borderRadius(20)

            Row({ space: 12 }) {
              Button('保存到相册').layoutWeight(1).height(50).enabled(!this.processing)
                .onClick(() => this.save())
              Button('系统分享').layoutWeight(1).height(50).type(ButtonType.Normal)
                .backgroundColor('#172033').enabled(!this.processing).onClick(() => this.share())
            }.width('100%')

            Text('结果会另存为新文件，不覆盖原图；全部处理均在设备本地完成。')
              .fontSize(12).fontColor('#667085').textAlign(TextAlign.Center).width('100%')
          }.width('100%').padding({ left: 18, right: 18, bottom: 34 })
        }.layoutWeight(1).width('100%')
      }.width('100%').height('100%').backgroundColor('#F5F7FB')

      if (this.processing) {
        ProcessingProgress({ message: this.progressMessage })
      }
    }.width('100%').height('100%')
  }
}
