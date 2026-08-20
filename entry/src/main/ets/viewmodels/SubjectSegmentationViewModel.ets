import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { ImageCodec } from '../services/ImageCodec';
import { MediaService } from '../services/MediaService';
import { SubjectSegmentationService } from '../services/SubjectSegmentationService';
import { TempFileManager } from '../services/TempFileManager';

export enum SubjectBackgroundMode {
  TRANSPARENT = 'transparent',
  SOLID = 'solid',
  IMAGE = 'image'
}

export class SegmentedImageInfo {
  foreground: image.PixelMap;
  width: number;
  height: number;
  subjectCount: number;

  constructor(foreground: image.PixelMap, width: number, height: number, subjectCount: number) {
    this.foreground = foreground;
    this.width = width;
    this.height = height;
    this.subjectCount = subjectCount;
  }
}

export class SubjectSegmentationViewModel {
  private readonly codec: ImageCodec = new ImageCodec();
  private readonly media: MediaService = new MediaService();
  private readonly segmentation: SubjectSegmentationService = new SubjectSegmentationService();
  private foreground: image.PixelMap | undefined = undefined;
  private background: image.PixelMap | undefined = undefined;
  private outputUri: string = '';
  private outputKey: string = '';

  async process(sourceUri: string): Promise<SegmentedImageInfo> {
    this.clearOutput();
    await this.releaseForeground();
    const decoded = await this.codec.decodeForExport(sourceUri);
    try {
      const result = await this.segmentation.segment(decoded.pixelMap);
      this.foreground = result.foreground;
      const info = await result.foreground.getImageInfo();
      return new SegmentedImageInfo(result.foreground, info.size.width, info.size.height, result.subjectCount);
    } finally {
      await decoded.pixelMap.release();
    }
  }

  async selectPhoto(): Promise<string> {
    return this.media.selectPhoto();
  }

  async setCustomBackground(uri: string): Promise<image.PixelMap> {
    const decoded = await this.codec.decodeForExport(uri);
    await this.releaseBackground();
    this.background = decoded.pixelMap;
    this.clearOutput();
    return decoded.pixelMap;
  }

  invalidateOutput(): void {
    this.clearOutput();
  }

  async save(context: common.UIAbilityContext, mode: SubjectBackgroundMode, color: string): Promise<string> {
    const uri = await this.prepareOutput(context, mode, color);
    return this.media.saveToGallery(context, uri);
  }

  async share(context: common.UIAbilityContext, mode: SubjectBackgroundMode, color: string): Promise<void> {
    await this.media.share(context, await this.prepareOutput(context, mode, color));
  }

  async release(): Promise<void> {
    this.clearOutput();
    await this.releaseBackground();
    await this.releaseForeground();
    await this.segmentation.release();
  }

  private async prepareOutput(context: common.UIAbilityContext,
    mode: SubjectBackgroundMode, color: string): Promise<string> {
    if (!this.foreground) {
      throw new Error('没有可导出的主体分割结果。');
    }
    const key = `${mode}:${color}`;
    if (this.outputUri && this.outputKey === key) {
      return this.outputUri;
    }
    this.clearOutput();

    if (mode === SubjectBackgroundMode.TRANSPARENT) {
      const data = await this.codec.encodePng(this.foreground);
      this.outputUri = TempFileManager.writeBuffer(context, data, 'subject_transparent', 'png');
    } else {
      const composed = await this.composeBackground(this.foreground, mode, color);
      try {
        const data = await this.codec.encodeJpeg(composed);
        this.outputUri = TempFileManager.writeBuffer(context, data, 'subject_background', 'jpg');
      } finally {
        await composed.release();
      }
    }
    this.outputKey = key;
    return this.outputUri;
  }

  private async composeBackground(foreground: image.PixelMap,
    mode: SubjectBackgroundMode, color: string): Promise<image.PixelMap> {
    const info = await foreground.getImageInfo();
    const width = info.size.width;
    const height = info.size.height;
    const canvas = new OffscreenCanvas(width, height);
    const drawing = canvas.getContext('2d', new RenderingContextSettings(true));
    drawing.fillStyle = color;
    drawing.fillRect(0, 0, width, height);

    if (mode === SubjectBackgroundMode.IMAGE && this.background) {
      const backgroundInfo = await this.background.getImageInfo();
      const sourceWidth = backgroundInfo.size.width;
      const sourceHeight = backgroundInfo.size.height;
      const scale = Math.max(width / sourceWidth, height / sourceHeight);
      const cropWidth = width / scale;
      const cropHeight = height / scale;
      const sourceX = (sourceWidth - cropWidth) / 2;
      const sourceY = (sourceHeight - cropHeight) / 2;
      drawing.drawImage(this.background, sourceX, sourceY, cropWidth, cropHeight, 0, 0, width, height);
    }
    drawing.drawImage(foreground, 0, 0, width, height);
    return drawing.getPixelMap(0, 0, width, height);
  }

  private clearOutput(): void {
    if (this.outputUri) {
      TempFileManager.cleanup(this.outputUri);
    }
    this.outputUri = '';
    this.outputKey = '';
  }

  private async releaseForeground(): Promise<void> {
    if (this.foreground) {
      await this.foreground.release();
      this.foreground = undefined;
    }
  }

  private async releaseBackground(): Promise<void> {
    if (this.background) {
      await this.background.release();
      this.background = undefined;
    }
  }
}
