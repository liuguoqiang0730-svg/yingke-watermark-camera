import { common } from '@kit.AbilityKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { AppLogger } from '../utils/AppLogger';
import { AppError, AppErrorCode } from '../models/AppError';
import { ErrorMessageUtil } from '../utils/ErrorMessageUtil';

const TAG: string = 'TempFileManager';

export class TempFileManager {
  private static paths: Map<string, string> = new Map<string, string>();

  static writeBuffer(context: common.UIAbilityContext, data: ArrayBuffer,
    prefix: string = 'image', extension: string = 'jpg'): string {
    try {
      const path = `${context.cacheDir}/${prefix}_${Date.now()}.${extension}`;
      const file = fileIo.openSync(path,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      try {
        fileIo.writeSync(file.fd, data);
      } finally {
        try {
          fileIo.closeSync(file);
        } catch (closeError) {
          AppLogger.warn(TAG, `关闭临时文件失败：${JSON.stringify(closeError)}`);
        }
      }
      const uri = fileUri.getUriFromPath(path);
      TempFileManager.paths.set(uri, path);
      return uri;
    } catch (error) {
      throw new AppError(AppErrorCode.SAVE_FAILED,
        ErrorMessageUtil.from(error as object, '写入本地临时文件失败。'));
    }
  }

  static cleanup(uri: string): void {
    const path = TempFileManager.paths.get(uri);
    if (!path) {
      return;
    }
    try {
      fileIo.unlinkSync(path);
      TempFileManager.paths.delete(uri);
    } catch (error) {
      AppLogger.warn(TAG, `清理临时文件失败：${JSON.stringify(error)}`);
    }
  }

  static cleanupAll(): void {
    const entries = Array.from(TempFileManager.paths.entries());
    entries.forEach((entry: [string, string]): void => {
      const uri = entry[0];
      const path = entry[1];
      try {
        fileIo.unlinkSync(path);
      } catch (error) {
        AppLogger.warn(TAG, `清理临时文件失败：${JSON.stringify(error)}`);
      }
      TempFileManager.paths.delete(uri);
    });
  }
}
