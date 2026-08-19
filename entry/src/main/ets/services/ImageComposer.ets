import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { AppError, AppErrorCode } from '../models/AppError';
import { WatermarkConfig, WatermarkPosition } from '../models/WatermarkConfig';
import { ErrorMessageUtil } from '../utils/ErrorMessageUtil';

class DrawPoint {
  x: number;
  y: number;

  constructor(x: number, y: number) {
    this.x = x;
    this.y = y;
  }
}

export class ImageComposer {
  async compose(context: common.UIAbilityContext, source: image.PixelMap,
    config: WatermarkConfig, logoResource: Resource): Promise<image.PixelMap> {
    let logo: image.PixelMap | undefined = undefined;
    let logoSource: image.ImageSource | undefined = undefined;
    try {
      const info = await source.getImageInfo();
      const canvas = new OffscreenCanvas(info.size.width, info.size.height);
      const drawing = canvas.getContext('2d', new RenderingContextSettings(true));
      drawing.drawImage(source, 0, 0, info.size.width, info.size.height);

      const fontSize = Math.max(24, Math.round(info.size.width * config.textSizePercent / 100));
      let logoWidth = 0;
      let logoHeight = 0;
      if (config.showLogo) {
        const media = await context.resourceManager.getMediaContent(logoResource.id);
        logoSource = image.createImageSource(media.buffer as ArrayBuffer);
        logo = await logoSource.createPixelMap();
        const logoInfo = await logo.getImageInfo();
        logoWidth = Math.round(info.size.width * config.logoSizePercent / 100);
        logoHeight = Math.round(logoWidth * logoInfo.size.height / logoInfo.size.width);
      }

      drawing.font = `bold ${fontSize}px sans-serif`;
      const textWidth = config.showText ? drawing.measureText(config.text).width : 0;
      const gap = Math.round(fontSize * 0.35);
      const textHeight = config.showText ? Math.round(fontSize * 1.4) : 0;
      const groupWidth = Math.max(logoWidth, Math.ceil(textWidth));
      const groupHeight = logoHeight + (logoHeight > 0 && textHeight > 0 ? gap : 0) + textHeight;
      const point = this.resolvePosition(info.size.width, info.size.height,
        groupWidth, groupHeight, config.position);

      drawing.globalAlpha = config.opacity;
      if (logo) {
        drawing.drawImage(logo, point.x, point.y, logoWidth, logoHeight);
      }
      if (config.showText && config.text.length > 0) {
        const textY = point.y + logoHeight + (logoHeight > 0 ? gap : 0);
        drawing.fillStyle = '#99000000';
        drawing.fillRect(point.x - gap, textY - gap / 2, textWidth + gap * 2, textHeight);
        drawing.fillStyle = '#FFFFFFFF';
        drawing.textBaseline = 'top';
        drawing.fillText(config.text, point.x, textY);
      }
      drawing.globalAlpha = 1;
      return drawing.getPixelMap(0, 0, info.size.width, info.size.height);
    } catch (error) {
      throw new AppError(AppErrorCode.IMAGE_PROCESS_FAILED,
        ErrorMessageUtil.from(error as object, '水印合成失败，请重试。'));
    } finally {
      await logo?.release();
      await logoSource?.release();
    }
  }

  private resolvePosition(width: number, height: number, groupWidth: number, groupHeight: number,
    position: WatermarkPosition): DrawPoint {
    const margin = Math.max(24, Math.round(Math.min(width, height) * 0.04));
    switch (position) {
      case WatermarkPosition.TOP_LEFT:
        return new DrawPoint(margin, margin);
      case WatermarkPosition.TOP_RIGHT:
        return new DrawPoint(width - margin - groupWidth, margin);
      case WatermarkPosition.CENTER:
        return new DrawPoint((width - groupWidth) / 2, (height - groupHeight) / 2);
      case WatermarkPosition.BOTTOM_LEFT:
        return new DrawPoint(margin, height - margin - groupHeight);
      default:
        return new DrawPoint(width - margin - groupWidth, height - margin - groupHeight);
    }
  }
}
