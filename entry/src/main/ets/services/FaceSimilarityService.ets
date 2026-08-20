import { faceComparator } from '@kit.CoreVisionKit';
import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { AppError, AppErrorCode } from '../models/AppError';
import { ErrorMessageUtil } from '../utils/ErrorMessageUtil';

const VISION_MAX_EDGE: number = 2048;

class VisionSize implements image.Size {
  width: number;
  height: number;

  constructor(width: number, height: number) {
    this.width = width;
    this.height = height;
  }
}

class VisionDecodeOptions implements image.DecodingOptions {
  editable: boolean = true;
  desiredPixelFormat: image.PixelMapFormat = image.PixelMapFormat.RGBA_8888;
  desiredSize?: image.Size;

  constructor(size: image.Size) {
    this.desiredSize = size;
  }
}

export class FaceSimilarityResult {
  similarity: number;
  isSamePerson: boolean;

  constructor(similarity: number, isSamePerson: boolean) {
    this.similarity = similarity;
    this.isSamePerson = isSamePerson;
  }
}

export class FaceSimilarityService {
  async compare(firstUri: string, secondUri: string): Promise<FaceSimilarityResult> {
    let firstPixelMap: image.PixelMap | undefined = undefined;
    let secondPixelMap: image.PixelMap | undefined = undefined;
    try {
      firstPixelMap = await this.loadPixelMap(firstUri);
      secondPixelMap = await this.loadPixelMap(secondUri);
      return await this.comparePixelMaps(firstPixelMap, secondPixelMap);
    } finally {
      await this.releasePixelMap(secondPixelMap);
      await this.releasePixelMap(firstPixelMap);
    }
  }

  async loadPixelMap(uri: string): Promise<image.PixelMap> {
    try {
      return await this.decode(uri);
    } catch (error) {
      throw new AppError(AppErrorCode.IMAGE_DECODE_FAILED,
        ErrorMessageUtil.from(error as object, '图片读取失败，请选择其他照片。'));
    }
  }

  async comparePixelMaps(firstPixelMap: image.PixelMap,
    secondPixelMap: image.PixelMap): Promise<FaceSimilarityResult> {
    try {
      const firstVisionInfo: faceComparator.VisionInfo = {
        pixelMap: firstPixelMap
      };
      const secondVisionInfo: faceComparator.VisionInfo = {
        pixelMap: secondPixelMap
      };
      const result = await faceComparator.compareFaces(firstVisionInfo, secondVisionInfo);
      return new FaceSimilarityResult(this.clamp(result.similarity), result.isSamePerson);
    } catch (error) {
      throw new AppError(AppErrorCode.IMAGE_PROCESS_FAILED,
        ErrorMessageUtil.from(error as object, '识别失败，请确保两张照片中都包含清晰的正面人脸。'));
    }
  }

  private clamp(value: number): number {
    return Math.max(0, Math.min(1, value));
  }

  private async decode(uri: string): Promise<image.PixelMap> {
    let file: fileIo.File | undefined = undefined;
    let source: image.ImageSource | undefined = undefined;
    let pixelMap: image.PixelMap | undefined = undefined;
    try {
      try {
        source = image.createImageSource(uri);
      } catch (_) {
      }
      if (!source) {
        file = await fileIo.open(uri, fileIo.OpenMode.READ_ONLY);
        source = image.createImageSource(file.fd);
      }
      if (!source) {
        throw new Error('无法创建图片解码器。');
      }
      const info = await source.getImageInfo();
      const size = this.fitSize(info.size.width, info.size.height);
      let orientation: string = 'Top-left';
      try {
        orientation = await source.getImageProperty(image.PropertyKey.ORIENTATION);
      } catch (_) {
      }
      pixelMap = await source.createPixelMap(new VisionDecodeOptions(size));
      await this.applyOrientation(pixelMap, orientation);
      return pixelMap;
    } catch (error) {
      await this.releasePixelMap(pixelMap);
      throw new Error(ErrorMessageUtil.from(error as object, '图片解码失败。'));
    } finally {
      try {
        await source?.release();
      } catch (_) {
      }
      if (file) {
        try {
          fileIo.closeSync(file);
        } catch (_) {
        }
      }
    }
  }

  private fitSize(width: number, height: number): image.Size {
    const longEdge = Math.max(width, height);
    if (longEdge <= VISION_MAX_EDGE) {
      return new VisionSize(width, height);
    }
    const scale = VISION_MAX_EDGE / longEdge;
    return new VisionSize(Math.max(1, Math.round(width * scale)), Math.max(1, Math.round(height * scale)));
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

  async releasePixelMap(pixelMap: image.PixelMap | undefined): Promise<void> {
    try {
      await pixelMap?.release();
    } catch (_) {
    }
  }
}
