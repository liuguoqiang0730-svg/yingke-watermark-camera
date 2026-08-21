import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { camera } from '@kit.CameraKit';
import { image } from '@kit.ImageKit';
import { display } from '@kit.ArkUI';
import { AppError, AppErrorCode } from '../models/AppError';
import { AppLogger } from '../utils/AppLogger';
import { ErrorMessageUtil } from '../utils/ErrorMessageUtil';

const TAG: string = 'CameraService';
const MAX_PHOTO_PIXELS: number = 12000000;
const MAX_PREVIEW_PIXELS: number = 2073600;

export class CameraOutputSize {
  width: number;
  height: number;

  constructor(width: number, height: number) {
    this.width = width;
    this.height = height;
  }
}

export class CameraService {
  private manager: camera.CameraManager | undefined = undefined;
  private input: camera.CameraInput | undefined = undefined;
  private previewOutput: camera.PreviewOutput | undefined = undefined;
  private photoOutput: camera.PhotoOutput | undefined = undefined;
  private session: camera.PhotoSession | undefined = undefined;
  private position: camera.CameraPosition = camera.CameraPosition.CAMERA_POSITION_BACK;
  private pendingResolve: ((data: ArrayBuffer) => void) | undefined = undefined;
  private pendingReject: ((reason: Object) => void) | undefined = undefined;
  private started: boolean = false;
  private deviceDegree: number = 0;
  private displayListenerRegistered: boolean = false;
  private photoOutputWidth: number = 0;
  private photoOutputHeight: number = 0;

  private readonly photoCallback = (error: BusinessError, photo: camera.Photo): void => {
    this.handlePhoto(error, photo);
  };
  private readonly displayChangeCallback = (_displayId: number): void => {
    this.updateDeviceRotation();
  };

  async initialize(context: common.UIAbilityContext, surfaceId: string,
    position: camera.CameraPosition = camera.CameraPosition.CAMERA_POSITION_BACK): Promise<void> {
    await this.release();
    try {
      this.position = position;
      this.manager = camera.getCameraManager(context);
      const device = this.selectCamera(this.manager.getSupportedCameras(), position);
      const capability = this.manager.getSupportedOutputCapability(device, camera.SceneMode.NORMAL_PHOTO);
      const photoProfile = this.selectPhotoProfile(capability.photoProfiles);
      const previewProfile = this.selectPreviewProfile(capability.previewProfiles, photoProfile);
      this.photoOutputWidth = photoProfile.size.width;
      this.photoOutputHeight = photoProfile.size.height;

      this.input = this.manager.createCameraInput(device);
      await this.input.open();
      this.previewOutput = this.manager.createPreviewOutput(previewProfile, surfaceId);
      this.photoOutput = this.manager.createPhotoOutput(photoProfile);
      this.photoOutput.on('photoAvailable', this.photoCallback);
      this.session = this.manager.createSession<camera.PhotoSession>(camera.SceneMode.NORMAL_PHOTO);
      this.session.beginConfig();
      if (!this.session.canAddInput(this.input)) {
        throw new AppError(AppErrorCode.CAMERA_UNAVAILABLE, '当前设备无法添加相机输入。');
      }
      this.session.addInput(this.input);
      if (!this.session.canAddOutput(this.previewOutput) || !this.session.canAddOutput(this.photoOutput)) {
        throw new AppError(AppErrorCode.CAMERA_UNAVAILABLE, '当前设备不支持所需的预览或拍照输出。');
      }
      this.session.addOutput(this.previewOutput);
      this.session.addOutput(this.photoOutput);
      await this.session.commitConfig();
      await this.session.start();
      this.started = true;
      this.updateDeviceRotation();
      this.registerDisplayListener();
      AppLogger.info(TAG, `相机会话已启动，位置=${position}`);
    } catch (error) {
      await this.release();
      throw ErrorMessageUtil.camera(error as object);
    }
  }

  async capture(): Promise<ArrayBuffer> {
    if (!this.started || !this.photoOutput) {
      throw new AppError(AppErrorCode.CAMERA_UNAVAILABLE, '相机尚未准备完成，请稍后重试。');
    }
    if (this.pendingResolve) {
      throw new AppError(AppErrorCode.CAMERA_UNAVAILABLE, '正在保存上一张照片，请稍候。');
    }
    return new Promise<ArrayBuffer>((resolve: (data: ArrayBuffer) => void,
      reject: (reason: Object) => void): void => {
      this.pendingResolve = resolve;
      this.pendingReject = reject;
      const rotation = this.photoOutput?.getPhotoRotation(this.deviceDegree) ??
        camera.ImageRotation.ROTATION_0;
      const setting: camera.PhotoCaptureSetting = { rotation: rotation };
      this.photoOutput?.capture(setting).catch((error: Object): void => {
        this.clearPending();
        reject(ErrorMessageUtil.camera(error));
      });
    });
  }

  canToggleFlash(): boolean {
    try {
      return this.session?.hasFlash() === true;
    } catch (error) {
      AppLogger.warn(TAG, `检查闪光灯失败：${JSON.stringify(error)}`);
      return false;
    }
  }

  setFlash(enabled: boolean): boolean {
    try {
      if (!this.session || !this.session.hasFlash()) {
        return false;
      }
      const mode = enabled ? camera.FlashMode.FLASH_MODE_OPEN : camera.FlashMode.FLASH_MODE_CLOSE;
      if (!this.session.isFlashModeSupported(mode)) {
        return false;
      }
      this.session.setFlashMode(mode);
      return true;
    } catch (error) {
      AppLogger.warn(TAG, `设置闪光灯失败：${JSON.stringify(error)}`);
      return false;
    }
  }

  getPosition(): camera.CameraPosition {
    return this.position;
  }

  getPhotoOutputSize(): CameraOutputSize {
    return new CameraOutputSize(this.photoOutputWidth, this.photoOutputHeight);
  }

  async release(): Promise<void> {
    this.started = false;
    this.unregisterDisplayListener();
    if (this.pendingReject) {
      this.pendingReject(new AppError(AppErrorCode.CAMERA_UNAVAILABLE, '相机会话已结束。'));
    }
    this.clearPending();
    if (this.photoOutput) {
      this.photoOutput.off('photoAvailable', this.photoCallback);
    }
    try {
      await this.session?.stop();
    } catch (error) {
      AppLogger.warn(TAG, `停止会话失败：${JSON.stringify(error)}`);
    }
    try {
      await this.session?.release();
      await this.previewOutput?.release();
      await this.photoOutput?.release();
      await this.input?.close();
    } catch (error) {
      AppLogger.warn(TAG, `释放相机资源失败：${JSON.stringify(error)}`);
    }
    this.session = undefined;
    this.previewOutput = undefined;
    this.photoOutput = undefined;
    this.input = undefined;
    this.manager = undefined;
  }

  private registerDisplayListener(): void {
    if (this.displayListenerRegistered) {
      return;
    }
    try {
      display.on('change', this.displayChangeCallback);
      this.displayListenerRegistered = true;
    } catch (error) {
      AppLogger.warn(TAG, `注册屏幕方向监听失败：${JSON.stringify(error)}`);
    }
  }

  private unregisterDisplayListener(): void {
    if (!this.displayListenerRegistered) {
      return;
    }
    try {
      display.off('change', this.displayChangeCallback);
    } catch (error) {
      AppLogger.warn(TAG, `移除屏幕方向监听失败：${JSON.stringify(error)}`);
    } finally {
      this.displayListenerRegistered = false;
    }
  }

  private updateDeviceRotation(): void {
    try {
      this.deviceDegree = this.toDeviceDegree(display.getDefaultDisplaySync().rotation);
      if (this.previewOutput) {
        const previewRotation = this.previewOutput.getPreviewRotation(this.deviceDegree);
        this.previewOutput.setPreviewRotation(previewRotation, false);
      }
      AppLogger.info(TAG, `相机方向已更新：deviceDegree=${this.deviceDegree}`);
    } catch (error) {
      AppLogger.warn(TAG, `更新相机方向失败：${JSON.stringify(error)}`);
    }
  }

  private toDeviceDegree(displayRotation: number): number {
    switch (displayRotation) {
      case 1:
        return 90;
      case 2:
        return 180;
      case 3:
        return 270;
      default:
        return 0;
    }
  }

  private async handlePhoto(error: BusinessError, photo: camera.Photo): Promise<void> {
    if (error && error.code) {
      this.pendingReject?.(ErrorMessageUtil.camera(error));
      this.clearPending();
      await photo.release();
      return;
    }
    try {
      const component = await photo.main.getComponent(image.ComponentType.JPEG);
      const source = new Uint8Array(component.byteBuffer);
      const copy = new Uint8Array(source.length);
      copy.set(source);
      this.pendingResolve?.(copy.buffer as ArrayBuffer);
    } catch (captureError) {
      this.pendingReject?.(new AppError(AppErrorCode.IMAGE_DECODE_FAILED,
        ErrorMessageUtil.from(captureError as object, '读取拍摄结果失败，请重试。')));
    } finally {
      this.clearPending();
      await photo.release();
    }
  }

  private clearPending(): void {
    this.pendingResolve = undefined;
    this.pendingReject = undefined;
  }

  private selectCamera(devices: Array<camera.CameraDevice>, position: camera.CameraPosition): camera.CameraDevice {
    const matched = devices.find((device: camera.CameraDevice): boolean => device.cameraPosition === position);
    if (matched) {
      return matched;
    }
    if (devices.length === 0) {
      throw new AppError(AppErrorCode.CAMERA_UNAVAILABLE, '设备未检测到可用摄像头。');
    }
    return devices[0];
  }

  private selectPreviewProfile(profiles: Array<camera.Profile>, photoProfile: camera.Profile): camera.Profile {
    if (profiles.length === 0) {
      throw new AppError(AppErrorCode.CAMERA_UNAVAILABLE, '设备没有可用的相机预览规格。');
    }
    let selected = profiles[0];
    const photoAspect = this.normalizedAspect(photoProfile);
    let selectedWithinLimit = selected.size.width * selected.size.height <= MAX_PREVIEW_PIXELS;
    let selectedAspectDelta = Math.abs(this.normalizedAspect(selected) - photoAspect);
    profiles.forEach((profile: camera.Profile): void => {
      const pixels = profile.size.width * profile.size.height;
      const selectedPixels = selected.size.width * selected.size.height;
      const withinLimit = pixels <= MAX_PREVIEW_PIXELS;
      const aspectDelta = Math.abs(this.normalizedAspect(profile) - photoAspect);
      const closerAspect = aspectDelta < selectedAspectDelta - 0.0001;
      const sameAspect = Math.abs(aspectDelta - selectedAspectDelta) <= 0.0001;
      const betterResolution = withinLimit ? pixels > selectedPixels : pixels < selectedPixels;
      if ((withinLimit && !selectedWithinLimit) ||
        (withinLimit === selectedWithinLimit && (closerAspect || (sameAspect && betterResolution)))) {
        selected = profile;
        selectedWithinLimit = withinLimit;
        selectedAspectDelta = aspectDelta;
      }
    });
    return selected;
  }

  private normalizedAspect(profile: camera.Profile): number {
    const shortEdge = Math.max(1, Math.min(profile.size.width, profile.size.height));
    const longEdge = Math.max(profile.size.width, profile.size.height);
    return longEdge / shortEdge;
  }

  private selectPhotoProfile(profiles: Array<camera.Profile>): camera.Profile {
    if (profiles.length === 0) {
      throw new AppError(AppErrorCode.CAMERA_UNAVAILABLE, '设备没有可用的拍照规格。');
    }
    let selected = profiles[0];
    let selectedWithinLimit = selected.size.width * selected.size.height <= MAX_PHOTO_PIXELS;
    profiles.forEach((profile: camera.Profile): void => {
      const pixels = profile.size.width * profile.size.height;
      const selectedPixels = selected.size.width * selected.size.height;
      if (pixels <= MAX_PHOTO_PIXELS && (!selectedWithinLimit || pixels > selectedPixels)) {
        selected = profile;
        selectedWithinLimit = true;
      } else if (!selectedWithinLimit && pixels < selectedPixels) {
        selected = profile;
      }
    });
    return selected;
  }
}
