import { common } from '@kit.AbilityKit';
import { WatermarkBrandBadge } from '../components/WatermarkBrandBadge';
import { WatermarkElementOverlay } from '../components/WatermarkElementOverlay';
import {
  cloneWatermarkElement,
  cloneWatermarkTemplate,
  createDefaultWatermarkTemplate,
  WatermarkElementConfig,
  WatermarkElementType,
  WatermarkTemplateConfig
} from '../models/WatermarkTemplate';
import { MediaService } from '../services/MediaService';
import { SettingsRepository, WatermarkDefaults } from '../services/SettingsRepository';
import { ErrorMessageUtil } from '../utils/ErrorMessageUtil';

@Entry
@Component
struct SettingsPage {
  @State private currentBreakpoint: string = 'xs';
  @State private elements: WatermarkElementConfig[] = [];
  @State private selectedId: string = '';
  @State private brandSizePercent: number = 2.8;
  @State private brandOpacity: number = 0.78;
  @State private previewWidth: number = 0;
  @State private previewHeight: number = 0;
  @State private dirty: boolean = false;
  @State private loading: boolean = true;
  @State private showExitDialog: boolean = false;

  private readonly repository: SettingsRepository = new SettingsRepository();
  private readonly mediaService: MediaService = new MediaService();
  private readonly abilityContext: common.UIAbilityContext =
    this.getUIContext().getHostContext() as common.UIAbilityContext;

  aboutToAppear(): void {
    this.loadSettings();
  }

  onBackPress(): boolean {
    if (this.showExitDialog) {
      this.showExitDialog = false;
      return true;
    }
    this.requestExit();
    return true;
  }

  private isExpanded(): boolean {
    return this.currentBreakpoint === 'md';
  }

  private loadSettings(): void {
    try {
      const settings = this.repository.load(this.abilityContext);
      const template = cloneWatermarkTemplate(settings.template);
      this.elements = template.elements;
      this.brandSizePercent = template.brandSizePercent;
      this.brandOpacity = template.brandOpacity;
      this.selectedId = this.elements.length > 0 ? this.elements[0].id : '';
      this.dirty = false;
    } catch (error) {
      this.showToast(ErrorMessageUtil.from(error as object, '设置读取失败。'));
      this.applyTemplate(createDefaultWatermarkTemplate());
      this.dirty = false;
    } finally {
      this.loading = false;
    }
  }

  private applyTemplate(template: WatermarkTemplateConfig): void {
    const copy = cloneWatermarkTemplate(template);
    this.elements = copy.elements;
    this.brandSizePercent = copy.brandSizePercent;
    this.brandOpacity = copy.brandOpacity;
    this.selectedId = this.elements.length > 0 ? this.elements[0].id : '';
  }

  private selectedIndex(): number {
    return this.elements.findIndex((item: WatermarkElementConfig) => item.id === this.selectedId);
  }

  private currentSettings(): WatermarkDefaults {
    const settings = new WatermarkDefaults();
    settings.template.elements = this.elements.map((item: WatermarkElementConfig) => cloneWatermarkElement(item));
    settings.template.brandSizePercent = this.brandSizePercent;
    settings.template.brandOpacity = this.brandOpacity;
    const firstText = settings.template.elements.find(
      (item: WatermarkElementConfig) => item.type === WatermarkElementType.TEXT);
    settings.text = firstText?.text ?? '';
    settings.showText = firstText?.visible ?? false;
    settings.showLogo = true;
    settings.opacity = Math.round((firstText?.opacity ?? 0.88) * 100);
    return settings;
  }

  private save(closeAfterSave: boolean = false): void {
    try {
      this.repository.save(this.abilityContext, this.currentSettings());
      this.dirty = false;
      this.showToast('默认水印模板已保存');
      if (closeAfterSave) {
        this.showExitDialog = false;
        this.getUIContext().getRouter().back();
      }
    } catch (error) {
      this.showToast(ErrorMessageUtil.from(error as object, '设置保存失败。'));
    }
  }

  private requestExit(): void {
    if (!this.dirty) {
      this.getUIContext().getRouter().back();
      return;
    }
    this.showExitDialog = true;
  }

  private discardAndExit(): void {
    this.showExitDialog = false;
    this.getUIContext().getRouter().back();
  }

  private markDirty(): void {
    this.dirty = true;
  }

  private replaceElement(updated: WatermarkElementConfig): void {
    this.elements = this.elements.map((item: WatermarkElementConfig) =>
      item.id === updated.id ? updated : item);
    this.markDirty();
  }

  private updateVisibility(value: boolean): void {
    const index = this.selectedIndex();
    if (index < 0 || this.elements[index].visible === value) {
      return;
    }
    const updated = cloneWatermarkElement(this.elements[index]);
    updated.visible = value;
    this.replaceElement(updated);
  }

  private updateText(value: string): void {
    const index = this.selectedIndex();
    if (index < 0 || this.elements[index].text === value) {
      return;
    }
    const updated = cloneWatermarkElement(this.elements[index]);
    updated.text = value;
    this.replaceElement(updated);
  }

  private updateSize(value: number): void {
    const index = this.selectedIndex();
    if (index < 0 || Math.abs(this.elements[index].sizePercent - value) < 0.001) {
      return;
    }
    const updated = cloneWatermarkElement(this.elements[index]);
    updated.sizePercent = value;
    this.replaceElement(updated);
  }

  private updateOpacity(value: number): void {
    const index = this.selectedIndex();
    if (index < 0 || Math.abs(this.elements[index].opacity * 100 - value) < 0.001) {
      return;
    }
    const updated = cloneWatermarkElement(this.elements[index]);
    updated.opacity = value / 100;
    this.replaceElement(updated);
  }

  private updatePosition(id: string, x: number, y: number): void {
    const index = this.elements.findIndex((item: WatermarkElementConfig) => item.id === id);
    if (index < 0) {
      return;
    }
    const updated = cloneWatermarkElement(this.elements[index]);
    updated.positionX = x;
    updated.positionY = y;
    this.replaceElement(updated);
  }

  private updateScale(id: string, scale: number): void {
    const index = this.elements.findIndex((item: WatermarkElementConfig) => item.id === id);
    if (index < 0) {
      return;
    }
    const updated = cloneWatermarkElement(this.elements[index]);
    updated.scaleFactor = scale;
    this.replaceElement(updated);
  }

  private selectElement(id: string): void {
    this.selectedId = id;
  }

  private addText(): void {
    if (this.elements.length >= 8) {
      this.showToast('最多可以添加 8 个水印元素');
      return;
    }
    const element = new WatermarkElementConfig(`text_${Date.now()}`, WatermarkElementType.TEXT);
    element.text = '新的文字';
    element.positionX = 0.12 + this.elements.length * 0.04;
    element.positionY = 0.18 + this.elements.length * 0.05;
    element.sizePercent = 3.5;
    this.elements = this.elements.concat([element]);
    this.selectedId = element.id;
    this.markDirty();
  }

  private async addImage(): Promise<void> {
    if (this.elements.length >= 8) {
      this.showToast('最多可以添加 8 个水印元素');
      return;
    }
    try {
      const uri = await this.mediaService.selectPhoto();
      const element = new WatermarkElementConfig(`image_${Date.now()}`, WatermarkElementType.IMAGE);
      element.imageUri = uri;
      element.positionX = 0.12 + this.elements.length * 0.04;
      element.positionY = 0.18 + this.elements.length * 0.05;
      element.sizePercent = 11;
      element.opacity = 0.9;
      this.elements = this.elements.concat([element]);
      this.selectedId = element.id;
      this.markDirty();
    } catch (error) {
      const message = ErrorMessageUtil.from(error as object, '没有添加图片。');
      if (message !== '未选择照片。') {
        this.showToast(message);
      }
    }
  }

  private async replaceSelectedImage(): Promise<void> {
    const index = this.selectedIndex();
    if (index < 0 || this.elements[index].type !== WatermarkElementType.IMAGE) {
      return;
    }
    try {
      const uri = await this.mediaService.selectPhoto();
      const updated = cloneWatermarkElement(this.elements[index]);
      updated.imageUri = uri;
      this.replaceElement(updated);
    } catch (_) {
    }
  }

  private deleteSelected(): void {
    const index = this.selectedIndex();
    if (index < 0) {
      return;
    }
    if (this.elements.length === 1) {
      this.showToast('至少保留一个可编辑水印；映刻标识会始终显示');
      return;
    }
    this.elements = this.elements.filter((item: WatermarkElementConfig) => item.id !== this.selectedId);
    this.selectedId = this.elements[0].id;
    this.markDirty();
  }

  private resetDefaults(): void {
    this.applyTemplate(createDefaultWatermarkTemplate());
    this.markDirty();
    this.showToast('已恢复默认模板，退出时记得保存');
  }

  private setPosition(x: number, y: number): void {
    if (this.selectedId.length > 0) {
      this.updatePosition(this.selectedId, x, y);
    }
  }

  private previewElementSize(element: WatermarkElementConfig): number {
    const percentSize = this.previewWidth * element.sizePercent / 100;
    return element.type === WatermarkElementType.IMAGE ? Math.max(30, percentSize) : Math.max(13, percentSize);
  }

  private elementRenderKey(element: WatermarkElementConfig): string {
    return element.id;
  }

  private brandSize(): number {
    return Math.max(24, this.previewWidth * this.brandSizePercent / 100);
  }

  private brandBadgeWidth(): number {
    return Math.max(92, this.brandSize() + 64);
  }

  private brandBadgeHeight(): number {
    return Math.max(62, this.brandSize() + 36);
  }
  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (_) {
    }
  }

  @Builder
  private previewBackdrop() {
    Stack() {
      Image($r('app.media.settings_preview_lakeside'))
        .width('100%').height('100%').objectFit(ImageFit.Cover)
      Column()
        .width('100%').height('100%')
        .linearGradient({
          angle: 180,
          colors: [['#08000000', 0.0], ['#14000000', 0.58], ['#3D120B07', 1.0]]
        })
      Text('默认预览画面').fontSize(11).fontColor('#F5FFFFFF')
        .padding({ left: 10, right: 10, top: 5, bottom: 5 })
        .backgroundColor('#66332119').borderRadius(12).position({ x: 16, y: 16 })
    }.width('100%').height('100%')
  }

  @Builder
  private watermarkPreview() {
    Stack() {
      this.previewBackdrop()
      ForEach(this.elements, (element: WatermarkElementConfig) => {
        if (element.visible) {
          WatermarkElementOverlay({
            elementId: element.id,
            elementType: element.type,
            text: element.text,
            imageUri: element.imageUri,
            opacityValue: element.opacity,
            sizeValue: this.previewElementSize(element),
            scaleFactor: element.scaleFactor,
            positionX: element.positionX,
            positionY: element.positionY,
            frameX: 16,
            frameY: 16,
            frameWidth: Math.max(1, this.previewWidth - 32),
            frameHeight: Math.max(1, this.previewHeight - 32),
            selected: element.id === this.selectedId,
            editable: true,
            onSelect: (id: string) => this.selectElement(id),
            onPositionChange: (id: string, x: number, y: number) => this.updatePosition(id, x, y),
            onScaleChange: (id: string, scale: number) => this.updateScale(id, scale),
            onEditRequest: (id: string) => this.selectElement(id)
          })
        }
      }, (element: WatermarkElementConfig) => this.elementRenderKey(element))
      WatermarkBrandBadge({
        iconSize: this.brandSize(),
        badgeWidth: this.brandBadgeWidth(),
        badgeHeight: this.brandBadgeHeight(),
        opacityValue: this.brandOpacity
      })
      .position({
        x: Math.max(12, this.previewWidth - this.brandBadgeWidth() - 18),
        y: Math.max(12, this.previewHeight - this.brandBadgeHeight() - 18)
      })
    }
    .width('100%').height(this.isExpanded() ? 470 : 320)
    .clip(true).borderRadius(26)
    .border({ width: 1, color: '#E4C9B2', radius: 26 })
    .shadow({ radius: 24, color: '#28000000', offsetY: 10 })
    .onAreaChange((_oldValue, newValue) => {
      this.previewWidth = Number(newValue.width);
      this.previewHeight = Number(newValue.height);
    })
  }

  @Builder
  private elementSelector() {
    Column({ space: 10 }) {
      Row() {
        Text('水印元素').fontSize(15).fontWeight(FontWeight.Bold).fontColor('#4A3025')
        Blank()
        Text(`${this.elements.length}/8`).fontSize(12).fontColor('#A07A63')
      }.width('100%')
      List({ space: 8 }) {
        ForEach(this.elements, (element: WatermarkElementConfig, index: number) => {
          ListItem() {
            Row({ space: 7 }) {
              Text(element.type === WatermarkElementType.TEXT ? '文' : '图')
                .fontSize(12).fontWeight(FontWeight.Bold)
                .width(28).height(28).textAlign(TextAlign.Center)
                .fontColor(element.id === this.selectedId ? Color.White : '#8A604A')
                .backgroundColor(element.id === this.selectedId ? '#E96832' : '#F4E5D8').borderRadius(14)
              Text(element.type === WatermarkElementType.TEXT ?
                (element.text.length > 0 ? element.text : '空文字') : `图片 ${index + 1}`)
                .fontSize(12).fontColor('#5A3829').maxLines(1)
            }
            .height(42).padding({ left: 8, right: 12 })
            .backgroundColor(element.id === this.selectedId ? '#FFF0E3' : '#FFFDF9')
            .borderRadius(15)
            .border({ width: 1, color: element.id === this.selectedId ? '#EAA070' : '#EEDBCB', radius: 15 })
            .onClick(() => this.selectElement(element.id))
          }
        }, (element: WatermarkElementConfig) => element.id)
      }.width('100%').height(48).listDirection(Axis.Horizontal).scrollBar(BarState.Off)
    }.width('100%')
  }

  @Builder
  private sliderRow(title: string, valueText: string, value: number, min: number, max: number, step: number,
    onChange: (value: number) => void) {
    Column({ space: 6 }) {
      Row() {
        Text(title).fontSize(14).fontWeight(FontWeight.Medium).fontColor('#5A3829')
        Blank()
        Text(valueText).fontSize(12).fontColor('#E96832')
      }.width('100%')
      Slider({ value: value, min: min, max: max, step: step })
        .selectedColor('#E96832').trackColor('#EBD4C2').onChange(onChange)
    }.width('100%')
  }

  @Builder
  private brandRow() {
    Row({ space: 12 }) {
      Image($r('app.media.startIcon')).width(34).height(34).borderRadius(8).opacity(this.brandOpacity)
      Column({ space: 3 }) {
        Text('映刻标识').fontSize(15).fontWeight(FontWeight.Bold).fontColor('#4A3025')
        Text('固定以小尺寸显示，不占用水印编辑区域').fontSize(11).fontColor('#A07A63')
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text('始终显示').fontSize(11).fontColor('#B45A31')
        .padding({ left: 9, right: 9, top: 5, bottom: 5 })
        .backgroundColor('#FFE9D7').borderRadius(12)
    }.width('100%').padding(12).backgroundColor('#FFF5EA').borderRadius(16)
  }

  @Builder
  private selectedEditor() {
    if (this.selectedIndex() >= 0) {
      Column({ space: 16 }) {
        Row() {
          Text(this.elements[this.selectedIndex()].type === WatermarkElementType.TEXT ? '显示文字' : '显示图片')
            .fontSize(14).fontColor('#5A3829').layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.elements[this.selectedIndex()].visible })
            .selectedColor('#E96832').onChange((value: boolean) => this.updateVisibility(value))
        }.width('100%')

        if (this.elements[this.selectedIndex()].type === WatermarkElementType.TEXT) {
          Column({ space: 7 }) {
            Text('文字内容').fontSize(13).fontColor('#6F4C3A').width('100%')
            TextArea({ text: this.elements[this.selectedIndex()].text, placeholder: '输入水印文字，回车可换行' })
              .width('100%').height(88).maxLength(120).fontSize(14).fontColor('#3B2117')
              .backgroundColor('#FFF9F3').borderRadius(14)
              .border({ width: 1, color: '#ECD4C1', radius: 14 })
              .onChange((value: string) => this.updateText(value))
          }.width('100%')
          this.sliderRow('文字大小', `${this.elements[this.selectedIndex()].sizePercent.toFixed(1)}%`,
            this.elements[this.selectedIndex()].sizePercent, 2, 10, 0.5,
            (value: number) => this.updateSize(value))
        } else {
          Row({ space: 12 }) {
            Image(this.elements[this.selectedIndex()].imageUri).width(58).height(58)
              .objectFit(ImageFit.Cover).borderRadius(12)
            Column({ space: 5 }) {
              Text('自定义图片').fontSize(14).fontWeight(FontWeight.Medium).fontColor('#5A3829')
              Text('默认以小尺寸插入，可拖动和缩放').fontSize(11).fontColor('#A07A63')
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Button('更换').height(34).type(ButtonType.Normal).fontSize(12)
              .fontColor('#A24C27').backgroundColor('#FFE9D7').borderRadius(12)
              .onClick(() => this.replaceSelectedImage())
          }.width('100%')
          this.sliderRow('图片大小', `${Math.round(this.elements[this.selectedIndex()].sizePercent)}%`,
            this.elements[this.selectedIndex()].sizePercent, 5, 30, 1,
            (value: number) => this.updateSize(value))
        }

        this.sliderRow('透明度', `${Math.round(this.elements[this.selectedIndex()].opacity * 100)}%`,
          this.elements[this.selectedIndex()].opacity * 100, 20, 100, 5,
          (value: number) => this.updateOpacity(value))

        Row({ space: 8 }) {
          Button('左下').layoutWeight(1).height(38).type(ButtonType.Normal).fontSize(12)
            .fontColor('#6F4C3A').backgroundColor('#FFF0E3').borderRadius(12)
            .onClick(() => this.setPosition(0.06, 0.82))
          Button('居中').layoutWeight(1).height(38).type(ButtonType.Normal).fontSize(12)
            .fontColor('#6F4C3A').backgroundColor('#FFF0E3').borderRadius(12)
            .onClick(() => this.setPosition(0.5, 0.5))
          Button('右下').layoutWeight(1).height(38).type(ButtonType.Normal).fontSize(12)
            .fontColor('#6F4C3A').backgroundColor('#FFF0E3').borderRadius(12)
            .onClick(() => this.setPosition(0.9, 0.82))
        }.width('100%')
      }.width('100%')
    }
  }

  @Builder
  private editorPanel() {
    Column({ space: 16 }) {
      this.brandRow()
      Divider().color('#F0D8C4')
      this.elementSelector()
      this.selectedEditor()
      Row({ space: 10 }) {
        Button('+ 插入文字').layoutWeight(1).height(42).type(ButtonType.Normal).fontSize(13)
          .fontColor('#A44D28').backgroundColor('#FFEBDD').borderRadius(14)
          .onClick(() => this.addText())
        Button('+ 插入图片').layoutWeight(1).height(42).type(ButtonType.Normal).fontSize(13)
          .fontColor('#A44D28').backgroundColor('#FFEBDD').borderRadius(14)
          .onClick(() => this.addImage())
      }.width('100%')
      Row({ space: 10 }) {
        Button('删除当前水印').layoutWeight(1).height(40).type(ButtonType.Normal).fontSize(12)
          .fontColor('#A24C3A').backgroundColor('#FFF5F0').borderRadius(13)
          .onClick(() => this.deleteSelected())
        Button('恢复默认设置').layoutWeight(1).height(40).type(ButtonType.Normal).fontSize(12)
          .fontColor('#6F4C3A').backgroundColor('#FFF3E7').borderRadius(13)
          .onClick(() => this.resetDefaults())
      }.width('100%')
      Text('在预览画面中拖动水印改变位置，双指缩放改变大小。保存后，新打开的相机会使用这套模板。')
        .width('100%').fontSize(11).lineHeight(17).fontColor('#9A725C')
    }
    .width('100%').padding(this.isExpanded() ? 22 : 18)
    .backgroundColor('#FFFDF9').borderRadius(24)
    .border({ width: 1, color: '#EED7C5', radius: 24 })
  }

  @Builder
  private exitConfirmOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      Column().width('100%').height('100%').backgroundColor('#730F0906')
      Column({ space: 16 }) {
        Row({ space: 12 }) {
          Image($r('app.media.startIcon')).width(44).height(44).borderRadius(12)
          Column({ space: 3 }) {
            Text('保存水印编辑').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#3B2117')
            Text('将作为以后拍摄的默认样式').fontSize(12).fontColor('#A07A63')
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Button('×').width(34).height(34).fontSize(22).type(ButtonType.Normal)
            .fontColor('#7A5A49').backgroundColor('#FFF0E3').borderRadius(17)
            .onClick(() => this.showExitDialog = false)
        }.width('100%')

        Column({ space: 9 }) {
          Text('要保存这次编辑吗？').fontSize(17).fontWeight(FontWeight.Bold)
            .fontColor('#4A3025').width('100%')
          Text('保存后，文字、图片、大小和位置会在下次打开相机时自动应用；拍摄页中的临时修改不会覆盖这里。')
            .fontSize(13).lineHeight(20).fontColor('#80604E').width('100%')
        }.width('100%').padding(16).backgroundColor('#FFF7EE').borderRadius(18)
          .border({ width: 1, color: '#F0D5BF', radius: 18 })

        Button('保存并退出').width('100%').height(48).type(ButtonType.Normal)
          .fontSize(15).fontWeight(FontWeight.Bold).fontColor(Color.White)
          .backgroundColor('#E96832').borderRadius(24)
          .onClick(() => this.save(true))
        Row({ space: 10 }) {
          Button('不保存').layoutWeight(1).height(42).type(ButtonType.Normal).fontSize(13)
            .fontColor('#A24C3A').backgroundColor('#FFF1E8').borderRadius(21)
            .onClick(() => this.discardAndExit())
          Button('继续编辑').layoutWeight(1).height(42).type(ButtonType.Normal).fontSize(13)
            .fontColor('#6F4C3A').backgroundColor('#F7E8DA').borderRadius(21)
            .onClick(() => this.showExitDialog = false)
        }.width('100%')
      }
      .width(this.isExpanded() ? 440 : '88%').constraintSize({ maxWidth: 440 })
      .padding(this.isExpanded() ? 24 : 20)
      .backgroundColor('#FFFDF9').borderRadius(28)
      .border({ width: 1, color: '#E8C7AE', radius: 28 })
      .shadow({ radius: 34, color: '#52000000', offsetY: 14 })
    }.width('100%').height('100%').zIndex(100)
  }
  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
      Row({ space: 14 }) {
        Button('‹').width(46).height(46).fontSize(27).type(ButtonType.Normal)
          .fontColor('#5A3829').backgroundColor('#FFF0E3').borderRadius(23)
          .onClick(() => this.requestExit())
        Column({ space: 3 }) {
          Text('默认水印设置').fontSize(this.isExpanded() ? 27 : 24)
            .fontWeight(FontWeight.Bold).fontColor('#3B2117')
          Text('保存后，每次打开相机都会自动应用').fontSize(13).fontColor('#A07A63')
        }.alignItems(HorizontalAlign.Start)
        Blank()
        if (this.dirty) {
          Text('未保存').fontSize(12).fontColor('#B45A31')
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor('#FFE8D6').borderRadius(13)
        }
        Button('保存').width(78).height(42).type(ButtonType.Normal).fontSize(14).fontWeight(FontWeight.Bold)
          .fontColor(Color.White).backgroundColor('#E96832').borderRadius(21)
          .enabled(this.dirty).opacity(this.dirty ? 1 : 0.5)
          .onClick(() => this.save(false))
      }
      .width('100%').constraintSize({ maxWidth: 1220 })
      .padding({ left: this.isExpanded() ? 34 : 20, right: this.isExpanded() ? 34 : 20,
        top: this.isExpanded() ? 24 : 18, bottom: 16 })

      Scroll() {
        GridRow({
          columns: 12,
          gutter: 22,
          breakpoints: { value: ['600vp', '840vp'], reference: BreakpointsReference.WindowSize }
        }) {
          GridCol({ span: { xs: 12, sm: 12, md: 7 } }) {
            Column({ space: 12 }) {
              this.watermarkPreview()
              Text('点选水印后可编辑；只有一个水印时会默认选中。')
                .fontSize(12).fontColor('#8F6B56').width('100%').textAlign(TextAlign.Center)
            }.width('100%')
          }.padding({ bottom: 20 })
          GridCol({ span: { xs: 12, sm: 12, md: 5 } }) {
            this.editorPanel()
          }.padding({ bottom: 24 })
        }
        .width('100%').constraintSize({ maxWidth: 1220 })
        .onBreakpointChange((breakpoint: string) => this.currentBreakpoint = breakpoint)
        .padding({ left: this.isExpanded() ? 34 : 20, right: this.isExpanded() ? 34 : 20 })
      }.width('100%').layoutWeight(1)

      if (this.loading) {
        LoadingProgress().width(36).height(36).color('#E96832').position({ x: '50%', y: '50%' })
      }
      }.width('100%').height('100%').backgroundColor('#FFF8F0')
      if (this.showExitDialog) {
        this.exitConfirmOverlay()
      }
    }.width('100%').height('100%')
  }
}