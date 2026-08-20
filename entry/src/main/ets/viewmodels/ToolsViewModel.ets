import { MediaService } from '../services/MediaService';

export class ToolsViewModel {
  private readonly mediaService: MediaService = new MediaService();

  async selectPhoto(): Promise<string> {
    return this.mediaService.selectPhoto();
  }
}
