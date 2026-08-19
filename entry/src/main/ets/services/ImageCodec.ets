import { image } from '@kit.ImageKit';
import { AppError, AppErrorCode } from '../models/AppError';
import { ImageProcessResult } from '../models/ImageProcessResult';
import { ErrorMessageUtil } from '../utils/ErrorMessageUtil';

const MAX_EDGE: number = 3072;

class TargetSize implements image.Size {
  width: number;
  height: number;

  constructor(width: number, height: number) {
    this.width = width;
    this.height = height;
  }
}

class DecodeOptions implements image.DecodingOptions {
  editable: boolean = true;
  desiredPixelFormat: image.PixelMapFormat = image.PixelMapFormat.RGBA_8888;
  desiredSize?: image.Size;

  constructor(size: image.Size) {
    this.desiredSize = size;
  }
}

class JpegPackingOptions implements image.PackingOption {
  format: string = 'image/jpeg';
  quality: number = 92;
  needsPackProperties: boolean = false;
}

export class ImageCodec {
  async decode(uri: string): Promise<ImageProcessResult> {
    const source = image.createImageSource(uri);
    if (!source) {
      throw new AppError(AppErrorCode.IMAGE_DECODE_FAILED, '无法读取所选图片。');
    }
    try {
      const info = await source.getImageInfo();
      const size = this.fitSize(info.size.width, info.size.height);
      let orientation: string = 'Top-left';
      try {
        orientation = await source.getImageProperty(image.PropertyKey.ORIENTATION);
      } catch (_) {
        orientation = 'Top-left';
      }
      const pixelMap = await source.createPixelMap(new DecodeOptions(size));
      await this.applyOrientation(pixelMap, orientation);
      const resultInfo = await pixelMap.getImageInfo();
      return new ImageProcessResult(pixelMap, resultInfo.size.width, resultInfo.size.height);
    } catch (error) {
      throw new AppError(AppErrorCode.IMAGE_DECODE_FAILED,
        ErrorMessageUtil.from(error as object, '图片解码失败，请选择其他图片。'));
    } finally {
      await source.release();
    }
  }

  async encodeJpeg(pixelMap: image.PixelMap): Promise<ArrayBuffer> {
    const packer = image.createImagePacker();
    try {
      return await packer.packToData(pixelMap, new JpegPackingOptions());
    } catch (error) {
      throw new AppError(AppErrorCode.IMAGE_PROCESS_FAILED,
        ErrorMessageUtil.from(error as object, '图片编码失败，请重试。'));
    } finally {
      await packer.release();
    }
  }

  private fitSize(width: number, height: number): image.Size {
    const longEdge = Math.max(width, height);
    if (longEdge <= MAX_EDGE) {
      return new TargetSize(width, height);
    }
    const scale = MAX_EDGE / longEdge;
    return new TargetSize(Math.max(1, Math.round(width * scale)), Math.max(1, Math.round(height * scale)));
  }

  private async applyOrientation(pixelMap: image.PixelMap, orientation: string): Promise<void> {
    switch (orientation) {
      case 'Top-right':
      case '2':
        await pixelMap.flip(true, false);
        break;
      case 'Bottom-right':
      case '3':
        await pixelMap.rotate(180);
        break;
      case 'Bottom-left':
      case '4':
        await pixelMap.flip(false, true);
        break;
      case 'Left-top':
      case '5':
        await pixelMap.flip(true, false);
        await pixelMap.rotate(270);
        break;
      case 'Right-top':
      case '6':
        await pixelMap.rotate(90);
        break;
      case 'Right-bottom':
      case '7':
        await pixelMap.flip(true, false);
        await pixelMap.rotate(90);
        break;
      case 'Left-bottom':
      case '8':
        await pixelMap.rotate(270);
        break;
      default:
        break;
    }
  }
}
