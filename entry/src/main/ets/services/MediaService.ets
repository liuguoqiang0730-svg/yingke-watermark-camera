import { common } from '@kit.AbilityKit';
import { uniformTypeDescriptor } from '@kit.ArkData';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { systemShare } from '@kit.ShareKit';
import { AppError, AppErrorCode } from '../models/AppError';
import { ErrorMessageUtil } from '../utils/ErrorMessageUtil';

class ImageCreationConfig implements photoAccessHelper.PhotoCreationConfig {
  title?: string;
  fileNameExtension: string = 'jpg';
  photoType: photoAccessHelper.PhotoType = photoAccessHelper.PhotoType.IMAGE;

  constructor(title: string) {
    this.title = title;
  }
}

class ImageSharedRecord implements systemShare.SharedRecord {
  utd: string = uniformTypeDescriptor.UniformDataType.JPEG;
  uri?: string;
  title?: string;
  description?: string;

  constructor(uri: string) {
    this.uri = uri;
    this.title = '映刻水印照片';
    this.description = '由映刻水印相机在本地生成';
  }
}

class SingleShareOptions implements systemShare.ShareControllerOptions {
  selectionMode?: systemShare.SelectionMode = systemShare.SelectionMode.SINGLE;
  previewMode?: systemShare.SharePreviewMode = systemShare.SharePreviewMode.DETAIL;
}

export class MediaService {
  async selectPhoto(): Promise<string> {
    try {
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      options.isOriginalSupported = true;
      const result = await new photoAccessHelper.PhotoViewPicker().select(options);
      if (result.photoUris.length === 0) {
        throw new AppError(AppErrorCode.USER_CANCELLED, '未选择照片。');
      }
      return result.photoUris[0];
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      throw new AppError(AppErrorCode.USER_CANCELLED,
        ErrorMessageUtil.from(error as object, '选图已取消或无法读取所选照片。'));
    }
  }

  async saveToGallery(context: common.UIAbilityContext, fileUri: string): Promise<string> {
    try {
      const helper = photoAccessHelper.getPhotoAccessHelper(context);
      const title = `映刻_${Date.now()}`;
      const result = await helper.showAssetsCreationDialog([fileUri], [new ImageCreationConfig(title)]);
      if (result.length === 0) {
        throw new AppError(AppErrorCode.SAVE_FAILED, '没有生成相册资源。');
      }
      return result[0];
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      throw new AppError(AppErrorCode.SAVE_FAILED,
        ErrorMessageUtil.from(error as object, '保存到相册失败，请检查存储空间后重试。'));
    }
  }

  async share(context: common.UIAbilityContext, fileUri: string): Promise<void> {
    try {
      const data = new systemShare.SharedData(new ImageSharedRecord(fileUri));
      const controller = new systemShare.ShareController(data);
      await controller.show(context, new SingleShareOptions());
    } catch (error) {
      throw new AppError(AppErrorCode.SHARE_FAILED,
        ErrorMessageUtil.from(error as object, '无法打开系统分享面板。'));
    }
  }
}
