import { common } from '@kit.AbilityKit';
import { CollageConfig } from '../models/CollageConfig';
import { CollageComposer } from '../services/CollageComposer';
import { ImageCodec } from '../services/ImageCodec';
import { MediaService } from '../services/MediaService';
import { TempFileManager } from '../services/TempFileManager';

export class CollageViewModel {
  private readonly media: MediaService = new MediaService();
  private readonly composer: CollageComposer = new CollageComposer();
  private readonly codec: ImageCodec = new ImageCodec();
  private outputUri: string = '';

  async selectPhotos(maxCount: number): Promise<string[]> {
    return this.media.selectPhotos(maxCount);
  }

  async generate(context: common.UIAbilityContext,
    uris: string[], config: CollageConfig): Promise<string> {
    this.discardOutput();
    const pixelMap = await this.composer.compose(uris, config);
    try {
      const buffer = await this.codec.encodeJpeg(pixelMap);
      this.outputUri = TempFileManager.writeBuffer(context, buffer, 'collage', 'jpg');
      return this.outputUri;
    } finally {
      await pixelMap.release();
    }
  }

  transferOutput(): void {
    this.outputUri = '';
  }

  discardOutput(): void {
    if (!this.outputUri) {
      return;
    }
    TempFileManager.cleanup(this.outputUri);
    this.outputUri = '';
  }
}
