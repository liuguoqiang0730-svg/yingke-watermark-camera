import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { AppError, AppErrorCode } from '../models/AppError';
import { WatermarkConfig, WatermarkPosition } from '../models/WatermarkConfig';
import {
  isAutomaticWatermarkSource,
  watermarkElementDisplayText,
  WatermarkElementConfig,
  WatermarkElementType,
  watermarkSourceLabel
} from '../models/WatermarkTemplate';
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
            drawing.font = 'bold ' + fontSize + 'px sans-serif';
            const horizontalPadding = Math.round(fontSize * 0.35);
            const verticalPadding = Math.round(fontSize * 0.22);
            const lineHeight = Math.round(fontSize * 1.28);
            const maxTextWidth = Math.max(fontSize,
              Math.round(info.size.width * 0.68) - horizontalPadding * 2);
            const displayText = watermarkElementDisplayText(element);
            const textLines = this.buildTextLines(drawing, displayText, maxTextWidth, 6);
            let textWidth = fontSize;
            for (let lineIndex = 0; lineIndex < textLines.length; lineIndex++) {
              textWidth = Math.max(textWidth, Math.ceil(drawing.measureText(textLines[lineIndex]).width));
            }
            const badgeText = element.showSourceBadge ?
              `${isAutomaticWatermarkSource(element.source) ? '◆' : '✎'} ${watermarkSourceLabel(element.source)}` : '';
            const badgeFontSize = Math.max(14, Math.round(fontSize * 0.42));
            const badgeHeight = badgeText.length > 0 ? Math.round(badgeFontSize * 1.35) : 0;
            const badgeGap = badgeText.length > 0 ? Math.max(4, Math.round(fontSize * 0.14)) : 0;
            drawing.font = 'bold ' + badgeFontSize + 'px sans-serif';
            const badgeWidth = badgeText.length > 0 ? Math.ceil(drawing.measureText(badgeText).width) : 0;
            drawing.font = 'bold ' + fontSize + 'px sans-serif';
            const blockWidth = Math.max(textWidth, badgeWidth) + horizontalPadding * 2;
            const blockHeight = lineHeight * textLines.length + badgeHeight + badgeGap + verticalPadding * 2;
            const point = this.resolveElementPosition(info.size.width, info.size.height,
              blockWidth, blockHeight, element);
            drawing.globalAlpha = this.clamp(element.opacity);
            drawing.fillStyle = '#8A342217';
            drawing.fillRect(point.x, point.y, blockWidth, blockHeight);
            drawing.textBaseline = 'top';
            let textY = point.y + verticalPadding;
            if (badgeText.length > 0) {
              drawing.font = 'bold ' + badgeFontSize + 'px sans-serif';
              drawing.fillStyle = isAutomaticWatermarkSource(element.source) ? '#FFB8E1C5' : '#FFFFD4B8';
              drawing.fillText(badgeText, point.x + horizontalPadding, textY);
              textY += badgeHeight + badgeGap;
            }
            drawing.font = 'bold ' + fontSize + 'px sans-serif';
            drawing.fillStyle = '#FFFFFFFF';
            for (let lineIndex = 0; lineIndex < textLines.length; lineIndex++) {
              drawing.fillText(textLines[lineIndex], point.x + horizontalPadding,
                textY + lineIndex * lineHeight);
            }
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

      drawing.font = 'bold ' + fontSize + 'px sans-serif';
      const horizontalPadding = Math.round(fontSize * 0.35);
      const verticalPadding = Math.round(fontSize * 0.22);
      const lineHeight = Math.round(fontSize * 1.28);
      const maxTextWidth = Math.max(fontSize,
        Math.round(info.size.width * 0.68) - horizontalPadding * 2);
      const textLines: string[] = config.showText && config.text.length > 0 ?
        this.buildTextLines(drawing, config.text, maxTextWidth, 6) : [];
      let textWidth = 0;
      for (let lineIndex = 0; lineIndex < textLines.length; lineIndex++) {
        textWidth = Math.max(textWidth, Math.ceil(drawing.measureText(textLines[lineIndex]).width));
      }
      const textHeight = textLines.length > 0 ?
        lineHeight * textLines.length + verticalPadding * 2 : 0;
      const gap = Math.round(fontSize * 0.35);
      const groupWidth = Math.max(logoWidth, textLines.length > 0 ? textWidth + horizontalPadding * 2 : 0);
      const groupHeight = logoHeight + (logoHeight > 0 && textHeight > 0 ? gap : 0) + textHeight;
      const point = this.resolvePosition(info.size.width, info.size.height,
        groupWidth, groupHeight, config);

      drawing.globalAlpha = config.opacity;
      if (logo && config.showLogo) {
        drawing.drawImage(logo, point.x, point.y, logoWidth, logoHeight);
      }
      if (textLines.length > 0) {
        const textY = point.y + logoHeight + (logoHeight > 0 ? gap : 0);
        drawing.fillStyle = '#99000000';
        drawing.fillRect(point.x, textY, textWidth + horizontalPadding * 2, textHeight);
        drawing.fillStyle = '#FFFFFFFF';
        drawing.textBaseline = 'top';
        for (let lineIndex = 0; lineIndex < textLines.length; lineIndex++) {
          drawing.fillText(textLines[lineIndex], point.x + horizontalPadding,
            textY + verticalPadding + lineIndex * lineHeight);
        }
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

  private buildTextLines(drawing: OffscreenCanvasRenderingContext2D, text: string,
    maxWidth: number, maxLines: number): string[] {
    const paragraphs = text.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n');
    const lines: string[] = [];
    for (let paragraphIndex = 0;
      paragraphIndex < paragraphs.length && lines.length < maxLines; paragraphIndex++) {
      const paragraph = paragraphs[paragraphIndex];
      if (paragraph.length === 0) {
        lines.push('');
        continue;
      }
      let currentLine = '';
      for (const character of paragraph) {
        const nextLine = currentLine + character;
        if (currentLine.length > 0 && drawing.measureText(nextLine).width > maxWidth) {
          lines.push(currentLine);
          currentLine = character;
          if (lines.length >= maxLines) {
            break;
          }
        } else {
          currentLine = nextLine;
        }
      }
      if (lines.length < maxLines && currentLine.length > 0) {
        lines.push(currentLine);
      }
    }
    return lines.length > 0 ? lines : [''];
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