import { common } from '@kit.AbilityKit';
import { WatermarkBrandBadge } from '../components/WatermarkBrandBadge';
import { AppError, AppErrorCode } from '../models/AppError';
import {
  cloneWatermarkElement,
  createDefaultWatermarkTemplate,
  createMinimalDateWatermarkTemplate,
  createTimeLocationWatermarkTemplate,
  WatermarkElementConfig,
  WatermarkElementType,
  WatermarkPreset,
  WatermarkTemplateConfig
} from '../models/WatermarkTemplate';
import { MediaService } from '../services/MediaService';
import { SettingsRepository } from '../services/SettingsRepository';
import { WatermarkLocationService } from '../services/WatermarkLocationService';
import { ErrorMessageUtil } from '../utils/ErrorMessageUtil';

@Entry
@Component
struct GalleryWatermarkPage {
  @State private sourceUri: string = '';
  @State private selectedPreset: WatermarkPreset = WatermarkPreset.CUSTOM;
  @State private template: WatermarkTemplateConfig = createDefaultWatermarkTemplate();
  @State private selecting: boolean = false;
  @State private errorMessage: string = '';
  @State private viewportWidth: number = 0;
  @State private previewWidth: number = 0;
  @State private previewHeight: number = 0;

  private readonly mediaService: MediaService = new MediaService();
  private readonly settingsRepository: SettingsRepository = new SettingsRepository();
  private readonly locationService: WatermarkLocationService = WatermarkLocationService.getInstance();
  private readonly abilityContext: common.UIAbilityContext =
    this.getUIContext().getHostContext() as common.UIAbilityContext;

  aboutToAppear(): void {
    this.selectPreset(WatermarkPreset.CUSTOM);
  }

  private isTablet(): boolean {
    return this.viewportWidth >= 600;
  }

  private selectPreset(preset: WatermarkPreset): void {
    this.selectedPreset = preset;
    if (preset === WatermarkPreset.MINIMAL_DATE) {
      this.template = createMinimalDateWatermarkTemplate(new Date());
      return;
    }
    if (preset === WatermarkPreset.TIME_LOCATION) {
      const cached = this.locationService.getCachedLocation();
      this.template = createTimeLocationWatermarkTemplate(new Date(),
        cached ? cached.locationText : '当前位置',
        cached ? cached.coordinateText : '经纬度');
      return;
    }
    try {
      this.template = this.settingsRepository.load(this.abilityContext).template;
    } catch (_) {
      this.template = createDefaultWatermarkTemplate();
    }
  }

  private async choosePhoto(): Promise<void> {
    if (this.selecting) {
      return;
    }
    this.selecting = true;
    this.errorMessage = '';
    try {
      this.sourceUri = await this.mediaService.selectPhoto();
    } catch (error) {
      if (error instanceof AppError && error.code === AppErrorCode.USER_CANCELLED) {
        return;
      }
      this.errorMessage = ErrorMessageUtil.from(error as object, '图片导入失败');
    } finally {
      this.selecting = false;
    }
  }

  private firstTextElement(): WatermarkElementConfig | undefined {
    return this.template.elements.find((item: WatermarkElementConfig) =>
      item.type === WatermarkElementType.TEXT && item.visible);
  }

  private continueEditing(): void {
    if (!this.sourceUri) {
      this.showToast('请先导入一张图片');
      return;
    }
    const firstText = this.firstTextElement();
    try {
      this.getUIContext().getRouter().pushUrl({
      url: 'pages/ResultPage',
      params: {
        sourceUri: this.sourceUri,
        resultOnly: false,
        resultTitle: '相册加水印',
        watermarkText: firstText ? firstText.text : '',
        watermarkOpacity: firstText ? Math.round(firstText.opacity * 100) : 88,
        textSizePercent: firstText ? firstText.sizePercent : 4,
        scaleFactor: firstText ? firstText.scaleFactor : 1,
        showText: !!firstText,
        showLogo: true,
        positionX: firstText ? firstText.positionX : 0.08,
        positionY: firstText ? firstText.positionY : 0.72,
        watermarkElements: this.template.elements.map((item: WatermarkElementConfig) =>
          cloneWatermarkElement(item)),
        brandSizePercent: this.template.brandSizePercent,
        brandOpacity: this.template.brandOpacity
        }
      });
    } catch (_) {
      this.showToast('暂时无法打开水印编辑');
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (_) {
    }
  }

  private elementSize(element: WatermarkElementConfig): number {
    const base = this.previewWidth * element.sizePercent / 100 * element.scaleFactor;
    return Math.max(element.type === WatermarkElementType.IMAGE ? 22 : 12, base);
  }

  private elementX(element: WatermarkElementConfig): number {
    return 16 + element.positionX * Math.max(1, this.previewWidth - 152);
  }

  private elementY(element: WatermarkElementConfig): number {
    return 16 + element.positionY * Math.max(1, this.previewHeight - 84);
  }

  @Builder
  private header() {
    Row({ space: 14 }) {
      Button('‹').width(46).height(46).fontSize(27).type(ButtonType.Normal)
        .fontColor('#5A3829').backgroundColor('#FFF0E3').borderRadius(23)
        .onClick(() => this.getUIContext().getRouter().back())
      Column({ space: 3 }) {
        Text('相册加水印').fontSize(this.isTablet() ? 27 : 23)
          .fontWeight(FontWeight.Bold).fontColor('#3B2117')
        Text('导入图片，挑选喜欢的水印设计').fontSize(13).fontColor('#9A725C')
      }.alignItems(HorizontalAlign.Start)
      Blank()
      Text('本地处理').fontSize(12).fontColor('#B45A31')
        .padding({ left: 11, right: 11, top: 7, bottom: 7 })
        .backgroundColor('#FFE9D7').borderRadius(16)
    }.width('100%')
  }

  @Builder
  private watermarkElement(element: WatermarkElementConfig) {
    if (element.type === WatermarkElementType.IMAGE) {
      if (element.imageUri) {
        Image(element.imageUri)
          .width(this.elementSize(element)).height(this.elementSize(element))
          .objectFit(ImageFit.Contain).borderRadius(6).opacity(element.opacity)
          .position({ x: this.elementX(element), y: this.elementY(element) })
      } else {
        Text('图').fontSize(12).fontColor(Color.White)
          .width(this.elementSize(element)).height(this.elementSize(element))
          .textAlign(TextAlign.Center).backgroundColor('#99000000').borderRadius(6)
          .position({ x: this.elementX(element), y: this.elementY(element) })
      }
    } else {
      Text(element.text).fontSize(this.elementSize(element)).fontWeight(FontWeight.Bold)
        .fontColor(Color.White).maxLines(5)
        .constraintSize({ maxWidth: Math.max(120, this.previewWidth * 0.68) })
        .padding({ left: 7, right: 7, top: 4, bottom: 4 })
        .backgroundColor('#8A1E1510').borderRadius(6)
        .textShadow({ radius: 2, color: '#66000000', offsetY: 1 })
        .opacity(element.opacity)
        .position({ x: this.elementX(element), y: this.elementY(element) })
    }
  }

  @Builder
  private previewCard() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.sourceUri) {
        Image(this.sourceUri).width('100%').height('100%').objectFit(ImageFit.Contain)
        ForEach(this.template.elements, (element: WatermarkElementConfig) => {
          if (element.visible) {
            this.watermarkElement(element)
          }
        }, (element: WatermarkElementConfig) => element.id)
        WatermarkBrandBadge({
          iconSize: 24,
          badgeWidth: 92,
          badgeHeight: 62,
          opacityValue: this.template.brandOpacity
        }).position({
          x: Math.max(12, this.previewWidth - 104),
          y: Math.max(12, this.previewHeight - 74)
        })
      } else {
        Column({ space: 14 }) {
          Text('▧').fontSize(46).fontColor('#E96832')
            .width(86).height(86).textAlign(TextAlign.Center)
            .backgroundColor('#FFF0E3').borderRadius(24)
          Text('导入一张图片').fontSize(21).fontWeight(FontWeight.Bold).fontColor('#3B2117')
          Text('支持系统相册中的常见图片格式').fontSize(13).fontColor('#9A725C')
          Button('选择图片').height(46).padding({ left: 28, right: 28 })
            .type(ButtonType.Normal).fontSize(15).fontWeight(FontWeight.Bold)
            .fontColor(Color.White).backgroundColor('#E96832').borderRadius(23)
            .enabled(!this.selecting).onClick(() => this.choosePhoto())
        }
      }
    }
    .width('100%').height(this.isTablet() ? 520 : 360)
    .backgroundColor('#241B17').borderRadius(26).clip(true)
    .border({ width: 1, color: '#E7CDBA' })
    .onAreaChange((_oldValue, newValue) => {
      this.previewWidth = Number(newValue.width);
      this.previewHeight = Number(newValue.height);
    })
  }

  @Builder
  private presetCard(preset: WatermarkPreset, icon: string, title: string, description: string) {
    Column({ space: 7 }) {
      Row() {
        Text(icon).fontSize(20).width(38).height(38).textAlign(TextAlign.Center)
          .backgroundColor(this.selectedPreset === preset ? '#FFD7B3' : '#F4E7DB').borderRadius(19)
        Blank()
        if (this.selectedPreset === preset) {
          Text('✓').fontSize(17).fontWeight(FontWeight.Bold).fontColor('#E96832')
        }
      }.width('100%')
      Text(title).fontSize(15).fontWeight(FontWeight.Bold).fontColor('#3B2117').width('100%')
      Text(description).fontSize(11).fontColor('#9A725C').maxLines(2).width('100%')
    }
    .layoutWeight(1).height(126).padding(14).alignItems(HorizontalAlign.Start)
    .backgroundColor(this.selectedPreset === preset ? '#FFF0E2' : '#FFFDF9')
    .borderRadius(20)
    .border({ width: this.selectedPreset === preset ? 2 : 1,
      color: this.selectedPreset === preset ? '#F19A63' : '#EEDBCB' })
    .onClick(() => this.selectPreset(preset))
  }

  build() {
    Column() {
      Scroll() {
        Column({ space: 22 }) {
          this.header()
          this.previewCard()

          if (this.sourceUri) {
            Row() {
              Column({ space: 3 }) {
                Text('已导入图片').fontSize(15).fontWeight(FontWeight.Bold).fontColor('#3B2117')
                Text('可重新选择，不会修改原图').fontSize(12).fontColor('#9A725C')
              }.alignItems(HorizontalAlign.Start)
              Blank()
              Button(this.selecting ? '正在打开…' : '重新选图')
                .height(40).type(ButtonType.Normal).fontSize(13)
                .fontColor('#B5532C').backgroundColor('#FFF0E3').borderRadius(20)
                .enabled(!this.selecting).onClick(() => this.choosePhoto())
            }.width('100%')
          }

          Column({ space: 12 }) {
            Row() {
              Text('选择水印设计').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#3B2117')
              Blank()
              Text('下一步仍可编辑').fontSize(12).fontColor('#A07A63')
            }.width('100%')
            Row({ space: 10 }) {
              this.presetCard(WatermarkPreset.TIME_LOCATION, '●', '时间地点', '时间、地点与经纬度')
              this.presetCard(WatermarkPreset.MINIMAL_DATE, '▣', '极简日期', '干净简洁的日期样式')
              this.presetCard(WatermarkPreset.CUSTOM, '✎', '自定义', '使用已保存的模板')
            }.width('100%')
          }.width('100%')

          if (this.errorMessage) {
            Text(this.errorMessage).fontSize(13).fontColor('#8C3020').width('100%')
              .padding(12).backgroundColor('#FFFFE9E3').borderRadius(12)
          }

          Button(this.sourceUri ? '继续编辑水印' : '请先导入图片')
            .width('100%').height(54).type(ButtonType.Normal)
            .fontSize(17).fontWeight(FontWeight.Bold).fontColor(Color.White)
            .backgroundColor(this.sourceUri ? '#E96832' : '#D9B8A5').borderRadius(27)
            .enabled(!!this.sourceUri).onClick(() => this.continueEditing())
          Text('图片与水印处理均在本机完成').fontSize(12).fontColor('#A07A63')
        }
        .width('100%').constraintSize({ maxWidth: 980 })
        .padding({
          left: this.isTablet() ? 34 : 18,
          right: this.isTablet() ? 34 : 18,
          top: this.isTablet() ? 28 : 20,
          bottom: 32
        })
      }.width('100%').height('100%')
    }
    .width('100%').height('100%').backgroundColor('#FFF8F0')
    .onAreaChange((_oldValue, newValue) => {
      this.viewportWidth = Number(newValue.width);
    })
  }
}
