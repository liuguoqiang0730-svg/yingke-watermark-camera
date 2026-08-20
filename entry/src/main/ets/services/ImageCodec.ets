import { image } from '@kit.ImageKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { AppError, AppErrorCode } from '../models/AppError';
import { ImageProcessResult } from '../models/ImageProcessResult';
import { ErrorMessageUtil } from '../utils/ErrorMessageUtil';

const PREVIEW_MAX_EDGE: number = 1280;
const EXPORT_MAX_EDGE: number = 3072;

class ImageSourceHandle {
  source: image.ImageSource;
  file: fileIo.File | undefined;

  constructor(source: image.ImageSource, file?: fileIo.File) {
    this.source = source;
    this.file = file;
  }
}

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

class PngPackingOptions implements image.PackingOption {
  format: string = 'image/png';
  quality: number = 100;
  needsPackProperties: boolean = false;
}

export class ImageCodec {
  async decodePreview(uri: string): Promise<ImageProcessResult> {
    return this.decode(uri, PREVIEW_MAX_EDGE);
  }

  async decodeForExport(uri: string): Promise<ImageProcessResult> {
    return this.decode(uri, EXPORT_MAX_EDGE);
  }

  private async decode(uri: string, maxEdge: number): Promise<ImageProcessResult> {
    let handle: ImageSourceHandle | undefined = undefined;
    try {
      handle = this.createSource(uri);
      const info = await handle.source.getImageInfo();
      const size = this.fitSize(info.size.width, info.size.height, maxEdge);
      let orientation: string = 'Top-left';
      try {
        orientation = await handle.source.getImageProperty(image.PropertyKey.ORIENTATION);
      } catch (_) {
        orientation = 'Top-left';
      }
      const pixelMap = await handle.source.createPixelMap(new DecodeOptions(size));
      await this.applyOrientation(pixelMap, orientation);
      const resultInfo = await pixelMap.getImageInfo();
      return new ImageProcessResult(pixelMap, resultInfo.size.width, resultInfo.size.height);
    } catch (error) {
      throw new AppError(AppErrorCode.IMAGE_DECODE_FAILED,
        ErrorMessageUtil.from(error as object, '图片解码失败，请选择其他图片。'));
    } finally {
      await handle?.source.release();
      if (handle?.file) {
        this.closeFile(handle.file);
      }
    }
  }

  private createSource(uri: string): ImageSourceHandle {
    let source = image.createImageSource(uri);
    if (source) {
      return new ImageSourceHandle(source);
    }
    if (!uri.startsWith('file://')) {
      throw new AppError(AppErrorCode.IMAGE_DECODE_FAILED, '无法读取所选图片。');
    }

    const path = new fileUri.FileUri(uri).path;
    let file: fileIo.File;
    try {
      file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
    } catch (error) {
      throw new AppError(AppErrorCode.IMAGE_DECODE_FAILED,
        ErrorMessageUtil.from(error as object, '无法打开本地图片文件。'));
    }
    source = image.createImageSource(file.fd);
    if (!source) {
      this.closeFile(file);
      throw new AppError(AppErrorCode.IMAGE_DECODE_FAILED, '无法读取本地图片文件。');
    }
    return new ImageSourceHandle(source, file);
  }

  private closeFile(file: fileIo.File): void {
    try {
      fileIo.closeSync(file);
    } catch (_) {
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

  async encodePng(pixelMap: image.PixelMap): Promise<ArrayBuffer> {
    const packer = image.createImagePacker();
    try {
      return await packer.packToData(pixelMap, new PngPackingOptions());
    } catch (error) {
      throw new AppError(AppErrorCode.IMAGE_PROCESS_FAILED,
        ErrorMessageUtil.from(error as object, '透明图片编码失败，请重试。'));
    } finally {
      await packer.release();
    }
  }

  private fitSize(width: number, height: number, maxEdge: number): image.Size {
    const longEdge = Math.max(width, height);
    if (longEdge <= maxEdge) {
      return new TargetSize(width, height);
    }
    const scale = maxEdge / longEdge;
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
