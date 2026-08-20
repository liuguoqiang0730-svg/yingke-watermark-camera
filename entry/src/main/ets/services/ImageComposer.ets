import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { AppError, AppErrorCode } from '../models/AppError';
import { WatermarkConfig, WatermarkPosition } from '../models/WatermarkConfig';
import { WatermarkElementConfig, WatermarkElementType } from '../models/WatermarkTemplate';
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
    const elementSources: image.ImageSource[] = [];
    const elementMaps: image.PixelMap[] = [];
    try {
      const info = await source.getImageInfo();
      const canvas = new OffscreenCanvas(info.size.width, info.size.height);
      const drawing = canvas.getContext('2d', new RenderingContextSettings(true));
      drawing.drawImage(source, 0, 0, info.size.width, info.size.height);

      if (config.elements.length > 0 || config.showLogo) {
        const media = await context.resourceManager.getMediaContent(logoResource.id);
        logoSource = image.createImageSource(media.buffer as ArrayBuffer);
        logo = await logoSource.createPixelMap();
      }

      if (config.elements.length > 0) {
        for (let index = 0; index < config.elements.length; index++) {
          const element = config.elements[index];
          if (!element.visible) {
            continue;
          }
          if (element.type === WatermarkElementType.IMAGE && element.imageUri.length > 0) {
            const imageSource = image.createImageSource(element.imageUri);
            const pixelMap = await imageSource.createPixelMap();
            elementSources.push(imageSource);
            elementMaps.push(pixelMap);
            const elementInfo = await pixelMap.getImageInfo();
            const elementWidth = Math.max(24,
              Math.round(info.size.width * element.sizePercent / 100 * this.clampScale(element.scaleFactor)));
            const elementHeight = Math.max(1,
              Math.round(elementWidth * elementInfo.size.height / Math.max(1, elementInfo.size.width)));
            const point = this.resolveElementPosition(info.size.width, info.size.height,
              elementWidth, elementHeight, element);
            drawing.globalAlpha = this.clamp(element.opacity);
            drawing.drawImage(pixelMap, point.x, point.y, elementWidth, elementHeight);
          } else if (element.type === WatermarkElementType.TEXT && element.text.length > 0) {
            const fontSize = Math.max(24,
              Math.round(info.size.width * element.sizePercent / 100 * this.clampScale(element.scaleFactor)));
            drawing.font = `bold ${fontSize}px sans-serif`;
            const textWidth = Math.ceil(drawing.measureText(element.text).width);
            const gap = Math.round(fontSize * 0.35);
            const textHeight = Math.round(fontSize * 1.42);
            const point = this.resolveElementPosition(info.size.width, info.size.height,
              textWidth + gap * 2, textHeight, element);
            drawing.globalAlpha = this.clamp(element.opacity);
            drawing.fillStyle = '#8A1E1510';
            drawing.fillRect(point.x, point.y, textWidth + gap * 2, textHeight);
            drawing.fillStyle = '#FFFFFFFF';
            drawing.textBaseline = 'top';
            drawing.fillText(element.text, point.x + gap, point.y + Math.round(gap * 0.35));
          }
        }
        if (logo) {
          const logoInfo = await logo.getImageInfo();
          const brandIconWidth = Math.max(20, Math.round(info.size.width * config.brandSizePercent / 100));
          const brandIconHeight = Math.max(1,
            Math.round(brandIconWidth * logoInfo.size.height / Math.max(1, logoInfo.size.width)));
          const brandFontSize = Math.max(14, Math.round(brandIconWidth * 0.38));
          const brandLabel = '映刻水印相机';
          drawing.font = 'bold ' + brandFontSize + 'px sans-serif';
          const brandTextWidth = Math.ceil(drawing.measureText(brandLabel).width);
          const brandTextHeight = Math.round(brandFontSize * 1.28);
          const brandGap = Math.max(4, Math.round(brandFontSize * 0.22));
          const brandPadding = Math.max(7, Math.round(brandFontSize * 0.32));
          const brandGroupWidth = Math.max(brandIconWidth, brandTextWidth) + brandPadding * 2;
          const brandGroupHeight = brandPadding * 2 + brandIconHeight + brandGap + brandTextHeight;
          const margin = Math.max(18, Math.round(Math.min(info.size.width, info.size.height) * 0.025));
          const brandX = info.size.width - margin - brandGroupWidth;
          const brandY = info.size.height - margin - brandGroupHeight;
          drawing.globalAlpha = this.clamp(config.brandOpacity);
          drawing.fillStyle = '#9E38281F';
          drawing.fillRect(brandX, brandY, brandGroupWidth, brandGroupHeight);
          drawing.drawImage(logo, brandX + (brandGroupWidth - brandIconWidth) / 2,
            brandY + brandPadding, brandIconWidth, brandIconHeight);
          drawing.fillStyle = '#FFFFFFFF';
          drawing.textBaseline = 'top';
          drawing.fillText(brandLabel, brandX + (brandGroupWidth - brandTextWidth) / 2,
            brandY + brandPadding + brandIconHeight + brandGap);
        }
        drawing.globalAlpha = 1;
        return drawing.getPixelMap(0, 0, info.size.width, info.size.height);
      }

      const scaleFactor = this.clampScale(config.scaleFactor);
      const fontSize = Math.max(24,
        Math.round(info.size.width * config.textSizePercent / 100 * scaleFactor));
      let logoWidth = 0;
      let logoHeight = 0;
      if (logo && config.showLogo) {
        const logoInfo = await logo.getImageInfo();
        logoWidth = Math.round(info.size.width * config.logoSizePercent / 100 * scaleFactor);
        logoHeight = Math.round(logoWidth * logoInfo.size.height / logoInfo.size.width);
      }

      drawing.font = `bold ${fontSize}px sans-serif`;
      const textWidth = config.showText ? drawing.measureText(config.text).width : 0;
      const gap = Math.round(fontSize * 0.35);
      const textHeight = config.showText ? Math.round(fontSize * 1.4) : 0;
      const groupWidth = Math.max(logoWidth, Math.ceil(textWidth));
      const groupHeight = logoHeight + (logoHeight > 0 && textHeight > 0 ? gap : 0) + textHeight;
      const point = this.resolvePosition(info.size.width, info.size.height,
        groupWidth, groupHeight, config);

      drawing.globalAlpha = config.opacity;
      if (logo && config.showLogo) {
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
      for (let index = 0; index < elementMaps.length; index++) {
        await elementMaps[index].release();
      }
      for (let index = 0; index < elementSources.length; index++) {
        await elementSources[index].release();
      }
      await logo?.release();
      await logoSource?.release();
    }
  }

  private resolveElementPosition(width: number, height: number, elementWidth: number, elementHeight: number,
    element: WatermarkElementConfig): DrawPoint {
    const margin = Math.max(18, Math.round(Math.min(width, height) * 0.025));
    return new DrawPoint(
      margin + this.clamp(element.positionX) * Math.max(0, width - elementWidth - margin * 2),
      margin + this.clamp(element.positionY) * Math.max(0, height - elementHeight - margin * 2));
  }

  private resolvePosition(width: number, height: number, groupWidth: number, groupHeight: number,
    config: WatermarkConfig): DrawPoint {
    const margin = Math.max(24, Math.round(Math.min(width, height) * 0.04));
    switch (config.position) {
      case WatermarkPosition.TOP_LEFT:
        return new DrawPoint(margin, margin);
      case WatermarkPosition.TOP_RIGHT:
        return new DrawPoint(width - margin - groupWidth, margin);
      case WatermarkPosition.CENTER:
        return new DrawPoint((width - groupWidth) / 2, (height - groupHeight) / 2);
      case WatermarkPosition.BOTTOM_LEFT:
        return new DrawPoint(margin, height - margin - groupHeight);
      case WatermarkPosition.CUSTOM:
        return new DrawPoint(
          margin + this.clamp(config.positionX) * Math.max(0, width - groupWidth - margin * 2),
          margin + this.clamp(config.positionY) * Math.max(0, height - groupHeight - margin * 2));
      default:
        return new DrawPoint(width - margin - groupWidth, height - margin - groupHeight);
    }
  }

  private clamp(value: number): number {
    return Math.min(1, Math.max(0, value));
  }

  private clampScale(value: number): number {
    return Math.min(2.5, Math.max(0.5, value));
  }
}