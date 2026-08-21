import { common } from '@kit.AbilityKit';
import { WatermarkElementOverlay } from '../components/WatermarkElementOverlay';
import {
  APPROXIMATE_LOCATION_PERMISSION,
  PermissionManager
} from '../common/permission/PermissionManager';
import { WatermarkBrandBadge } from '../components/WatermarkBrandBadge';
import { AppError, AppErrorCode } from '../models/AppError';
import { PermissionState } from '../models/PermissionState';
import {
  cloneWatermarkElement,
  cloneWatermarkTemplate,
  createDefaultWatermarkTemplate,
  createSourceWatermarkElement,
  createMinimalDateWatermarkTemplate,
  createTimeLocationWatermarkTemplate,
  formatWatermarkDate,
  formatWatermarkDateTime,
  isAutomaticWatermarkSource,
  watermarkElementDisplayText,
  WatermarkElementConfig,
  WatermarkElementSource,
  WatermarkElementType,
  WatermarkPreset,
  watermarkSourceLabel,
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
  @State private requestingLocation: boolean = false;
  @State private errorMessage: string = '';
  @State private viewportWidth: number = 0;
  @State private previewWidth: number = 0;
  @State private previewHeight: number = 0;
  @State private sourceImageWidth: number = 0;
  @State private sourceImageHeight: number = 0;
  @State private selectedWatermarkId: string = '';

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

  private asGalleryTemplate(source: WatermarkTemplateConfig): WatermarkTemplateConfig {
    const template = cloneWatermarkTemplate(source);
    const now = new Date();
    template.elements = template.elements.map((item: WatermarkElementConfig) => {
      const updated = cloneWatermarkElement(item);
      if (item.source === WatermarkElementSource.CAPTURE_DATE_TIME ||
        item.source === WatermarkElementSource.EDIT_DATE_TIME) {
        updated.source = WatermarkElementSource.EDIT_DATE_TIME;
        updated.text = item.id === 'preset_date' ? formatWatermarkDate(now) : formatWatermarkDateTime(now);
      } else if (item.source === WatermarkElementSource.CAPTURE_LOCATION ||
        item.source === WatermarkElementSource.EDIT_LOCATION) {
        updated.source = WatermarkElementSource.EDIT_LOCATION;
        updated.text = '正在获取编辑位置…';
      } else if (item.source === WatermarkElementSource.CAPTURE_COORDINATES ||
        item.source === WatermarkElementSource.EDIT_COORDINATES) {
        updated.source = WatermarkElementSource.EDIT_COORDINATES;
        updated.text = '正在获取编辑经纬度…';
      }
      return updated;
    });
    return template;
  }

  private requiresGalleryLocation(): boolean {
    return this.template.elements.some((item: WatermarkElementConfig) =>
      item.source === WatermarkElementSource.EDIT_LOCATION ||
      item.source === WatermarkElementSource.EDIT_COORDINATES);
  }

  private updateGalleryLocation(locationText: string, coordinateText: string): void {
    const updated = cloneWatermarkTemplate(this.template);
    updated.elements = updated.elements.map((item: WatermarkElementConfig) => {
      const next = cloneWatermarkElement(item);
      if (item.source === WatermarkElementSource.EDIT_LOCATION) {
        next.text = locationText;
      } else if (item.source === WatermarkElementSource.EDIT_COORDINATES) {
        next.text = coordinateText;
      }
      return next;
    });
    this.template = updated;
  }

  private async refreshGalleryLocation(): Promise<void> {
    if (this.requestingLocation || !this.requiresGalleryLocation()) {
      return;
    }
    this.requestingLocation = true;
    let permissionState = PermissionManager.getInstance().checkPermission(
      this.abilityContext, APPROXIMATE_LOCATION_PERMISSION);
    if (permissionState !== PermissionState.GRANTED) {
      permissionState = await PermissionManager.getInstance()
        .requestLocationPermissions(this.abilityContext);
    }
    if (permissionState !== PermissionState.GRANTED) {
      this.updateGalleryLocation('编辑位置未授权', '编辑经纬度未授权');
      this.requestingLocation = false;
      this.showToast('未获得定位权限，编辑位置无法显示');
      return;
    }
    try {
      const location = await this.locationService.getCurrentLocation();
      this.updateGalleryLocation(location.locationText, location.coordinateText);
    } catch (_) {
      this.updateGalleryLocation('编辑位置未获取', '编辑经纬度未获取');
    } finally {
      this.requestingLocation = false;
    }
  }

  private selectPreset(preset: WatermarkPreset): void {
    this.selectedPreset = preset;
    this.selectedWatermarkId = '';
    if (preset === WatermarkPreset.MINIMAL_DATE) {
      this.template = this.asGalleryTemplate(createMinimalDateWatermarkTemplate(new Date()));
      return;
    }
    if (preset === WatermarkPreset.TIME_LOCATION) {
      this.template = this.asGalleryTemplate(createTimeLocationWatermarkTemplate(
        new Date(), '正在获取编辑位置…', '正在获取编辑经纬度…'));
      this.refreshGalleryLocation();
      return;
    }
    try {
      this.template = this.asGalleryTemplate(this.settingsRepository.load(this.abilityContext).template);
      this.refreshGalleryLocation();
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
      const nextUri = await this.mediaService.selectPhoto();
      this.sourceImageWidth = 0;
      this.sourceImageHeight = 0;
      this.sourceUri = nextUri;
    } catch (error) {
      if (error instanceof AppError && error.code === AppErrorCode.USER_CANCELLED) {
        return;
      }
      this.errorMessage = ErrorMessageUtil.from(error as object, '图片导入失败');
    } finally {
      this.selecting = false;
    }
  }

  private addGalleryManualField(label: string): void {
    if (this.template.elements.length >= 8) {
      this.showToast('最多可以添加 8 个水印元素');
      return;
    }
    const updated = cloneWatermarkTemplate(this.template);
    const element = new WatermarkElementConfig(`gallery_field_${Date.now()}`, WatermarkElementType.TEXT);
    element.fieldLabel = label;
    element.text = label === '姓名' ? '请输入姓名' : '请输入内容';
    element.source = WatermarkElementSource.MANUAL;
    element.positionX = 0.08;
    element.positionY = Math.min(0.82, 0.18 + updated.elements.length * 0.1);
    element.sizePercent = 3.5;
    updated.elements = updated.elements.concat([element]);
    this.template = updated;
    this.selectedWatermarkId = element.id;
  }

  private addGallerySource(source: WatermarkElementSource): void {
    if (this.template.elements.length >= 8) {
      this.showToast('最多可以添加 8 个水印元素');
      return;
    }
    if (this.template.elements.some((item: WatermarkElementConfig) => item.source === source)) {
      this.showToast('这个信息已经添加');
      return;
    }
    const updated = cloneWatermarkTemplate(this.template);
    const element = createSourceWatermarkElement(source, `gallery_source_${Date.now()}`);
    element.positionY = Math.min(0.82, 0.18 + updated.elements.length * 0.1);
    updated.elements = updated.elements.concat([element]);
    this.template = updated;
    this.selectedWatermarkId = element.id;
    if (source === WatermarkElementSource.EDIT_LOCATION ||
      source === WatermarkElementSource.EDIT_COORDINATES) {
      this.refreshGalleryLocation();
    }
  }

  private updateSelectedGalleryText(value: string): void {
    const updated = cloneWatermarkTemplate(this.template);
    const element = updated.elements.find((item: WatermarkElementConfig) =>
      item.id === this.selectedWatermarkId);
    if (!element || isAutomaticWatermarkSource(element.source)) {
      return;
    }
    element.text = value;
    this.template = updated;
  }

  private selectedGalleryElement(): WatermarkElementConfig | undefined {
    return this.template.elements.find((item: WatermarkElementConfig) =>
      item.id === this.selectedWatermarkId);
  }

  private firstTextElement(): WatermarkElementConfig | undefined {
    return this.template.elements.find((item: WatermarkElementConfig) =>
      item.type === WatermarkElementType.TEXT && item.visible);
  }

  private openFinalResult(): void {
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
        resultOnly: true,
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
      this.showToast('暂时无法生成成品图');
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (_) {
    }
  }

  private previewImageWidth(): number {
    if (this.sourceImageWidth <= 0 || this.sourceImageHeight <= 0) {
      return this.previewWidth;
    }
    const scale = Math.min(this.previewWidth / this.sourceImageWidth,
      this.previewHeight / this.sourceImageHeight);
    return this.sourceImageWidth * scale;
  }

  private previewImageHeight(): number {
    if (this.sourceImageWidth <= 0 || this.sourceImageHeight <= 0) {
      return this.previewHeight;
    }
    const scale = Math.min(this.previewWidth / this.sourceImageWidth,
      this.previewHeight / this.sourceImageHeight);
    return this.sourceImageHeight * scale;
  }

  private exportImageWidth(): number {
    if (this.sourceImageWidth <= 0 || this.sourceImageHeight <= 0) {
      return Math.max(1, this.previewImageWidth());
    }
    const scale = Math.min(1, 3072 / Math.max(this.sourceImageWidth, this.sourceImageHeight));
    return Math.max(1, Math.round(this.sourceImageWidth * scale));
  }

  private exportImageHeight(): number {
    if (this.sourceImageWidth <= 0 || this.sourceImageHeight <= 0) {
      return Math.max(1, this.previewImageHeight());
    }
    const scale = Math.min(1, 3072 / Math.max(this.sourceImageWidth, this.sourceImageHeight));
    return Math.max(1, Math.round(this.sourceImageHeight * scale));
  }

  private previewToExportScale(): number {
    const previewImageWidth = this.previewImageWidth();
    return previewImageWidth > 0 ? previewImageWidth / this.exportImageWidth() : 1;
  }

  private previewMargin(): number {
    const exportMargin = Math.max(18,
      Math.round(Math.min(this.exportImageWidth(), this.exportImageHeight()) * 0.025));
    return exportMargin * this.previewToExportScale();
  }

  private previewFrameX(): number {
    return (this.previewWidth - this.previewImageWidth()) / 2 + this.previewMargin();
  }

  private previewFrameY(): number {
    return (this.previewHeight - this.previewImageHeight()) / 2 + this.previewMargin();
  }

  private previewFrameWidth(): number {
    return Math.max(1, this.previewImageWidth() - this.previewMargin() * 2);
  }

  private previewFrameHeight(): number {
    return Math.max(1, this.previewImageHeight() - this.previewMargin() * 2);
  }

  private clampElementScale(scale: number): number {
    return Math.min(2.5, Math.max(0.5, scale));
  }

  private previewElementSize(element: WatermarkElementConfig): number {
    const scale = this.clampElementScale(element.scaleFactor);
    const exportSize = Math.max(24,
      Math.round(this.exportImageWidth() * element.sizePercent / 100 * scale));
    return exportSize * this.previewToExportScale() / scale;
  }

  private previewTextMaxWidth(): number {
    return Math.round(this.exportImageWidth() * 0.68) * this.previewToExportScale();
  }

  private previewBrandIconSize(): number {
    const exportSize = Math.max(20,
      Math.round(this.exportImageWidth() * this.template.brandSizePercent / 100));
    return exportSize * this.previewToExportScale();
  }

  private previewBrandLabelSize(): number {
    const exportIconSize = Math.max(20,
      Math.round(this.exportImageWidth() * this.template.brandSizePercent / 100));
    return Math.max(14, Math.round(exportIconSize * 0.38)) * this.previewToExportScale();
  }

  private previewBrandPadding(): number {
    const exportLabelSize = this.previewBrandLabelSize() / this.previewToExportScale();
    return Math.max(7, Math.round(exportLabelSize * 0.32)) * this.previewToExportScale();
  }

  private previewBrandGap(): number {
    const exportLabelSize = this.previewBrandLabelSize() / this.previewToExportScale();
    return Math.max(4, Math.round(exportLabelSize * 0.22)) * this.previewToExportScale();
  }

  private previewBrandWidth(): number {
    return Math.max(this.previewBrandIconSize(), this.previewBrandLabelSize() * 6) +
      this.previewBrandPadding() * 2;
  }

  private previewBrandHeight(): number {
    return this.previewBrandPadding() * 2 + this.previewBrandIconSize() +
      this.previewBrandGap() + this.previewBrandLabelSize() * 1.28;
  }

  private elementRenderKey(element: WatermarkElementConfig): string {
    return `${element.id}:${element.type}:${element.text}:${element.imageUri}:` +
      `${Math.round(this.previewWidth)}x${Math.round(this.previewHeight)}:` +
      `${this.sourceImageWidth}x${this.sourceImageHeight}`;
  }

  private updateElementPosition(id: string, x: number, y: number): void {
    const updated = cloneWatermarkTemplate(this.template);
    const element = updated.elements.find((item: WatermarkElementConfig) => item.id === id);
    if (!element) {
      return;
    }
    element.positionX = x;
    element.positionY = y;
    this.template = updated;
  }

  private updateElementScale(id: string, scale: number): void {
    const updated = cloneWatermarkTemplate(this.template);
    const element = updated.elements.find((item: WatermarkElementConfig) => item.id === id);
    if (!element) {
      return;
    }
    element.scaleFactor = scale;
    this.template = updated;
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
  private previewCard() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.sourceUri) {
        Image(this.sourceUri).width('100%').height('100%').objectFit(ImageFit.Contain)
          .onComplete((event) => {
            if (event && event.width > 0 && event.height > 0) {
              this.sourceImageWidth = event.width;
              this.sourceImageHeight = event.height;
            }
          })
        ForEach(this.template.elements, (element: WatermarkElementConfig) => {
          if (element.visible) {
            WatermarkElementOverlay({
              elementId: element.id,
              elementType: element.type,
              text: watermarkElementDisplayText(element),
              sourceBadgeText: element.type === WatermarkElementType.TEXT && element.showSourceBadge ?
                watermarkSourceLabel(element.source) : '',
              sourceBadgeAutomatic: isAutomaticWatermarkSource(element.source),
              imageUri: element.imageUri,
              opacityValue: element.opacity,
              sizeValue: this.previewElementSize(element),
              scaleFactor: element.scaleFactor,
              positionX: element.positionX,
              positionY: element.positionY,
              frameX: this.previewFrameX(),
              frameY: this.previewFrameY(),
              frameWidth: this.previewFrameWidth(),
              frameHeight: this.previewFrameHeight(),
              textMaxWidthValue: this.previewTextMaxWidth(),
              textRenderScale: 1 / this.getUIContext().vp2px(1),
              interactionPadding: 0,
              selected: element.id === this.selectedWatermarkId,
              editable: !this.requestingLocation,
              onSelect: (id: string) => this.selectedWatermarkId = id,
              onPositionChange: (id: string, x: number, y: number) =>
                this.updateElementPosition(id, x, y),
              onScaleChange: (id: string, scale: number) => this.updateElementScale(id, scale),
              onEditRequest: (id: string) => this.selectedWatermarkId = id
            })
          }
        }, (element: WatermarkElementConfig) => this.elementRenderKey(element))
        WatermarkBrandBadge({
          iconSize: this.previewBrandIconSize(),
          badgeWidth: this.previewBrandWidth(),
          badgeHeight: this.previewBrandHeight(),
          labelSizeValue: this.previewBrandLabelSize() / this.getUIContext().vp2px(1),
          paddingValue: this.previewBrandPadding(),
          gapValue: this.previewBrandGap(),
          opacityValue: this.template.brandOpacity
        }).position({
          x: (this.previewWidth - this.previewImageWidth()) / 2 + this.previewImageWidth() -
            this.previewMargin() - this.previewBrandWidth(),
          y: (this.previewHeight - this.previewImageHeight()) / 2 + this.previewImageHeight() -
            this.previewMargin() - this.previewBrandHeight()
        })
      } else {
        Stack({ alignContent: Alignment.Center }) {
          Circle().width(210).height(210).fill('#33F6A56A')
            .position({ x: Math.max(12, this.previewWidth - 160), y: -72 })
          Circle().width(128).height(128).fill('#28E96832')
            .position({ x: -42, y: Math.max(20, this.previewHeight - 92) })
          Column({ space: 14 }) {
            Image($r('app.media.foreground')).width(82).height(82)
              .borderRadius(22).shadow({ radius: 18, color: '#30A7552C', offsetY: 7 })
            Text('选一张照片，开始设计水印').fontSize(21)
              .fontWeight(FontWeight.Bold).fontColor('#3B2117')
            Text('支持系统相册中的常见图片格式').fontSize(13).fontColor('#9A725C')
            Button('从相册选择').height(46).padding({ left: 30, right: 30 })
              .type(ButtonType.Normal).fontSize(15).fontWeight(FontWeight.Bold)
              .fontColor(Color.White).backgroundColor('#E96832').borderRadius(23)
              .enabled(!this.selecting).onClick(() => this.choosePhoto())
            Text('照片仅在本机处理').fontSize(11).fontColor('#A97960')
              .padding({ left: 11, right: 11, top: 5, bottom: 5 })
              .backgroundColor('#BFFFFFFF').borderRadius(14)
          }
        }
        .width('100%').height('100%')
        .linearGradient({ angle: 135, colors: [['#FFFFFAF5', 0.0], ['#FFFFE6D2', 1.0]] })
      }
    }
    .width('100%').height(this.isTablet() ? 520 : 360)
    .backgroundColor(this.sourceUri ? '#241B17' : '#FFF3E7').borderRadius(26).clip(true)
    .border({ width: 1, color: this.sourceUri ? '#E7CDBA' : '#F0C9A9' })
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
        if (this.selectedPreset === preset && preset === WatermarkPreset.TIME_LOCATION &&
          this.requestingLocation) {
          LoadingProgress().width(18).height(18).color('#E96832')
        } else if (this.selectedPreset === preset) {
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
                Text('可拖动、缩放水印，也可重新选择图片').fontSize(12).fontColor('#9A725C')
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
              Text('下一步生成成品图').fontSize(12).fontColor('#A07A63')
            }.width('100%')
            Row({ space: 10 }) {
              this.presetCard(WatermarkPreset.TIME_LOCATION, '●', '时间地点',
                this.requestingLocation ? '正在获取位置…' : '编辑时间、当前地点与经纬度')
              this.presetCard(WatermarkPreset.MINIMAL_DATE, '▣', '极简日期', '干净简洁的日期样式')
              this.presetCard(WatermarkPreset.CUSTOM, '✎', '自定义', '使用已保存的模板')
            }.width('100%')
          }.width('100%')

          Column({ space: 10 }) {
            Row() {
              Text('添加内容').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#3B2117')
              Blank()
              Text('最多 8 项').fontSize(11).fontColor('#A07A63')
            }.width('100%')
            Row({ space: 8 }) {
              Button('＋姓名').layoutWeight(1).height(40).type(ButtonType.Normal).fontSize(11)
                .fontColor('#78472E').backgroundColor('#FFF0E3').borderRadius(13)
                .onClick(() => this.addGalleryManualField('姓名'))
              Button('＋日期时间').layoutWeight(1).height(40).type(ButtonType.Normal).fontSize(11)
                .fontColor('#356149').backgroundColor('#E9F3EC').borderRadius(13)
                .onClick(() => this.addGallerySource(WatermarkElementSource.EDIT_DATE_TIME))
              Button('＋地点').layoutWeight(1).height(40).type(ButtonType.Normal).fontSize(11)
                .fontColor('#356149').backgroundColor('#E9F3EC').borderRadius(13)
                .onClick(() => this.addGallerySource(WatermarkElementSource.EDIT_LOCATION))
              Button('＋自定义').layoutWeight(1).height(40).type(ButtonType.Normal).fontSize(11)
                .fontColor('#78472E').backgroundColor('#FFF0E3').borderRadius(13)
                .onClick(() => this.addGalleryManualField('自定义字段'))
            }.width('100%')
            if (this.selectedGalleryElement()) {
              if (isAutomaticWatermarkSource(this.selectedGalleryElement()?.source ??
                WatermarkElementSource.MANUAL)) {
                Text(`◆ ${watermarkSourceLabel(this.selectedGalleryElement()?.source ??
                  WatermarkElementSource.MANUAL)} · 内容由系统获取，不可手动修改`)
                  .width('100%').fontSize(11).fontColor('#47745D')
                  .padding(12).backgroundColor('#EAF4ED').borderRadius(13)
              } else if (this.selectedGalleryElement()?.type === WatermarkElementType.TEXT) {
                TextArea({ text: this.selectedGalleryElement()?.text ?? '', placeholder: '输入内容' })
                  .width('100%').height(72).maxLength(100).backgroundColor('#FFF8F1')
                  .onChange((value: string) => this.updateSelectedGalleryText(value))
                Text('✎ 手动填写 · 成品会保留来源标识').fontSize(11).fontColor('#9B623E').width('100%')
              }
            }
          }.width('100%').padding(16).backgroundColor('#FFFDF9').borderRadius(20)
            .border({ width: 1, color: '#EED7C5', radius: 20 })

          if (this.errorMessage) {
            Text(this.errorMessage).fontSize(13).fontColor('#8C3020').width('100%')
              .padding(12).backgroundColor('#FFFFE9E3').borderRadius(12)
          }

          Button(!this.sourceUri ? '请先导入图片' :
            this.requestingLocation ? '正在获取位置…' : '下一步')
            .width('100%').height(54).type(ButtonType.Normal)
            .fontSize(17).fontWeight(FontWeight.Bold).fontColor(Color.White)
            .backgroundColor(this.sourceUri && !this.requestingLocation ? '#E96832' : '#D9B8A5')
            .borderRadius(27).enabled(!!this.sourceUri && !this.requestingLocation)
            .onClick(() => this.openFinalResult())
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
