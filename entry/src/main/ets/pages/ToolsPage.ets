import { AppError, AppErrorCode } from '../models/AppError';
import { ToolsViewModel } from '../viewmodels/ToolsViewModel';
import { ErrorMessageUtil } from '../utils/ErrorMessageUtil';

@Entry
@Component
struct ToolsPage {
  @State private selecting: boolean = false;
  private readonly viewModel: ToolsViewModel = new ToolsViewModel();

  private async selectPhoto(): Promise<void> {
    if (this.selecting) {
      return;
    }
    this.selecting = true;
    try {
      const uri = await this.viewModel.selectPhoto();
      this.getUIContext().getRouter().pushUrl({ url: 'pages/ResultPage', params: { sourceUri: uri } });
    } catch (error) {
      const appError = error as AppError;
      if (appError.code !== AppErrorCode.USER_CANCELLED) {
        this.showToast(ErrorMessageUtil.from(error as object, '无法选择照片。'));
      }
    } finally {
      this.selecting = false;
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (_) {
    }
  }

  @Builder
  private futureCard(icon: string, title: string, description: string) {
    Row({ space: 16 }) {
      Text(icon).fontSize(28).width(52).height(52).textAlign(TextAlign.Center)
        .backgroundColor('#EEF1F6').borderRadius(16)
      Column({ space: 4 }) {
        Text(title).fontSize(17).fontWeight(FontWeight.Medium).fontColor('#667085')
        Text(description).fontSize(13).fontColor('#98A2B3')
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text('后续').fontSize(12).fontColor('#98A2B3')
    }.width('100%').padding(16).backgroundColor('#FAFBFC').borderRadius(20)
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Row() {
          Button('‹').type(ButtonType.Normal).onClick(() => this.getUIContext().getRouter().back())
          Text('图片工具').fontSize(24).fontWeight(FontWeight.Bold)
            .layoutWeight(1).textAlign(TextAlign.Center)
          Blank().width(52)
        }.width('100%')

        Column({ space: 14 }) {
          Text('相册水印').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#172033')
          Text('通过系统 PhotoPicker 选择一张照片，无需申请整个相册权限。')
            .fontSize(14).fontColor('#667085').lineHeight(21)
          Button(this.selecting ? '正在打开相册…' : '选择照片并添加水印')
            .width('100%').height(52).enabled(!this.selecting).onClick(() => this.selectPhoto())
        }.width('100%').padding(22).alignItems(HorizontalAlign.Start)
          .backgroundColor('#FFFFFF').borderRadius(24)

        Text('后续图片能力').fontSize(18).fontWeight(FontWeight.Bold)
          .width('100%').margin({ top: 10 })
        this.futureCard('🧩', '多图拼接', '纵向、横向与网格拼图')
        this.futureCard('🔤', '文字识别', '端侧 OCR 与结果复制')
        this.futureCard('✂️', '主体分割', '透明 PNG 与背景替换')
      }.width('100%').padding({ left: 22, right: 22, top: 34, bottom: 32 })
    }.width('100%').height('100%').backgroundColor('#F5F7FB')
  }
}
