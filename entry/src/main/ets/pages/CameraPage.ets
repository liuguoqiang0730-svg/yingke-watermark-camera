import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { APP_BACKGROUND_EVENT, APP_FOREGROUND_EVENT } from '../common/constants/AppEvent';
import { CAMERA_PERMISSION, PermissionManager } from '../common/permission/PermissionManager';
import { DraggableWatermarkOverlay } from '../components/DraggableWatermarkOverlay';
import { PermissionGuide } from '../components/PermissionGuide';
import { PermissionState } from '../models/PermissionState';
import { CameraViewModel } from '../viewmodels/CameraViewModel';
import { ErrorMessageUtil } from '../utils/ErrorMessageUtil';
import { AppLogger } from '../utils/AppLogger';

const TAG: string = 'CameraPage';

@Entry
@Component
struct CameraPage {
  @State private permissionState: PermissionState = PermissionState.UNKNOWN;
  @State private statusText: string = '正在准备相机…';
  @State private ready: boolean = false;
  @State private capturing: boolean = false;
  @State private flashEnabled: boolean = false;
  @State private flashAvailable: boolean = false;
  @State private switching: boolean = false;
  @State private viewportWidth: number = 0;
  @State private viewportHeight: number = 0;
  @State private showSettings: boolean = false;
  @State private watermarkText: string = '映刻 · 记录此刻';
  @State private watermarkOpacity: number = 80;
  @State private textSize: number = 4;
  @State private logoSize: number = 5;
  @State private watermarkScale: number = 1;
  @State private showText: boolean = true;
  @State private showLogo: boolean = true;
  @State private positionX: number = 0.78;
  @State private positionY: number = 0.62;

  private readonly controller: XComponentController = new XComponentController();
  private readonly viewModel: CameraViewModel = new CameraViewModel();
  private readonly abilityContext: common.UIAbilityContext =
    this.getUIContext().getHostContext() as common.UIAbilityContext;
  private surfaceId: string = '';

  private readonly foregroundCallback = (): void => {
    this.resumeCamera();
  };
  private readonly backgroundCallback = (): void => {
    this.pauseCamera();
  };

  aboutToAppear(): void {
    this.setImmersive(true);
    this.abilityContext.eventHub.on(APP_FOREGROUND_EVENT, this.foregroundCallback);
    this.abilityContext.eventHub.on(APP_BACKGROUND_EVENT, this.backgroundCallback);
    this.checkAndRequestPermission();
  }

  aboutToDisappear(): void {
    this.setImmersive(false);
    this.abilityContext.eventHub.off(APP_FOREGROUND_EVENT, this.foregroundCallback);
    this.abilityContext.eventHub.off(APP_BACKGROUND_EVENT, this.backgroundCallback);
    this.pauseCamera();
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

  private async checkAndRequestPermission(): Promise<void> {
    this.permissionState = PermissionManager.getInstance()
      .checkPermission(this.abilityContext, CAMERA_PERMISSION);
    if (this.permissionState !== PermissionState.GRANTED) {
      this.permissionState = PermissionState.REQUESTING;
      this.permissionState = await PermissionManager.getInstance()
        .requestPermission(this.abilityContext, CAMERA_PERMISSION);
    }
    if (this.permissionState === PermissionState.GRANTED) {
      await this.startCamera();
      await this.setImmersive(true);
    } else {
      this.statusText = '未获得相机权限';
    }
  }

  private async openPermissionSetting(): Promise<void> {
    this.permissionState = PermissionState.REQUESTING;
    this.permissionState = await PermissionManager.getInstance()
      .requestPermissionOnSetting(this.abilityContext, CAMERA_PERMISSION);
    if (this.permissionState === PermissionState.GRANTED) {
      await this.startCamera();
    }
  }

  private async startCamera(): Promise<void> {
    if (!this.surfaceId || this.ready || this.switching) {
      return;
    }
    this.statusText = '正在启动相机…';
    try {
      await this.viewModel.start(this.abilityContext, this.surfaceId);
      this.ready = true;
      this.flashAvailable = this.viewModel.hasFlash();
      this.statusText = '';
    } catch (error) {
      this.ready = false;
      this.statusText = ErrorMessageUtil.from(error as object, '相机启动失败，请重试。');
    }
  }

  private async pauseCamera(): Promise<void> {
    this.ready = false;
    this.flashEnabled = false;
    await this.viewModel.stop();
  }

  private async resumeCamera(): Promise<void> {
    this.permissionState = PermissionManager.getInstance()
      .checkPermission(this.abilityContext, CAMERA_PERMISSION);
    if (this.permissionState === PermissionState.GRANTED) {
      await this.startCamera();
      await this.setImmersive(true);
    }
  }

  private async takePhoto(): Promise<void> {
    if (!this.ready || this.capturing) {
      return;
    }
    this.capturing = true;
    this.statusText = '正在拍摄…';
    try {
      const uri = await this.viewModel.capture(this.abilityContext);
      await this.viewModel.stop();
      this.ready = false;
      await this.getUIContext().getRouter().replaceUrl({
        url: 'pages/ResultPage',
        params: {
          sourceUri: uri,
          resultOnly: true,
          watermarkText: this.watermarkText,
          watermarkOpacity: this.watermarkOpacity,
          textSizePercent: this.textSize,
          logoSizePercent: this.logoSize,
          scaleFactor: this.watermarkScale,
          showText: this.showText,
          showLogo: this.showLogo,
          positionX: this.positionX,
          positionY: this.positionY
        }
      });
    } catch (error) {
      const message = ErrorMessageUtil.from(error as object, '拍照失败，请重试。');
      this.statusText = message;
      this.showToast(message);
    } finally {
      this.capturing = false;
    }
  }

  private async switchCamera(): Promise<void> {
    if (!this.ready || this.switching) {
      return;
    }
    this.switching = true;
    this.ready = false;
    this.statusText = '正在切换摄像头…';
    try {
      await this.viewModel.switchCamera(this.abilityContext, this.surfaceId);
      this.ready = true;
      this.flashEnabled = false;
      this.flashAvailable = this.viewModel.hasFlash();
      this.statusText = '';
    } catch (error) {
      this.statusText = ErrorMessageUtil.from(error as object, '摄像头切换失败。');
    } finally {
      this.switching = false;
    }
  }

  private toggleFlash(): void {
    if (!this.ready || !this.flashAvailable) {
      this.showToast('当前摄像头不支持闪光灯。');
      return;
    }
    const target = !this.flashEnabled;
    if (this.viewModel.setFlash(target)) {
      this.flashEnabled = target;
      this.showToast(target ? '闪光灯已开启' : '闪光灯已关闭');
    } else {
      this.showToast('当前摄像头不支持该闪光灯模式。');
    }
  }

  private updatePosition(x: number, y: number): void {
    this.positionX = x;
    this.positionY = y;
  }

  private updateScale(scale: number): void {
    this.watermarkScale = scale;
  }

  private watermarkMargin(): number {
    return Math.min(this.viewportWidth, this.viewportHeight) * 0.04;
  }

  private watermarkFrameWidth(): number {
    return Math.max(1, this.viewportWidth - this.watermarkMargin() * 2);
  }

  private watermarkFrameHeight(): number {
    return Math.max(1, this.viewportHeight - this.watermarkMargin() * 2);
  }

  private isWide(): boolean {
    return this.viewportWidth >= 700;
  }

  private toggleText(value: boolean): void {
    if (!value && !this.showLogo) {
      this.showToast('文字和 Logo 至少保留一种。');
      return;
    }
    this.showText = value;
  }

  private toggleLogo(value: boolean): void {
    if (!value && !this.showText) {
      this.showToast('文字和 Logo 至少保留一种。');
      return;
    }
    this.showLogo = value;
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (_) {
    }
  }

  @Builder
  private settingsGlyph() {
    Column({ space: 4 }) {
      Row() {
        Divider().width(19).strokeWidth(2).color(Color.White)
        Circle().width(5).height(5).fill(Color.White).position({ x: 4, y: 0 })
      }.width(24).height(5)
      Row() {
        Divider().width(19).strokeWidth(2).color(Color.White)
        Circle().width(5).height(5).fill(Color.White).position({ x: 14, y: 0 })
      }.width(24).height(5)
      Row() {
        Divider().width(19).strokeWidth(2).color(Color.White)
        Circle().width(5).height(5).fill(Color.White).position({ x: 8, y: 0 })
      }.width(24).height(5)
    }.width(24)
  }

  @Builder
  private settingsPanel() {
    Stack({ alignContent: Alignment.End }) {
      Column().width('100%').height('100%').backgroundColor('#77000000')
        .onClick(() => this.showSettings = false)

      Column() {
        Row() {
          Column({ space: 3 }) {
            Text('拍摄水印设置').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#3B2117')
            Text('调整后会立即显示在取景器上').fontSize(12).fontColor('#9A725C')
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
              TextInput({ text: this.watermarkText, placeholder: '输入水印文字' })
                .width('100%').height(46).maxLength(40).backgroundColor('#FFF8F1')
                .onChange((value: string) => this.watermarkText = value)
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
                .selectedColor('#E96832').onChange((value: number) => this.watermarkOpacity = value)
            }.width('100%')

            Column({ space: 6 }) {
              Text(`文字大小 ${this.textSize.toFixed(1)}%`).fontSize(14)
                .fontColor('#5A3829').width('100%')
              Slider({ value: this.textSize, min: 2, max: 8, step: 0.5 })
                .selectedColor('#E96832').onChange((value: number) => this.textSize = value)
            }.width('100%')

            Column({ space: 6 }) {
              Text(`Logo 大小 ${Math.round(this.logoSize)}%`).fontSize(14)
                .fontColor('#5A3829').width('100%')
              Slider({ value: this.logoSize, min: 3, max: 12, step: 1 })
                .selectedColor('#E96832').onChange((value: number) => this.logoSize = value)
            }.width('100%')

            Column({ space: 6 }) {
              Text(`整体缩放 ${Math.round(this.watermarkScale * 100)}%`).fontSize(14)
                .fontColor('#5A3829').width('100%')
              Slider({ value: this.watermarkScale, min: 0.5, max: 2.5, step: 0.05 })
                .selectedColor('#E96832').onChange((value: number) => this.updateScale(value))
            }.width('100%')

            Row({ space: 10 }) {
              Button('左下').layoutWeight(1).height(42).type(ButtonType.Normal)
                .fontColor('#5A3829').backgroundColor('#FFF0E3')
                .onClick(() => this.updatePosition(0.1, 0.72))
              Button('居中').layoutWeight(1).height(42).type(ButtonType.Normal)
                .fontColor('#5A3829').backgroundColor('#FFF0E3')
                .onClick(() => this.updatePosition(0.5, 0.5))
              Button('右下').layoutWeight(1).height(42).type(ButtonType.Normal)
                .fontColor(Color.White).backgroundColor('#E96832')
                .onClick(() => this.updatePosition(0.9, 0.72))
            }.width('100%')

            Text('关闭设置后，可拖动、双指缩放或双击水印编辑。')
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
      XComponent({ id: 'cameraPreview', type: XComponentType.SURFACE, controller: this.controller })
        .width('100%').height('100%')
        .onLoad(() => {
          this.surfaceId = this.controller.getXComponentSurfaceId();
          if (this.permissionState === PermissionState.GRANTED) {
            this.startCamera();
          }
        })
        .onDestroy(() => {
          this.surfaceId = '';
          this.pauseCamera();
        })


      Column() {
        Row({ space: 10 }) {
          Button('‹').width(50).height(50).fontSize(28).type(ButtonType.Normal)
            .backgroundColor('#66000000').fontColor(Color.White).borderRadius(25)
            .onClick(() => this.getUIContext().getRouter().back())
          Column({ space: 2 }) {
            Text('映刻相机').fontSize(18).fontWeight(FontWeight.Bold).fontColor(Color.White)
            Text('拖动移动 · 双指缩放 · 双击编辑').fontSize(11).fontColor('#CCFFFFFF')
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)

          Column({ space: 1 }) {
            Text('ϟ').fontSize(25).fontWeight(FontWeight.Bold)
              .fontColor(this.flashEnabled ? '#FFD166' : Color.White)
            Text(this.flashEnabled ? '已开' : '闪光').fontSize(9)
              .fontColor(this.flashEnabled ? '#FFD166' : '#DDFFFFFF')
          }
          .width(52).height(52).justifyContent(FlexAlign.Center)
          .backgroundColor(this.flashEnabled ? '#664B3700' : '#66000000').borderRadius(26)
          .opacity(this.flashAvailable ? 1 : 0.5).onClick(() => this.toggleFlash())

          Column({ space: 2 }) {
            this.settingsGlyph()
            Text('设置').fontSize(9).fontColor('#DDFFFFFF')
          }
          .width(52).height(52).justifyContent(FlexAlign.Center)
          .backgroundColor('#66000000').borderRadius(26)
          .onClick(() => this.showSettings = true)
        }.width('100%').padding({ left: 18, right: 54, top: 18 })

        Blank()

        if (this.statusText) {
          Text(this.statusText).fontSize(14).fontColor(Color.White)
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
            .backgroundColor('#88000000').borderRadius(18).margin({ bottom: 14 })
        } else {
          Text('拖动移动 · 双指缩放 · 双击编辑').fontSize(12).fontColor(Color.White)
            .padding({ left: 14, right: 14, top: 7, bottom: 7 })
            .backgroundColor('#66000000').borderRadius(16).margin({ bottom: 12 })
        }

        Row() {
          Button('').width(82).height(82).borderRadius(41).backgroundColor(Color.White)
            .border({ width: 6, color: '#88FFFFFF', radius: 41 })
            .enabled(this.ready && !this.capturing).onClick(() => this.takePhoto())
        }.width('100%').justifyContent(FlexAlign.Center)
          .padding({ left: 30, right: 30, bottom: 26 })
      }.width('100%').height('100%')

      if (this.permissionState === PermissionState.GRANTED) {
        DraggableWatermarkOverlay({
          text: this.watermarkText,
          showText: this.showText,
          showLogo: this.showLogo,
          watermarkOpacity: this.watermarkOpacity / 100,
          textSize: Math.max(13, this.viewportWidth * this.textSize / 100),
          logoSize: Math.max(24, this.viewportWidth * this.logoSize / 100),
          scaleFactor: this.watermarkScale,
          positionX: this.positionX,
          positionY: this.positionY,
          frameX: this.watermarkMargin(),
          frameY: this.watermarkMargin(),
          frameWidth: this.watermarkFrameWidth(),
          frameHeight: this.watermarkFrameHeight(),
          onPositionChange: (x: number, y: number) => this.updatePosition(x, y),
          onScaleChange: (scale: number) => this.updateScale(scale),
          onEditRequest: () => this.showSettings = true
        })
      }
      if (this.showSettings) {
        this.settingsPanel()
      }

      if (this.permissionState !== PermissionState.GRANTED) {
        PermissionGuide({
          permissionState: this.permissionState,
          requestPermission: () => this.checkAndRequestPermission(),
          openSettings: () => this.openPermissionSetting()
        })
      }
    }
    .width('100%').height('100%').backgroundColor('#0E1118')
    .onAreaChange((_oldValue, newValue) => {
      this.viewportWidth = Number(newValue.width);
      this.viewportHeight = Number(newValue.height);
    })
  }
}