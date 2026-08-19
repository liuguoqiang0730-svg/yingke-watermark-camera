import { image } from '@kit.ImageKit';

export class ImageProcessResult {
  pixelMap: image.PixelMap;
  width: number;
  height: number;

  constructor(pixelMap: image.PixelMap, width: number, height: number) {
    this.pixelMap = pixelMap;
    this.width = width;
    this.height = height;
  }
}
