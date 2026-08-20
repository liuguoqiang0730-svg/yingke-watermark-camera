import { BusinessError } from '@kit.BasicServicesKit';
import { objectDetection, visionBase } from '@kit.CoreVisionKit';
import { image } from '@kit.ImageKit';
import { AppError, AppErrorCode } from '../models/AppError';
import { DetectedObject, DetectionBox } from '../models/ObjectDetectionResult';
import { ErrorMessageUtil } from '../utils/ErrorMessageUtil';

export class ObjectDetectionService {
  private detector: objectDetection.ObjectDetector | undefined = undefined;
  private creating: Promise<objectDetection.ObjectDetector> | undefined = undefined;
  private processing: Promise<DetectedObject[]> | undefined = undefined;

  async detect(pixelMap: image.PixelMap, imageWidth: number, imageHeight: number): Promise<DetectedObject[]> {
    if (this.processing) {
      throw new AppError(AppErrorCode.OBJECT_DETECTION_FAILED, '正在识别上一张图片，请稍候。');
    }
    this.processing = this.process(pixelMap, imageWidth, imageHeight);
    try {
      return await this.processing;
    } finally {
      this.processing = undefined;
    }
  }

  async release(): Promise<void> {
    if (this.processing) {
      try {
        await this.processing;
      } catch (_) {
      }
    }
    if (this.creating) {
      try {
        await this.creating;
      } catch (_) {
      }
    }
    const currentDetector = this.detector;
    this.detector = undefined;
    if (currentDetector) {
      try {
        await currentDetector.destroy();
      } catch (_) {
      }
    }
  }

  private async process(pixelMap: image.PixelMap, imageWidth: number,
    imageHeight: number): Promise<DetectedObject[]> {
    try {
      const detector = await this.getDetector();
      const request: visionBase.Request = {
        inputData: { pixelMap: pixelMap },
        scene: visionBase.SceneMode.FOREGROUND,
        requestId: `object_${Date.now()}`
      };
      const response = await detector.process(request);
      return response.objects.map((item: objectDetection.VisionObject): DetectedObject => {
        const left = this.clamp(item.boundingBox.left, 0, imageWidth);
        const top = this.clamp(item.boundingBox.top, 0, imageHeight);
        const width = this.clamp(item.boundingBox.width, 0, imageWidth - left);
        const height = this.clamp(item.boundingBox.height, 0, imageHeight - top);
        return new DetectedObject(item.id, this.labelText(item.labels),
          this.clamp(item.score, 0, 1), new DetectionBox(left, top, width, height));
      }).sort((first: DetectedObject, second: DetectedObject): number => second.score - first.score);
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      const businessError = error as BusinessError;
      if (businessError.code === 1011000004) {
        throw new AppError(AppErrorCode.OBJECT_DETECTION_FAILED, '画面识别超时，请稍后重试。');
      }
      if (businessError.code === 1011000003) {
        throw new AppError(AppErrorCode.OBJECT_DETECTION_FAILED, '端侧识别模型运行失败，请换一张图片重试。');
      }
      throw new AppError(AppErrorCode.OBJECT_DETECTION_FAILED,
        ErrorMessageUtil.from(error as object, '当前设备暂时无法完成画面识别。'));
    }
  }

  private async getDetector(): Promise<objectDetection.ObjectDetector> {
    if (this.detector) {
      return this.detector;
    }
    try {
      if (!this.creating) {
        this.creating = objectDetection.ObjectDetector.create();
      }
      this.detector = await this.creating;
      return this.detector;
    } catch (error) {
      throw new AppError(AppErrorCode.OBJECT_DETECTION_FAILED,
        ErrorMessageUtil.from(error as object, '画面识别服务初始化失败。'));
    } finally {
      this.creating = undefined;
    }
  }

  private labelText(labels: number[]): string {
    if (labels.length === 0) {
      return '未分类目标';
    }
    return labels.map((label: number): string => this.labelName(label)).join('、');
  }

  private labelName(label: number): string {
    switch (label) {
      case 0:
        return '场景';
      case 1:
        return '动物';
      case 2:
        return '植物';
      case 3:
        return '建筑';
      case 5:
        return '人脸';
      case 6:
        return '表格';
      case 7:
        return '文字';
      case 8:
        return '人物头部';
      case 9:
        return '猫';
      case 10:
        return '狗';
      case 11:
        return '食物';
      case 12:
        return '汽车';
      case 13:
        return '人物';
      case 21:
        return '文档';
      case 22:
        return '卡片';
      default:
        return `类别 ${label}`;
    }
  }

  private clamp(value: number, min: number, max: number): number {
    return Math.max(min, Math.min(max, value));
  }
}
