import { BusinessError } from '@kit.BasicServicesKit';
import { AppError, AppErrorCode } from '../models/AppError';

export class ErrorMessageUtil {
  static from(error: object, fallback: string): string {
    if (error instanceof AppError) {
      return error.message;
    }
    const businessError = error as BusinessError;
    if (businessError.message) {
      return `${fallback}（${businessError.code}: ${businessError.message}）`;
    }
    return fallback;
  }

  static camera(error: object): AppError {
    const businessError = error as BusinessError;
    if (businessError.code === 7400107) {
      return new AppError(AppErrorCode.CAMERA_BUSY, '相机正被其他应用占用，请稍后重试。');
    }
    return new AppError(AppErrorCode.CAMERA_UNAVAILABLE,
      ErrorMessageUtil.from(error, '相机启动失败，请确认设备支持并重试。'));
  }
}
