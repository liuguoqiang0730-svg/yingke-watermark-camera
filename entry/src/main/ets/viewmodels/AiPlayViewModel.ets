import { MediaService } from '../services/MediaService';
import { FaceSimilarityResult, FaceSimilarityService } from '../services/FaceSimilarityService';

export class AiPlayViewModel {
  private readonly mediaService: MediaService = new MediaService();
  private readonly faceSimilarityService: FaceSimilarityService = new FaceSimilarityService();

  async selectPhoto(): Promise<string> {
    return this.mediaService.selectPhoto();
  }

  async compareFaces(firstUri: string, secondUri: string): Promise<FaceSimilarityResult> {
    return this.faceSimilarityService.compare(firstUri, secondUri);
  }
}
