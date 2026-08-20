import { common } from '@kit.AbilityKit';
import { ProcessingProgress } from '../components/ProcessingProgress';
import { AppError, AppErrorCode } from '../models/AppError';
import { CollageConfig, CollageLayout } from '../models/CollageConfig';
import { ErrorMessageUtil } from '../utils/ErrorMessageUtil';
import { CollageViewModel } from '../viewmodels/CollageViewModel';

@Entry
@Component
struct CollagePage {
  @State private photoUris: string[] = [];
  @State private layout: CollageLayout = CollageLayout.VERTICAL;
  @State private spacing: number = 12;
  @State private cornerRadius: number = 20;
  @State private collageBackground: string = '#FFFFFFFF';
  @State private selecting: boolean = false;
  @State private processing: boolean = false;
  @State private viewportWidth: number = 0;
  @State private errorMessage: string = '';
  @State private selectedPhotoIndex: number = 0;

  private readonly viewModel: CollageViewModel = new CollageViewModel();
  private readonly abilityContext: common.UIAbilityContext =
    this.getUIContext().getHostContext() as common.UIAbilityContext;

  aboutToDisappear(): void {
    if (!this.processing) {
      this.viewModel.discardOutput();
    }
  }

  private isWide(): boolean {
    return this.viewportWidth >= 760;
  }

  private async selectPhotos(): Promise<void> {
    if (this.selecting || this.processing) {
      return;
    }
    this.selecting = true;
    this.errorMessage = '';
    try {
      this.photoUris = await this.viewModel.selectPhotos(9);
      this.selectedPhotoIndex = 0;
    } catch (error) {
      const appError = error as AppError;
      if (appError.code !== AppErrorCode.USER_CANCELLED) {
        this.errorMessage = ErrorMessageUtil.from(error as object, '无法选择照片。');
      }
    } finally {
      this.selecting = false;
    }
  }

  private movePhoto(index: number, offset: number): void {
    const target = index + offset;
    if (target < 0 || target >= this.photoUris.length) {
      return;
    }
    const next = this.photoUris.slice();
    const current = next[index];
    next[index] = next[target];
    next[target] = current;
    this.photoUris = next;
    this.selectedPhotoIndex = target;
  }

  private movePhotoTo(index: number, target: number): void {
    if (index < 0 || index >= this.photoUris.length || target < 0 ||
      target >= this.photoUris.length || index === target) {
      return;
    }
    const next = this.photoUris.slice();
    const moving = next.splice(index, 1)[0];
    next.splice(target, 0, moving);
    this.photoUris = next;
    this.selectedPhotoIndex = target;
  }

  private removePhoto(index: number): void {
    const next: string[] = [];
    this.photoUris.forEach((uri: string, current: number): void => {
      if (current !== index) {
        next.push(uri);
      }
    });
    this.photoUris = next;
    if (next.length === 0) {
      this.selectedPhotoIndex = 0;
    } else if (this.selectedPhotoIndex > index) {
      this.selectedPhotoIndex--;
    } else if (this.selectedPhotoIndex >= next.length) {
      this.selectedPhotoIndex = next.length - 1;
    }
  }

  private createConfig(): CollageConfig {
    const config = new CollageConfig();
    config.layout = this.layout;
    config.spacing = this.spacing;
    config.backgroundColor = this.collageBackground;
    config.cornerRadius = this.cornerRadius;
    return config;
  }

  private async generate(): Promise<void> {
    if (this.photoUris.length < 2) {
      this.showToast('请至少选择 2 张图片。');
      return;
    }
    if (this.processing) {
      return;
    }
    this.processing = true;
    this.errorMessage = '';
    try {
      const uri = await this.viewModel.generate(
        this.abilityContext, this.photoUris, this.createConfig());
      await this.getUIContext().getRouter().pushUrl({
        url: 'pages/ResultPage',
        params: {
          sourceUri: uri,
          resultOnly: true,
          plainResult: true,
          cleanupSource: true,
          resultTitle: '拼接完成'
        }
      });
      this.viewModel.transferOutput();
    } catch (error) {
      this.errorMessage = ErrorMessageUtil.from(error as object, '图片拼接失败。');
      this.viewModel.discardOutput();
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

  @Builder
  private layoutButton(value: CollageLayout, label: string, icon: string) {
    Button() {
      Column({ space: 4 }) {
        Text(icon).fontSize(20).fontWeight(FontWeight.Bold)
        Text(label).fontSize(12)
      }
    }
    .layoutWeight(1).height(64).type(ButtonType.Normal)
    .fontColor(this.layout === value ? Color.White : '#6A4332')
    .backgroundColor(this.layout === value ? '#E96832' : '#FFF1E5')
    .borderRadius(16).onClick(() => this.layout = value)
  }

  @Builder
  private backgroundButton(color: string, label: string) {
    Column({ space: 5 }) {
      Row().width(30).height(30).borderRadius(15).backgroundColor(color)
        .border({ width: this.collageBackground === color ? 3 : 1,
          color: this.collageBackground === color ? '#E96832' : '#D8C2B4' })
      Text(label).fontSize(11).fontColor('#795746')
    }.onClick(() => this.collageBackground = color)
  }

  @Builder
  private photoItem(uri: string, index: number) {
    Stack({ alignContent: Alignment.TopEnd }) {
      Image(uri).width(112).height(112).objectFit(ImageFit.Cover).borderRadius(16)
        .onClick(() => this.selectedPhotoIndex = index)
      Text(`${index + 1}`).width(28).height(28).textAlign(TextAlign.Center)
        .fontSize(12).fontWeight(FontWeight.Bold).fontColor(Color.White)
        .backgroundColor('#AA000000').borderRadius({ topRight: 16, bottomLeft: 12 })
      Button('×').width(30).height(30).fontSize(16).type(ButtonType.Normal)
        .fontColor('#B42318').backgroundColor('#EEFFFFFF')
        .position({ x: 74, y: 74 }).onClick(() => this.removePhoto(index))
    }
    .width(112).height(112)
    .border({ width: this.selectedPhotoIndex === index ? 3 : 0,
      color: this.selectedPhotoIndex === index ? '#E96832' : Color.Transparent })
    .borderRadius(18)
  }

  @Builder
  private editor() {
    Column({ space: 18 }) {
      Row() {
        Column({ space: 3 }) {
          Text(`已选 ${this.photoUris.length}/9 张`).fontSize(18)
            .fontWeight(FontWeight.Bold).fontColor('#3B2117')
          Text('所有布局均按下方编号顺序生成').fontSize(12).fontColor('#9A725C')
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Button(this.selecting ? '正在打开…' : '重新选择').height(38).type(ButtonType.Normal)
          .enabled(!this.selecting && !this.processing).fontSize(13).fontColor('#E96832')
          .backgroundColor('#FFF0E3').onClick(() => this.selectPhotos())
      }.width('100%')

      List({ space: 12 }) {
        ForEach(this.photoUris, (uri: string, index: number) => {
          ListItem() {
            this.photoItem(uri, index)
          }
        }, (uri: string, index: number) => `${uri}_${index}`)
      }.width('100%').height(124).listDirection(Axis.Horizontal).scrollBar(BarState.Off)

      Column({ space: 8 }) {
        Text(`正在调整第 ${this.selectedPhotoIndex + 1} 张 · 点击缩略图可切换`)
          .fontSize(12).fontColor('#795746').width('100%')
        Row({ space: 6 }) {
          Button('移到最前').layoutWeight(1).height(38).type(ButtonType.Normal)
            .fontSize(11).enabled(this.selectedPhotoIndex > 0)
            .fontColor('#5A3829').backgroundColor('#FFF0E3')
            .onClick(() => this.movePhotoTo(this.selectedPhotoIndex, 0))
          Button('前移').layoutWeight(1).height(38).type(ButtonType.Normal)
            .fontSize(11).enabled(this.selectedPhotoIndex > 0)
            .fontColor('#5A3829').backgroundColor('#FFF0E3')
            .onClick(() => this.movePhoto(this.selectedPhotoIndex, -1))
          Button('后移').layoutWeight(1).height(38).type(ButtonType.Normal)
            .fontSize(11).enabled(this.selectedPhotoIndex < this.photoUris.length - 1)
            .fontColor('#5A3829').backgroundColor('#FFF0E3')
            .onClick(() => this.movePhoto(this.selectedPhotoIndex, 1))
          Button('移到最后').layoutWeight(1).height(38).type(ButtonType.Normal)
            .fontSize(11).enabled(this.selectedPhotoIndex < this.photoUris.length - 1)
            .fontColor('#5A3829').backgroundColor('#FFF0E3')
            .onClick(() => this.movePhotoTo(this.selectedPhotoIndex, this.photoUris.length - 1))
        }.width('100%')
      }.width('100%').padding(10).backgroundColor('#FFF8F1').borderRadius(14)

      Column({ space: 10 }) {
        Text('拼接布局').fontSize(15).fontWeight(FontWeight.Bold)
          .fontColor('#4A3025').width('100%')
        Row({ space: 10 }) {
          this.layoutButton(CollageLayout.VERTICAL, '纵向长图', '▤')
          this.layoutButton(CollageLayout.HORIZONTAL, '横向长图', '▥')
          this.layoutButton(CollageLayout.GRID, '宫格拼图', '▦')
        }.width('100%')
      }.width('100%')

      Column({ space: 8 }) {
        Text(`图片间距 ${Math.round(this.spacing)} px`).fontSize(14)
          .fontColor('#5A3829').width('100%')
        Slider({ value: this.spacing, min: 0, max: 48, step: 4 })
          .selectedColor('#E96832').onChange((value: number) => this.spacing = value)
      }.width('100%')

      Column({ space: 8 }) {
        Text(`图片圆角 ${Math.round(this.cornerRadius)} px`).fontSize(14)
          .fontColor('#5A3829').width('100%')
        Slider({ value: this.cornerRadius, min: 0, max: 64, step: 4 })
          .selectedColor('#E96832').onChange((value: number) => this.cornerRadius = value)
      }.width('100%')

      Row({ space: 24 }) {
        Text('背景').fontSize(14).fontColor('#5A3829').layoutWeight(1)
        this.backgroundButton('#FFFFFFFF', '白色')
        this.backgroundButton('#FFFFF3E7', '暖色')
        this.backgroundButton('#FF171717', '黑色')
      }.width('100%').alignItems(VerticalAlign.Center)
    }
    .width('100%').padding(20).backgroundColor('#FFFFFDF9').borderRadius(24)
    .border({ width: 1, color: '#F2DCCB' })
  }

  build() {
    Stack() {
      Column() {
        Row({ space: 12 }) {
          Button('‹').width(44).height(44).fontSize(26).type(ButtonType.Normal)
            .fontColor('#5A3829').backgroundColor('#FFF0E3').borderRadius(22)
            .onClick(() => this.getUIContext().getRouter().back())
          Column({ space: 2 }) {
            Text('多图拼接').fontSize(24).fontWeight(FontWeight.Bold).fontColor('#3B2117')
            Text('2 至 9 张图片，本地生成不上传').fontSize(12).fontColor('#9A725C')
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        }.width('100%')

        Scroll() {
          Column({ space: 20 }) {
            if (this.photoUris.length === 0) {
              Column({ space: 16 }) {
                Text('▦').fontSize(54).fontColor('#E96832')
                Text('选择多张照片开始拼接').fontSize(20)
                  .fontWeight(FontWeight.Bold).fontColor('#3B2117')
                Text('支持纵向长图、横向长图和宫格拼图\n单次最多选择 9 张')
                  .fontSize(13).fontColor('#9A725C').lineHeight(21).textAlign(TextAlign.Center)
                Button(this.selecting ? '正在打开相册…' : '选择 2 至 9 张图片')
                  .width(this.isWide() ? 320 : '88%').height(52)
                  .enabled(!this.selecting).fontSize(16).fontColor(Color.White)
                  .backgroundColor('#E96832').borderRadius(26).onClick(() => this.selectPhotos())
              }
              .width('100%').padding({ top: 54, bottom: 54 })
              .backgroundColor('#FFFFFDF9').borderRadius(26)
              .border({ width: 1, color: '#F2DCCB' })
            } else {
              this.editor()
            }

            if (this.errorMessage) {
              Text(this.errorMessage).fontSize(13).fontColor('#7A271A').width('100%')
                .padding(12).backgroundColor('#FFFFE9E3').borderRadius(12)
            }
          }.width('100%').constraintSize({ maxWidth: this.isWide() ? 760 : 560 })
        }.width('100%').layoutWeight(1).margin({ top: 18 })

        if (this.photoUris.length > 0) {
          Button('生成拼接图片').width(this.isWide() ? 520 : '92%').height(54)
            .enabled(this.photoUris.length >= 2 && !this.processing)
            .fontSize(17).fontWeight(FontWeight.Bold).fontColor(Color.White)
            .backgroundColor('#E96832').borderRadius(27)
            .margin({ top: 10, bottom: 14 }).onClick(() => this.generate())
        }
      }
      .width('100%').height('100%').padding({ left: 20, right: 20, top: 24 })
      .backgroundColor('#FFF8F0')
      .onAreaChange((_oldValue, newValue) => this.viewportWidth = Number(newValue.width))

      if (this.processing) {
        ProcessingProgress({ message: '正在生成高清拼接图片…' })
      }
    }.width('100%').height('100%')
  }
}
