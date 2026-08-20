import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { ProcessingProgress } from '../components/ProcessingProgress';
import { AppError, AppErrorCode } from '../models/AppError';
import { ErrorMessageUtil } from '../utils/ErrorMessageUtil';
import {
  SegmentedImageInfo,
  SubjectBackgroundMode,
  SubjectSegmentationViewModel
} from '../viewmodels/SubjectSegmentationViewModel';

class SubjectSegmentationParams {
  sourceUri: string = '';
}

class BackgroundPreset {
  name: string;
  color: string;

  constructor(name: string, color: string) {
    this.name = name;
    this.color = color;
  }
}

@Entry
@Component
struct SubjectSegmentationPage {
  @State private sourceUri: string = '';
  @State private foreground: image.PixelMap | undefined = undefined;
  @State private customBackground: image.PixelMap | undefined = undefined;
  @State private backgroundMode: SubjectBackgroundMode = SubjectBackgroundMode.TRANSPARENT;
  @State private selectedBackgroundColor: string = '#FFFFFFFF';
  @State private subjectCount: number = 0;
  @State private showOriginal: boolean = false;
  @State private processing: boolean = false;
  @State private progressMessage: string = '正在识别图片主体…';
  @State private errorMessage: string = '';
  @State private viewportWidth: number = 0;

  private readonly presets: Array<BackgroundPreset> = [
    new BackgroundPreset('白色', '#FFFFFFFF'),
    new BackgroundPreset('蓝色', '#FF4385E6'),
    new BackgroundPreset('红色', '#FFE84A5F'),
    new BackgroundPreset('灰色', '#FFE8EAED')
  ];
  private readonly viewModel: SubjectSegmentationViewModel = new SubjectSegmentationViewModel();
  private readonly abilityContext: common.UIAbilityContext =
    this.getUIContext().getHostContext() as common.UIAbilityContext;

  aboutToAppear(): void {
    const params = this.getUIContext().getRouter().getParams() as SubjectSegmentationParams;
    if (params?.sourceUri) {
      this.sourceUri = params.sourceUri;
      this.processSource();
    }
  }

  aboutToDisappear(): void {
    this.viewModel.release();
  }

  private async processSource(): Promise<void> {
    if (!this.sourceUri || this.processing) {
      return;
    }
    this.processing = true;
    this.progressMessage = '正在识别并提取图片主体…';
    this.errorMessage = '';
    this.foreground = undefined;
    this.subjectCount = 0;
    try {
      const result: SegmentedImageInfo = await this.viewModel.process(this.sourceUri);
      this.foreground = result.foreground;
      this.subjectCount = result.subjectCount;
      this.showOriginal = false;
    } catch (error) {
      this.errorMessage = ErrorMessageUtil.from(error as object, '主体分割失败，请重试。');
    } finally {
      this.processing = false;
    }
  }

  private async chooseSource(): Promise<void> {
    if (this.processing) {
      return;
    }
    try {
      this.sourceUri = await this.viewModel.selectPhoto();
      await this.processSource();
    } catch (error) {
      if (error instanceof AppError && error.code === AppErrorCode.USER_CANCELLED) {
        return;
      }
      this.errorMessage = ErrorMessageUtil.from(error as object, '无法读取所选图片。');
    }
  }

  private async chooseCustomBackground(): Promise<void> {
    if (this.processing || !this.foreground) {
      return;
    }
    try {
      const uri = await this.viewModel.selectPhoto();
      this.customBackground = await this.viewModel.setCustomBackground(uri);
      this.backgroundMode = SubjectBackgroundMode.IMAGE;
      this.errorMessage = '';
    } catch (error) {
      if (error instanceof AppError && error.code === AppErrorCode.USER_CANCELLED) {
        return;
      }
      this.errorMessage = ErrorMessageUtil.from(error as object, '自定义背景读取失败。');
    }
  }

  private chooseTransparent(): void {
    this.backgroundMode = SubjectBackgroundMode.TRANSPARENT;
    this.viewModel.invalidateOutput();
  }

  private chooseSolid(color: string): void {
    this.selectedBackgroundColor = color;
    this.backgroundMode = SubjectBackgroundMode.SOLID;
    this.viewModel.invalidateOutput();
  }

  private async save(): Promise<void> {
    if (!this.foreground || this.processing) {
      return;
    }
    this.processing = true;
    this.progressMessage = this.backgroundMode === SubjectBackgroundMode.TRANSPARENT ?
      '正在生成透明 PNG…' : '正在合成新背景…';
    this.errorMessage = '';
    try {
      await this.viewModel.save(this.abilityContext, this.backgroundMode, this.selectedBackgroundColor);
      this.showToast(this.backgroundMode === SubjectBackgroundMode.TRANSPARENT ?
        '透明 PNG 已保存到相册' : '换背景图片已保存到相册');
    } catch (error) {
      this.errorMessage = ErrorMessageUtil.from(error as object, '保存失败，请重试。');
    } finally {
      this.processing = false;
    }
  }

  private async share(): Promise<void> {
    if (!this.foreground || this.processing) {
      return;
    }
    this.processing = true;
    this.progressMessage = '正在准备分享图片…';
    this.errorMessage = '';
    try {
      await this.viewModel.share(this.abilityContext, this.backgroundMode, this.selectedBackgroundColor);
    } catch (error) {
      this.errorMessage = ErrorMessageUtil.from(error as object, '分享失败，请重试。');
    } finally {
      this.processing = false;
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (_) {
    }
  }

  private isExpanded(): boolean {
    return this.viewportWidth >= 840;
  }

  private previewBackground(): string {
    if (this.backgroundMode === SubjectBackgroundMode.SOLID) {
      return this.selectedBackgroundColor;
    }
    return '#FFE4E6EA';
  }

  @Builder
  private topBar() {
    Row({ space: 12 }) {
      Button('‹').width(44).height(44).fontSize(30).type(ButtonType.Normal)
        .fontColor('#3B2117').backgroundColor('#FFFFF7F0').borderRadius(22)
        .onClick(() => this.getUIContext().getRouter().back())
      Column({ space: 2 }) {
        Text('主体分割').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#3B2117')
        Text(this.subjectCount > 0 ? `已识别 ${this.subjectCount} 个主体 · 全程本地处理` : '透明抠图与一键换背景')
          .fontSize(12).fontColor('#9A725C')
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Button(this.sourceUri ? '重新选图' : '选择图片').height(42).type(ButtonType.Normal)
        .fontSize(14).fontColor('#D95F2D').backgroundColor('#FFFFE9D8').borderRadius(21)
        .enabled(!this.processing).onClick(() => this.chooseSource())
    }
    .width('100%').padding({ left: 18, right: 18, top: 14, bottom: 12 })
    .backgroundColor('#FFFFFBF7')
  }

  @Builder
  private previewPanel() {
    Column({ space: 10 }) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.showOriginal && this.sourceUri) {
          Image(this.sourceUri).width('100%').height('100%').objectFit(ImageFit.Contain)
        } else if (this.foreground) {
          if (this.backgroundMode === SubjectBackgroundMode.IMAGE && this.customBackground) {
            Image(this.customBackground).width('100%').height('100%').objectFit(ImageFit.Cover)
          }
          Image(this.foreground).width('100%').height('100%').objectFit(ImageFit.Contain)
        } else if (!this.processing) {
          Column({ space: 12 }) {
            Text('◉').fontSize(48).fontColor('#F08A54')
            Text(this.errorMessage ? '暂未生成分割结果' : '请选择一张图片')
              .fontSize(17).fontWeight(FontWeight.Medium).fontColor('#5A3829')
            Button(this.errorMessage ? '重试' : '选择图片').height(42).type(ButtonType.Normal)
              .fontColor(Color.White).backgroundColor('#E96832').borderRadius(21)
              .onClick(() => this.errorMessage ? this.processSource() : this.chooseSource())
          }
        }

        if (!this.showOriginal && this.foreground &&
          this.backgroundMode === SubjectBackgroundMode.TRANSPARENT) {
          Text('透明背景').fontSize(11).fontColor('#775B6670')
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .backgroundColor('#DDFFFFFF').borderRadius(12)
            .position({ x: 12, y: 12 })
        }
      }
      .width('100%').layoutWeight(1).backgroundColor(this.previewBackground())
      .borderRadius(this.isExpanded() ? 28 : 20).clip(true)

      if (this.foreground) {
        Row({ space: 8 }) {
          Button('处理结果').height(36).type(ButtonType.Normal)
            .fontSize(13).fontColor(this.showOriginal ? '#80685A' : Color.White)
            .backgroundColor(this.showOriginal ? '#FFF0E4' : '#E96832').borderRadius(18)
            .onClick(() => this.showOriginal = false)
          Button('查看原图').height(36).type(ButtonType.Normal)
            .fontSize(13).fontColor(this.showOriginal ? Color.White : '#80685A')
            .backgroundColor(this.showOriginal ? '#E96832' : '#FFF0E4').borderRadius(18)
            .onClick(() => this.showOriginal = true)
        }
      }
    }.width('100%').height('100%')
  }

  @Builder
  private backgroundControls() {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 2 }) {
          Text('选择背景').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#3B2117')
          Text('透明结果导出 PNG，换背景结果导出 JPEG').fontSize(11).fontColor('#9A725C')
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      }.width('100%')

      List({ space: 12 }) {
        ListItem() {
          Column({ space: 5 }) {
            Stack() {
              Text('◇').fontSize(23).fontColor('#6D7580')
            }.width(48).height(48).backgroundColor('#FFE4E6EA').borderRadius(24)
              .border({
                width: this.backgroundMode === SubjectBackgroundMode.TRANSPARENT ? 3 : 1,
                color: this.backgroundMode === SubjectBackgroundMode.TRANSPARENT ? '#FFE96832' : '#FFD4D7DC'
              })
            Text('透明').fontSize(12).fontColor('#5A3829')
          }.onClick(() => this.chooseTransparent())
        }
        ForEach(this.presets, (preset: BackgroundPreset) => {
          ListItem() {
            Column({ space: 5 }) {
              Row().width(48).height(48).backgroundColor(preset.color).borderRadius(24)
                .border({
                  width: this.backgroundMode === SubjectBackgroundMode.SOLID &&
                    this.selectedBackgroundColor === preset.color ? 3 : 1,
                  color: this.backgroundMode === SubjectBackgroundMode.SOLID &&
                    this.selectedBackgroundColor === preset.color ? '#FFE96832' : '#FFD4D7DC'
                })
              Text(preset.name).fontSize(12).fontColor('#5A3829')
            }.onClick(() => this.chooseSolid(preset.color))
          }
        }, (preset: BackgroundPreset) => preset.color)
        ListItem() {
          Column({ space: 5 }) {
            Stack() {
              if (this.customBackground) {
                Image(this.customBackground).width(48).height(48).objectFit(ImageFit.Cover).borderRadius(24)
              } else {
                Text('+').fontSize(27).fontColor('#D95F2D')
              }
            }.width(48).height(48).backgroundColor('#FFFFE9D8').borderRadius(24)
              .border({
                width: this.backgroundMode === SubjectBackgroundMode.IMAGE ? 3 : 1,
                color: this.backgroundMode === SubjectBackgroundMode.IMAGE ? '#FFE96832' : '#FFF1C8AA'
              })
            Text('图片').fontSize(12).fontColor('#5A3829')
          }.onClick(() => this.chooseCustomBackground())
        }
      }
      .width('100%').height(76).listDirection(Axis.Horizontal)
      .scrollBar(BarState.Off)

      Row({ space: 12 }) {
        Column() {
          SaveButton({
            icon: SaveIconStyle.LINES,
            text: SaveDescription.SAVE_TO_GALLERY,
            buttonType: ButtonType.Capsule
          })
            .width('100%').height(50).enabled(!this.processing && !!this.foreground)
            .fontSize(15).fontWeight(FontWeight.Bold).fontColor('#3B2117')
            .iconSize(18).iconColor('#3B2117').textIconSpace(6)
            .backgroundColor('#FFFFEBDD').borderRadius(25)
            .onClick((_event: ClickEvent, result: SaveButtonOnClickResult) => {
              if (result === SaveButtonOnClickResult.SUCCESS) {
                this.save();
                return;
              }
              this.showToast('未获得保存授权，请重试。');
            })
        }.layoutWeight(1)
        Button('分享').width(108).height(50).type(ButtonType.Normal)
          .enabled(!this.processing && !!this.foreground)
          .fontSize(15).fontWeight(FontWeight.Bold).fontColor(Color.White)
          .backgroundColor('#E96832').borderRadius(25).onClick(() => this.share())
      }.width('100%')
    }
    .width('100%').padding({ left: 20, right: 20, top: 16, bottom: 18 })
    .backgroundColor('#FFFFFBF7')
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        this.topBar()
        Row() {
          this.previewPanel()
        }
        .width('100%').layoutWeight(1)
        .padding({
          left: this.isExpanded() ? 48 : 16,
          right: this.isExpanded() ? 48 : 16,
          top: this.isExpanded() ? 22 : 12,
          bottom: this.isExpanded() ? 22 : 12
        })
        this.backgroundControls()
      }.width('100%').height('100%').backgroundColor('#FFF8F0')

      if (this.errorMessage && this.foreground) {
        Text(this.errorMessage).fontSize(13).fontColor('#7A271A')
          .padding(12).backgroundColor('#FFFFE9E3').borderRadius(12)
          .position({ x: 20, y: 84 }).constraintSize({ maxWidth: 440 })
      }

      if (this.processing) {
        ProcessingProgress({ message: this.progressMessage })
      }
    }
    .width('100%').height('100%')
    .onAreaChange((_oldValue, newValue) => this.viewportWidth = Number(newValue.width))
  }
}
