import { common } from '@kit.AbilityKit';
import { camera } from '@kit.CameraKit';
import { CameraService } from '../services/CameraService';
import { TempFileManager } from '../services/TempFileManager';

export class CameraViewModel {
  private readonly service: CameraService = new CameraService();
  private position: camera.CameraPosition = camera.CameraPosition.CAMERA_POSITION_BACK;

  async start(context: common.UIAbilityContext, surfaceId: string): Promise<void> {
    await this.service.initialize(context, surfaceId, this.position);
  }

  async stop(): Promise<void> {
    await this.service.release();
  }

  async switchCamera(context: common.UIAbilityContext, surfaceId: string): Promise<void> {
    this.position = this.position === camera.CameraPosition.CAMERA_POSITION_BACK ?
      camera.CameraPosition.CAMERA_POSITION_FRONT : camera.CameraPosition.CAMERA_POSITION_BACK;
    await this.start(context, surfaceId);
  }

  async capture(context: common.UIAbilityContext): Promise<string> {
    const buffer = await this.service.capture();
    return TempFileManager.writeBuffer(context, buffer, 'capture', 'jpg');
  }

  setFlash(enabled: boolean): boolean {
    return this.service.setFlash(enabled);
  }

  hasFlash(): boolean {
    return this.service.canToggleFlash();
  }
}
