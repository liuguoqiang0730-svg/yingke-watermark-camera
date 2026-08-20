import { image } from '@kit.ImageKit';
import { FaceSimilarityResult, FaceSimilarityService } from '../services/FaceSimilarityService';
import { MediaService } from '../services/MediaService';

export class FaceSimilarityViewModel {
  private readonly mediaService: MediaService = new MediaService();
  private readonly faceSimilarityService: FaceSimilarityService = new FaceSimilarityService();

  async selectPhoto(): Promise<image.PixelMap> {
    const uri = await this.mediaService.selectPhoto();
    return this.faceSimilarityService.loadPixelMap(uri);
  }

  async compareFaces(firstImage: image.PixelMap,
    secondImage: image.PixelMap): Promise<FaceSimilarityResult> {
    return this.faceSimilarityService.comparePixelMaps(firstImage, secondImage);
  }

  async releasePixelMap(pixelMap: image.PixelMap | undefined): Promise<void> {
    await this.faceSimilarityService.releasePixelMap(pixelMap);
  }
}
