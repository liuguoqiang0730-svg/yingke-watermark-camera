import { pasteboard } from '@kit.BasicServicesKit';
import { AppError, AppErrorCode } from '../models/AppError';
import { MediaService } from '../services/MediaService';
import { TextRecognitionService } from '../services/TextRecognitionService';
import { ErrorMessageUtil } from '../utils/ErrorMessageUtil';

export class TextRecognitionViewModel {
  private readonly mediaService: MediaService = new MediaService();
  private readonly textRecognitionService: TextRecognitionService = new TextRecognitionService();

  async initialize(): Promise<void> {
    return this.textRecognitionService.initialize();
  }

  async selectPhoto(): Promise<string> {
    return this.mediaService.selectPhoto();
  }

  async recognize(uri: string): Promise<string> {
    return this.textRecognitionService.recognize(uri);
  }

  async copyText(text: string): Promise<void> {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      await pasteboard.getSystemPasteboard().setData(data);
    } catch (error) {
      throw new AppError(AppErrorCode.UNKNOWN,
        ErrorMessageUtil.from(error as object, '无法复制识别文字。'));
    }
  }

  async release(): Promise<void> {
    return this.textRecognitionService.release();
  }
}
