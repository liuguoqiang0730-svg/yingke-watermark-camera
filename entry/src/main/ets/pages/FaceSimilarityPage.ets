import { image } from '@kit.ImageKit';
import { AppError, AppErrorCode } from '../models/AppError';
import { ErrorMessageUtil } from '../utils/ErrorMessageUtil';
import { FaceSimilarityViewModel } from '../viewmodels/FaceSimilarityViewModel';

@Entry
@Component
struct FaceSimilarityPage {
  @State private viewportWidth: number = 0;
  @State private firstImage: image.PixelMap | undefined = undefined;
  @State private secondImage: image.PixelMap | undefined = undefined;
  @State private selectingSlot: number = 0;
  @State private isComparing: boolean = false;
  @State private hasResult: boolean = false;
  @State private similarity: number = 0;
  @State private isSamePerson: boolean = false;
  @State private errorMessage: string = '';
  private readonly viewModel: FaceSimilarityViewModel = new FaceSimilarityViewModel();

  async aboutToDisappear(): Promise<void> {
    // 系统 PhotoViewPicker 会让当前页面暂时进入不可见状态，选图期间不能释放预览数据。
    if (this.selectingSlot !== 0) {
      return;
    }
    const firstImage = this.firstImage;
    const secondImage = this.secondImage;
    this.firstImage = undefined;
    this.secondImage = undefined;
    await this.viewModel.releasePixelMap(firstImage);
    await this.viewModel.releasePixelMap(secondImage);
  }

  private isExpanded(): boolean {
    return this.viewportWidth >= 840;
  }

  private canCompare(): boolean {
    return !!this.firstImage && !!this.secondImage && !this.isComparing && this.selectingSlot === 0;
  }

  private similarityPercent(): number {
    return this.similarity * 100;
  }

  private resultTitle(): string {
    const percent = this.similarityPercent();
    if (percent >= 85) {
      return '默契十足';
    }
    if (percent >= 70) {
      return '很有相似感';
    }
    if (percent >= 50) {
      return '有些神似';
    }
    return '各有特色';
  }

  private resultDescription(): string {
    return this.isSamePerson ? '系统判断两张照片中的最大人脸可能属于同一人' :
      '系统判断两张照片中的最大人脸更可能属于不同的人';
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (_) {
    }
  }

  private clearResult(): void {
    this.hasResult = false;
    this.similarity = 0;
    this.isSamePerson = false;
    this.errorMessage = '';
  }

  private async choosePhoto(slot: number): Promise<void> {
    if (this.isComparing || this.selectingSlot !== 0) {
      return;
    }
    this.selectingSlot = slot;
    this.errorMessage = '';
    try {
      const pixelMap = await this.viewModel.selectPhoto();
      let previousImage: image.PixelMap | undefined = undefined;
      if (slot === 1) {
        previousImage = this.firstImage;
        this.firstImage = pixelMap;
      } else {
        previousImage = this.secondImage;
        this.secondImage = pixelMap;
      }
      this.clearResult();
      await this.viewModel.releasePixelMap(previousImage);
      this.showToast(slot === 1 ? '照片 A 已选择' : '照片 B 已选择');
    } catch (error) {
      if (error instanceof AppError && error.code === AppErrorCode.USER_CANCELLED) {
        return;
      }
      this.errorMessage = ErrorMessageUtil.from(error as object, '无法读取所选照片，请重试。');
      this.showToast(this.errorMessage);
    } finally {
      this.selectingSlot = 0;
    }
  }

  private async compareFaces(): Promise<void> {
    const firstImage = this.firstImage;
    const secondImage = this.secondImage;
    if (!this.canCompare() || !firstImage || !secondImage) {
      this.showToast('请先选择两张包含人脸的照片');
      return;
    }
    this.isComparing = true;
    this.hasResult = false;
    this.errorMessage = '';
    try {
      const result = await this.viewModel.compareFaces(firstImage, secondImage);
      this.similarity = result.similarity;
      this.isSamePerson = result.isSamePerson;
      this.hasResult = true;
    } catch (error) {
      this.errorMessage = ErrorMessageUtil.from(error as object,
        '识别失败，请确保两张照片中都包含清晰的正面人脸。');
    } finally {
      this.isComparing = false;
    }
  }

  @Builder
  private topBar() {
    Row({ space: 12 }) {
      Button('‹').width(44).height(44).fontSize(30).type(ButtonType.Normal)
        .fontColor('#3B2117').backgroundColor('#FFF7F0').borderRadius(22)
        .enabled(!this.isComparing)
        .onClick(() => this.getUIContext().getRouter().back())
      Column({ space: 2 }) {
        Text('相似度趣测').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#3B2117')
        Text('Core Vision Kit 端侧人脸比对').fontSize(12).fontColor('#9A725C')
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text('本地处理').fontSize(12).fontColor('#4F7657')
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .backgroundColor('#EAF5EA').borderRadius(14)
    }
    .width('100%').padding({ left: 18, right: 18, top: 14, bottom: 12 })
    .backgroundColor('#FFFBF7')
  }

  @Builder
  private photoPlaceholder() {
    Column({ space: 8 }) {
      Text('+').fontSize(this.isExpanded() ? 42 : 36)
        .fontWeight(FontWeight.Lighter).fontColor('#E85D27')
      Text('选择照片').fontSize(this.isExpanded() ? 16 : 14)
        .fontWeight(FontWeight.Medium).fontColor('#6F4C3A')
    }
    .width('100%').height(this.isExpanded() ? 250 : 160)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#FFF8EE').borderRadius(20)
  }

  @Builder
  private photoSlot(label: string, slot: number) {
    Column({ space: 10 }) {
      Stack() {
        if (slot === 1 && this.firstImage) {
          Image(this.firstImage)
            .width('100%').height(this.isExpanded() ? 250 : 160)
            .objectFit(ImageFit.Cover).borderRadius(20)
        } else if (slot === 2 && this.secondImage) {
          Image(this.secondImage)
            .width('100%').height(this.isExpanded() ? 250 : 160)
            .objectFit(ImageFit.Cover).borderRadius(20)
        } else {
          this.photoPlaceholder()
        }
        if (this.selectingSlot === slot) {
          Column({ space: 8 }) {
            LoadingProgress().width(32).height(32).color('#E85D27')
            Text('正在读取…').fontSize(13).fontColor('#6F4C3A')
          }
          .width('100%').height('100%').justifyContent(FlexAlign.Center)
          .backgroundColor('#E6FFF8EE').borderRadius(20)
        }
      }
      .width('100%').height(this.isExpanded() ? 250 : 160)
      .borderRadius(20)
      .border({
        width: 1,
        color: (slot === 1 && this.firstImage) || (slot === 2 && this.secondImage) ? '#F0B78E' : '#EBCDB7',
        style: BorderStyle.Dashed
      })

      Row() {
        Text(label).fontSize(this.isExpanded() ? 16 : 14)
          .fontWeight(FontWeight.Bold).fontColor('#4A3025')
        Blank()
        Text((slot === 1 && this.firstImage) || (slot === 2 && this.secondImage) ? '点击更换' : '待选择')
          .fontSize(12).fontColor('#B17A5C')
      }.width('100%')
    }
    .layoutWeight(1)
    .padding(this.isExpanded() ? 16 : 10)
    .backgroundColor('#FFFDF9').borderRadius(24)
    .border({ width: 1, color: '#F2DCCB' })
    .onClick(() => this.choosePhoto(slot))
  }

  @Builder
  private comparisonPanel() {
    Column({ space: this.isExpanded() ? 22 : 16 }) {
      Column({ space: 6 }) {
        Text('看看你们有多像').fontSize(this.isExpanded() ? 30 : 25)
          .fontWeight(FontWeight.Bold).fontColor('#3B2117')
        Text('分别选择两张照片，系统将比对其中面积最大的人脸')
          .fontSize(this.isExpanded() ? 15 : 13).fontColor('#9B7761')
      }.width('100%').alignItems(HorizontalAlign.Start)

      Row({ space: this.isExpanded() ? 20 : 8 }) {
        this.photoSlot('照片 A', 1)
        Text('VS').fontSize(this.isExpanded() ? 18 : 12)
          .fontWeight(FontWeight.Bold).fontColor('#E85D27')
          .width(this.isExpanded() ? 48 : 30).textAlign(TextAlign.Center)
        this.photoSlot('照片 B', 2)
      }.width('100%').alignItems(VerticalAlign.Center)

      Button() {
        Row({ space: 10 }) {
          if (this.isComparing) {
            LoadingProgress().width(22).height(22).color(Color.White)
          }
          Text(this.isComparing ? '正在识别…' : '开始比对')
            .fontSize(17).fontWeight(FontWeight.Bold).fontColor(Color.White)
        }.justifyContent(FlexAlign.Center)
      }
      .width('100%').height(52).type(ButtonType.Capsule)
      .backgroundColor(this.canCompare() ? '#EC652E' : '#D7B9A7')
      .enabled(this.canCompare())
      .onClick(() => this.compareFaces())

      if (this.errorMessage.length > 0) {
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
  private resultCard() {
    Row({ space: this.isExpanded() ? 28 : 18 }) {
      Stack() {
        Circle().width(this.isExpanded() ? 126 : 106).height(this.isExpanded() ? 126 : 106)
          .fill('#FFF2E7').stroke('#F39A61').strokeWidth(7)
        Column({ space: 0 }) {
          Text(this.similarityPercent().toFixed(1)).fontSize(this.isExpanded() ? 34 : 29)
            .fontWeight(FontWeight.Bold).fontColor('#E55420')
          Text('%').fontSize(14).fontWeight(FontWeight.Bold).fontColor('#B86A43')
        }
      }.width(this.isExpanded() ? 132 : 112).height(this.isExpanded() ? 132 : 112)

      Column({ space: 7 }) {
        Text(this.resultTitle()).fontSize(this.isExpanded() ? 26 : 22)
          .fontWeight(FontWeight.Bold).fontColor('#3B2117')
        Text(this.resultDescription()).fontSize(this.isExpanded() ? 15 : 13)
          .fontColor('#87624D').lineHeight(this.isExpanded() ? 23 : 20)
        Text('结果仅供娱乐，不用于身份认证或专业判断')
          .fontSize(12).fontColor('#B28B73')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }
    .width('100%').padding(this.isExpanded() ? 26 : 20)
    .linearGradient({ angle: 120, colors: [['#FFF8EE', 0.0], ['#FFE5CF', 1.0]] })
    .borderRadius(26).border({ width: 1, color: '#F3C7A7' })
  }

  build() {
    Column() {
      this.topBar()
      Scroll() {
        Column({ space: this.isExpanded() ? 24 : 18 }) {
          this.comparisonPanel()
          if (this.hasResult) {
            this.resultCard()
          }
          Text('建议选择清晰、正面、无遮挡的人脸照片。识别仅比较每张照片中面积最大的人脸。')
            .width('100%').fontSize(12).lineHeight(19).fontColor('#9B7761')
            .padding(14).backgroundColor('#FFF0E5').borderRadius(16)
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
