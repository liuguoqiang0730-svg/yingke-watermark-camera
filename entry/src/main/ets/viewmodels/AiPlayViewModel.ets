import { common } from '@kit.AbilityKit';
import { AppError, AppErrorCode } from '../models/AppError';
import { ObjectDetectionResult } from '../models/ObjectDetectionResult';
import { ImageCodec } from '../services/ImageCodec';
import { MediaService } from '../services/MediaService';
import { ObjectDetectionService } from '../services/ObjectDetectionService';
import { TempFileManager } from '../services/TempFileManager';

export class AiPlayViewModel {
  private readonly mediaService: MediaService = new MediaService();
  private readonly imageCodec: ImageCodec = new ImageCodec();
  private readonly objectDetectionService: ObjectDetectionService = new ObjectDetectionService();
  private detectionPreviewUri: string = '';

  async selectPhoto(): Promise<string> {
    return this.mediaService.selectPhoto();
  }

  async recognizeObjects(context: common.UIAbilityContext, uri: string): Promise<ObjectDetectionResult> {
    const imageResult = await this.imageCodec.decodeForExport(uri);
    try {
      if (imageResult.width < 100 || imageResult.height < 100) {
        throw new AppError(AppErrorCode.OBJECT_DETECTION_FAILED,
          '图片尺寸过小，请选择宽高均大于 100 像素的图片。');
      }
      const objects = await this.objectDetectionService.detect(imageResult.pixelMap,
        imageResult.width, imageResult.height);
      const previewData = await this.imageCodec.encodeJpeg(imageResult.pixelMap);
      const nextPreviewUri = TempFileManager.writeBuffer(context, previewData, 'object_detection', 'jpg');
      this.cleanupDetectionPreview();
      this.detectionPreviewUri = nextPreviewUri;
      return new ObjectDetectionResult(nextPreviewUri, imageResult.width, imageResult.height, objects);
    } finally {
      await imageResult.pixelMap.release();
    }
  }

  async release(): Promise<void> {
    await this.objectDetectionService.release();
    this.cleanupDetectionPreview();
  }

  private cleanupDetectionPreview(): void {
    if (!this.detectionPreviewUri) {
      return;
    }
    TempFileManager.cleanup(this.detectionPreviewUri);
    this.detectionPreviewUri = '';
  }
}
