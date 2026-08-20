import { textRecognition } from '@kit.CoreVisionKit';
import { AppError, AppErrorCode } from '../models/AppError';
import { ErrorMessageUtil } from '../utils/ErrorMessageUtil';
import { ImageCodec } from './ImageCodec';

export class TextRecognitionService {
  private readonly imageCodec: ImageCodec = new ImageCodec();
  private initialized: boolean = false;
  private initializing: Promise<void> | undefined = undefined;

  async initialize(): Promise<void> {
    if (this.initialized) {
      return;
    }
    if (this.initializing) {
      return this.initializing;
    }
    this.initializing = this.initializeService();
    try {
      await this.initializing;
    } finally {
      this.initializing = undefined;
    }
  }

  async recognize(uri: string): Promise<string> {
    await this.initialize();
    const imageResult = await this.imageCodec.decodeForExport(uri);
    try {
      const visionInfo: textRecognition.VisionInfo = {
        pixelMap: imageResult.pixelMap
      };
      const configuration: textRecognition.TextRecognitionConfiguration = {
        isDirectionDetectionSupported: false
      };
      const result = await textRecognition.recognizeText(visionInfo, configuration);
      return result.value.trim();
    } catch (error) {
      throw new AppError(AppErrorCode.OCR_FAILED,
        ErrorMessageUtil.from(error as object, '文字识别失败，请换一张更清晰的图片重试。'));
    } finally {
      try {
        await imageResult.pixelMap.release();
      } catch (_) {
      }
    }
  }

  async release(): Promise<void> {
    if (this.initializing) {
      try {
        await this.initializing;
      } catch (_) {
      }
    }
    if (!this.initialized) {
      return;
    }
    this.initialized = false;
    try {
      await textRecognition.release();
    } catch (_) {
    }
  }

  private async initializeService(): Promise<void> {
    try {
      const initialized = await textRecognition.init();
      if (!initialized) {
        throw new AppError(AppErrorCode.OCR_FAILED, '当前设备暂不支持端侧文字识别。');
      }
      this.initialized = true;
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      throw new AppError(AppErrorCode.OCR_FAILED,
        ErrorMessageUtil.from(error as object, '文字识别服务初始化失败。'));
    }
  }
}
