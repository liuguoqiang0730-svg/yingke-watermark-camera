import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { ImageProcessResult } from '../models/ImageProcessResult';
import { WatermarkConfig } from '../models/WatermarkConfig';
import { ImageCodec } from '../services/ImageCodec';
import { ImageComposer } from '../services/ImageComposer';
import { MediaService } from '../services/MediaService';
import { TempFileManager } from '../services/TempFileManager';

export class ResultViewModel {
  private readonly codec: ImageCodec = new ImageCodec();
  private readonly composer: ImageComposer = new ImageComposer();
  private readonly media: MediaService = new MediaService();
  private source: image.PixelMap | undefined = undefined;
  private output: image.PixelMap | undefined = undefined;
  private outputUri: string = '';

  async load(uri: string): Promise<ImageProcessResult> {
    await this.release();
    const result = await this.codec.decode(uri);
    this.source = result.pixelMap;
    return result;
  }

  async apply(context: common.UIAbilityContext, config: WatermarkConfig,
    logoResource: Resource): Promise<image.PixelMap> {
    if (!this.source) {
      throw new Error('原始图片尚未加载。');
    }
    await this.output?.release();
    this.output = await this.composer.compose(context, this.source, config, logoResource);
    if (this.outputUri) {
      TempFileManager.cleanup(this.outputUri);
      this.outputUri = '';
    }
    return this.output;
  }

  async prepareOutput(context: common.UIAbilityContext): Promise<string> {
    const pixelMap = this.output ? this.output : this.source;
    if (!pixelMap) {
      throw new Error('没有可导出的图片。');
    }
    if (!this.outputUri) {
      const buffer = await this.codec.encodeJpeg(pixelMap);
      this.outputUri = TempFileManager.writeBuffer(context, buffer, 'watermark', 'jpg');
    }
    return this.outputUri;
  }

  async save(context: common.UIAbilityContext): Promise<string> {
    return this.media.saveToGallery(context, await this.prepareOutput(context));
  }

  async share(context: common.UIAbilityContext): Promise<void> {
    await this.media.share(context, await this.prepareOutput(context));
  }

  async release(): Promise<void> {
    await this.output?.release();
    await this.source?.release();
    this.output = undefined;
    this.source = undefined;
    if (this.outputUri) {
      TempFileManager.cleanup(this.outputUri);
      this.outputUri = '';
    }
  }
}
