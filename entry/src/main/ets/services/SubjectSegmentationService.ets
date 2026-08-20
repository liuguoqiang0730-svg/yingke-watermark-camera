import { subjectSegmentation } from '@kit.CoreVisionKit';
import { image } from '@kit.ImageKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppError, AppErrorCode } from '../models/AppError';
import { AppLogger } from '../utils/AppLogger';

const TAG: string = 'SubjectSegmentation';

export class SubjectSegmentationOutput {
  foreground: image.PixelMap;
  subjectCount: number;

  constructor(foreground: image.PixelMap, subjectCount: number) {
    this.foreground = foreground;
    this.subjectCount = subjectCount;
  }
}

export class SubjectSegmentationService {
  private initialized: boolean = false;

  async initialize(): Promise<void> {
    if (this.initialized) {
      return;
    }
    if (!canIUse('SystemCapability.AI.Vision.SubjectSegmentation')) {
      throw new AppError(AppErrorCode.IMAGE_PROCESS_FAILED,
        '当前设备不支持主体分割，请在 HarmonyOS 5.0.5 及以上的真机上使用。');
    }
    try {
      const success = await subjectSegmentation.init();
      if (!success) {
        throw new AppError(AppErrorCode.IMAGE_PROCESS_FAILED, '主体分割服务初始化失败，请稍后重试。');
      }
      this.initialized = true;
      AppLogger.info(TAG, '主体分割服务初始化完成');
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      throw this.toAppError(error as object, '主体分割服务初始化失败，请稍后重试。');
    }
  }

  async segment(pixelMap: image.PixelMap): Promise<SubjectSegmentationOutput> {
    await this.initialize();
    const visionInfo: subjectSegmentation.VisionInfo = { pixelMap: pixelMap };
    const config: subjectSegmentation.SegmentationConfig = {
      maxCount: 20,
      enableSubjectDetails: false,
      enableSubjectForegroundImage: true
    };
    try {
      const result = await subjectSegmentation.doSegmentation(visionInfo, config);
      if (result.subjectCount <= 0 || !result.fullSubject.foregroundImage) {
        throw new AppError(AppErrorCode.IMAGE_PROCESS_FAILED,
          '没有识别到明显主体，请换一张主体更突出、背景区分更清楚的图片。');
      }
      AppLogger.info(TAG, `主体分割完成，主体数=${result.subjectCount}`);
      return new SubjectSegmentationOutput(result.fullSubject.foregroundImage, result.subjectCount);
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      throw this.toAppError(error as object, '主体分割失败，请重试。');
    }
  }

  async release(): Promise<void> {
    if (!this.initialized) {
      return;
    }
    try {
      await subjectSegmentation.release();
    } catch (error) {
      AppLogger.warn(TAG, `释放主体分割服务失败：${JSON.stringify(error)}`);
    } finally {
      this.initialized = false;
    }
  }

  private toAppError(error: object, fallback: string): AppError {
    const businessError = error as BusinessError;
    switch (businessError.code) {
      case 200:
        return new AppError(AppErrorCode.IMAGE_PROCESS_FAILED, '主体分割处理超时，请重试。');
      case 401:
        return new AppError(AppErrorCode.IMAGE_PROCESS_FAILED, '图片不符合主体分割要求，请选择其他图片。');
      case 1011000002:
        return new AppError(AppErrorCode.IMAGE_PROCESS_FAILED, '当前设备的主体分割服务暂不可用，请稍后重试。');
      default:
        return new AppError(AppErrorCode.IMAGE_PROCESS_FAILED,
          businessError.message ? `${fallback}（${businessError.code}: ${businessError.message}）` : fallback);
    }
  }
}
