import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { WatermarkConfig } from '../models/WatermarkConfig';
import { ImageCodec } from '../services/ImageCodec';
import { ImageComposer } from '../services/ImageComposer';
import { MediaService } from '../services/MediaService';
import { TempFileManager } from '../services/TempFileManager';
import { AppLogger } from '../utils/AppLogger';

const TAG: string = 'ResultViewModel';

export class PreviewImageResult {
  uri: string;
  width: number;
  height: number;

  constructor(uri: string, width: number, height: number) {
    this.uri = uri;
    this.width = width;
    this.height = height;
  }
}

export class ResultViewModel {
  private readonly codec: ImageCodec = new ImageCodec();
  private readonly composer: ImageComposer = new ImageComposer();
  private readonly media: MediaService = new MediaService();
  private sourceUri: string = '';
  private previewUri: string = '';
  private outputUri: string = '';

  async load(context: common.UIAbilityContext, uri: string): Promise<PreviewImageResult> {
    const startedAt = Date.now();
    await this.release();
    this.sourceUri = uri;
    AppLogger.info(TAG, `开始读取预览图片，来源=${uri.startsWith('file://media') ? 'album' : 'local'}`);
    const result = await this.codec.decodePreview(uri);
    try {
      const previewUri = await this.updatePreviewFile(context, result.pixelMap);
      AppLogger.info(TAG,
        `预览图片读取完成：${result.width}x${result.height}，耗时=${Date.now() - startedAt}ms`);
      return new PreviewImageResult(previewUri, result.width, result.height);
    } finally {
      await result.pixelMap.release();
    }
  }

  async prepareOutput(context: common.UIAbilityContext, config: WatermarkConfig,
    logoResource: Resource): Promise<string> {
    if (!this.sourceUri) {
      throw new Error('没有可导出的图片。');
    }
    if (this.outputUri) {
      return this.outputUri;
    }

    const startedAt = Date.now();
    let exportSource: image.PixelMap | undefined = undefined;
    let exportOutput: image.PixelMap | undefined = undefined;
    try {
      AppLogger.info(TAG, '开始生成高清水印成片');
      const result = await this.codec.decodeForExport(this.sourceUri);
      exportSource = result.pixelMap;
      exportOutput = await this.composer.compose(context, exportSource, config, logoResource);
      const buffer = await this.codec.encodeJpeg(exportOutput);
      this.outputUri = TempFileManager.writeBuffer(context, buffer, 'watermark', 'jpg');
      AppLogger.info(TAG,
        `高清水印成片生成完成：${result.width}x${result.height}，耗时=${Date.now() - startedAt}ms`);
      return this.outputUri;
    } finally {
      await exportOutput?.release();
      await exportSource?.release();
    }
  }

  async save(context: common.UIAbilityContext, config: WatermarkConfig,
    logoResource: Resource): Promise<string> {
    return this.media.saveToGallery(context,
      await this.prepareOutput(context, config, logoResource));
  }

  async share(context: common.UIAbilityContext, config: WatermarkConfig,
    logoResource: Resource): Promise<void> {
    await this.media.share(context,
      await this.prepareOutput(context, config, logoResource));
  }

  async saveSource(context: common.UIAbilityContext): Promise<string> {
    if (!this.sourceUri) {
      throw new Error('没有可保存的图片。');
    }
    return this.media.saveToGallery(context, this.sourceUri);
  }

  async shareSource(context: common.UIAbilityContext): Promise<void> {
    if (!this.sourceUri) {
      throw new Error('没有可分享的图片。');
    }
    await this.media.share(context, this.sourceUri);
  }

  invalidateOutput(): void {
    this.cleanupOutput();
  }

  async release(): Promise<void> {
    this.sourceUri = '';
    this.cleanupPreview();
    this.cleanupOutput();
  }

  private async updatePreviewFile(context: common.UIAbilityContext,
    pixelMap: image.PixelMap): Promise<string> {
    const buffer = await this.codec.encodeJpeg(pixelMap);
    const nextUri = TempFileManager.writeBuffer(context, buffer, 'source_preview', 'jpg');
    this.cleanupPreview();
    this.previewUri = nextUri;
    return nextUri;
  }

  private cleanupPreview(): void {
    if (!this.previewUri) {
      return;
    }
    TempFileManager.cleanup(this.previewUri);
    this.previewUri = '';
  }

  private cleanupOutput(): void {
    if (!this.outputUri) {
      return;
    }
    TempFileManager.cleanup(this.outputUri);
    this.outputUri = '';
  }
}
