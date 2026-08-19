import { common } from '@kit.AbilityKit';
import { APP_BACKGROUND_EVENT, APP_FOREGROUND_EVENT } from '../common/constants/AppEvent';
import { CAMERA_PERMISSION, PermissionManager } from '../common/permission/PermissionManager';
import { PermissionGuide } from '../components/PermissionGuide';
import { PermissionState } from '../models/PermissionState';
import { CameraViewModel } from '../viewmodels/CameraViewModel';
import { ErrorMessageUtil } from '../utils/ErrorMessageUtil';

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
    this.abilityContext.eventHub.on(APP_FOREGROUND_EVENT, this.foregroundCallback);
    this.abilityContext.eventHub.on(APP_BACKGROUND_EVENT, this.backgroundCallback);
    this.checkAndRequestPermission();
  }

  aboutToDisappear(): void {
    this.abilityContext.eventHub.off(APP_FOREGROUND_EVENT, this.foregroundCallback);
    this.abilityContext.eventHub.off(APP_BACKGROUND_EVENT, this.backgroundCallback);
    this.pauseCamera();
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
      this.getUIContext().getRouter().pushUrl({ url: 'pages/ResultPage', params: { sourceUri: uri } });
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
    const target = !this.flashEnabled;
    if (this.viewModel.setFlash(target)) {
      this.flashEnabled = target;
    } else {
      this.showToast('当前摄像头不支持该闪光灯模式。');
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (_) {
    }
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
        Row() {
          Button('‹').width(48).height(48).fontSize(28).type(ButtonType.Normal)
            .backgroundColor('#66000000').fontColor(Color.White)
            .onClick(() => this.getUIContext().getRouter().back())
          Text('相机').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Color.White)
            .layoutWeight(1).textAlign(TextAlign.Center)
          Button(this.flashEnabled ? '⚡' : '⚡︎').width(48).height(48).fontSize(22)
            .type(ButtonType.Normal).backgroundColor('#66000000').fontColor(Color.White)
            .enabled(this.ready && this.flashAvailable).onClick(() => this.toggleFlash())
        }.width('100%').padding({ left: 16, right: 16, top: 12 })

        Blank()

        if (this.statusText) {
          Text(this.statusText).fontSize(14).fontColor(Color.White)
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
            .backgroundColor('#88000000').borderRadius(18).margin({ bottom: 16 })
        }

        Row() {
          Button('切换').width(72).height(48).type(ButtonType.Normal)
            .backgroundColor('#66000000').fontColor(Color.White)
            .enabled(this.ready && !this.switching).onClick(() => this.switchCamera())
          Button('').width(78).height(78).borderRadius(39).backgroundColor(Color.White)
            .border({ width: 6, color: '#66FFFFFF', radius: 39 })
            .enabled(this.ready && !this.capturing).onClick(() => this.takePhoto())
          Blank().width(72)
        }.width('100%').justifyContent(FlexAlign.SpaceAround)
          .padding({ left: 26, right: 26, bottom: 30 })
      }.width('100%').height('100%')

      if (this.permissionState !== PermissionState.GRANTED) {
        PermissionGuide({
          permissionState: this.permissionState,
          requestPermission: () => this.checkAndRequestPermission(),
          openSettings: () => this.openPermissionSetting()
        })
      }
    }.width('100%').height('100%').backgroundColor('#0E1118')
  }
}
