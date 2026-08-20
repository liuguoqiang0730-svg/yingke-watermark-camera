import { image } from '@kit.ImageKit';
import { CollageConfig, CollageLayout } from '../models/CollageConfig';
import { AppError, AppErrorCode } from '../models/AppError';
import { ImageCodec } from './ImageCodec';
import { ErrorMessageUtil } from '../utils/ErrorMessageUtil';

const VERTICAL_CONTENT_WIDTH: number = 1600;
const HORIZONTAL_CONTENT_HEIGHT: number = 1200;
const GRID_CELL_SIZE: number = 1000;
const MAX_OUTPUT_EDGE: number = 8192;
const MAX_OUTPUT_PIXELS: number = 24000000;

class CollageImageSize {
  width: number;
  height: number;

  constructor(width: number, height: number) {
    this.width = width;
    this.height = height;
  }
}

class CollageSlot {
  x: number;
  y: number;
  width: number;
  height: number;
  cover: boolean;

  constructor(x: number, y: number, width: number, height: number, cover: boolean) {
    this.x = x;
    this.y = y;
    this.width = width;
    this.height = height;
    this.cover = cover;
  }
}

class CollagePlan {
  width: number;
  height: number;
  slots: CollageSlot[];

  constructor(width: number, height: number, slots: CollageSlot[]) {
    this.width = width;
    this.height = height;
    this.slots = slots;
  }
}

export class CollageComposer {
  private readonly codec: ImageCodec = new ImageCodec();

  async compose(uris: string[], config: CollageConfig): Promise<image.PixelMap> {
    if (uris.length < 2 || uris.length > 9) {
      throw new AppError(AppErrorCode.IMAGE_PROCESS_FAILED, '请选择 2 至 9 张图片。');
    }

    try {
      const sizes = await this.readSizes(uris);
      const plan = this.createPlan(sizes, config);
      const canvas = new OffscreenCanvas(plan.width, plan.height);
      const drawing = canvas.getContext('2d', new RenderingContextSettings(true));
      drawing.fillStyle = config.backgroundColor;
      drawing.fillRect(0, 0, plan.width, plan.height);

      for (let index = 0; index < uris.length; index++) {
        const decoded = await this.codec.decodeForExport(uris[index]);
        try {
          this.drawSlot(drawing, decoded.pixelMap, decoded.width, decoded.height,
            plan.slots[index], config.cornerRadius);
        } finally {
          await decoded.pixelMap.release();
        }
      }
      return drawing.getPixelMap(0, 0, plan.width, plan.height);
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      throw new AppError(AppErrorCode.IMAGE_PROCESS_FAILED,
        ErrorMessageUtil.from(error as object, '图片拼接失败，请重试。'));
    }
  }

  private async readSizes(uris: string[]): Promise<CollageImageSize[]> {
    const sizes: CollageImageSize[] = [];
    for (let index = 0; index < uris.length; index++) {
      const decoded = await this.codec.decodeForExport(uris[index]);
      sizes.push(new CollageImageSize(decoded.width, decoded.height));
      await decoded.pixelMap.release();
    }
    return sizes;
  }

  private createPlan(sizes: CollageImageSize[], config: CollageConfig): CollagePlan {
    const spacing = Math.max(0, Math.round(config.spacing));
    let plan: CollagePlan;
    switch (config.layout) {
      case CollageLayout.HORIZONTAL:
        plan = this.createHorizontalPlan(sizes, spacing);
        break;
      case CollageLayout.GRID:
        plan = this.createGridPlan(sizes.length, spacing);
        break;
      default:
        plan = this.createVerticalPlan(sizes, spacing);
        break;
    }
    return this.scalePlanToLimits(plan);
  }

  private createVerticalPlan(sizes: CollageImageSize[], spacing: number): CollagePlan {
    const slots: CollageSlot[] = [];
    let y = spacing;
    sizes.forEach((size: CollageImageSize): void => {
      const height = Math.max(1, Math.round(VERTICAL_CONTENT_WIDTH * size.height / size.width));
      slots.push(new CollageSlot(spacing, y, VERTICAL_CONTENT_WIDTH, height, false));
      y += height + spacing;
    });
    return new CollagePlan(VERTICAL_CONTENT_WIDTH + spacing * 2, y, slots);
  }

  private createHorizontalPlan(sizes: CollageImageSize[], spacing: number): CollagePlan {
    const slots: CollageSlot[] = [];
    let x = spacing;
    sizes.forEach((size: CollageImageSize): void => {
      const width = Math.max(1, Math.round(HORIZONTAL_CONTENT_HEIGHT * size.width / size.height));
      slots.push(new CollageSlot(x, spacing, width, HORIZONTAL_CONTENT_HEIGHT, false));
      x += width + spacing;
    });
    return new CollagePlan(x, HORIZONTAL_CONTENT_HEIGHT + spacing * 2, slots);
  }

  private createGridPlan(count: number, spacing: number): CollagePlan {
    const columns = count <= 4 ? 2 : 3;
    const rows = Math.ceil(count / columns);
    const slots: CollageSlot[] = [];
    for (let index = 0; index < count; index++) {
      const column = index % columns;
      const row = Math.floor(index / columns);
      slots.push(new CollageSlot(
        spacing + column * (GRID_CELL_SIZE + spacing),
        spacing + row * (GRID_CELL_SIZE + spacing),
        GRID_CELL_SIZE,
        GRID_CELL_SIZE,
        true));
    }
    return new CollagePlan(
      columns * GRID_CELL_SIZE + (columns + 1) * spacing,
      rows * GRID_CELL_SIZE + (rows + 1) * spacing,
      slots);
  }

  private scalePlanToLimits(plan: CollagePlan): CollagePlan {
    const edgeScale = MAX_OUTPUT_EDGE / Math.max(plan.width, plan.height);
    const pixelScale = Math.sqrt(MAX_OUTPUT_PIXELS / (plan.width * plan.height));
    const scale = Math.min(1, edgeScale, pixelScale);
    if (scale >= 1) {
      return plan;
    }
    const slots = plan.slots.map((slot: CollageSlot): CollageSlot => {
      return new CollageSlot(
        Math.round(slot.x * scale),
        Math.round(slot.y * scale),
        Math.max(1, Math.round(slot.width * scale)),
        Math.max(1, Math.round(slot.height * scale)),
        slot.cover);
    });
    return new CollagePlan(
      Math.max(1, Math.round(plan.width * scale)),
      Math.max(1, Math.round(plan.height * scale)),
      slots);
  }

  private drawSlot(drawing: OffscreenCanvasRenderingContext2D, pixelMap: image.PixelMap,
    sourceWidth: number, sourceHeight: number, slot: CollageSlot, cornerRadius: number): void {
    drawing.save();
    this.clipRoundedRect(drawing, slot, Math.min(
      Math.max(0, cornerRadius), Math.min(slot.width, slot.height) / 2));
    if (!slot.cover) {
      drawing.drawImage(pixelMap, slot.x, slot.y, slot.width, slot.height);
      drawing.restore();
      return;
    }

    const sourceRatio = sourceWidth / sourceHeight;
    const targetRatio = slot.width / slot.height;
    let cropX = 0;
    let cropY = 0;
    let cropWidth = sourceWidth;
    let cropHeight = sourceHeight;
    if (sourceRatio > targetRatio) {
      cropWidth = sourceHeight * targetRatio;
      cropX = (sourceWidth - cropWidth) / 2;
    } else {
      cropHeight = sourceWidth / targetRatio;
      cropY = (sourceHeight - cropHeight) / 2;
    }
    drawing.drawImage(pixelMap, cropX, cropY, cropWidth, cropHeight,
      slot.x, slot.y, slot.width, slot.height);
    drawing.restore();
  }

  private clipRoundedRect(drawing: OffscreenCanvasRenderingContext2D,
    slot: CollageSlot, radius: number): void {
    drawing.beginPath();
    drawing.moveTo(slot.x + radius, slot.y);
    drawing.lineTo(slot.x + slot.width - radius, slot.y);
    drawing.arcTo(slot.x + slot.width, slot.y, slot.x + slot.width, slot.y + radius, radius);
    drawing.lineTo(slot.x + slot.width, slot.y + slot.height - radius);
    drawing.arcTo(slot.x + slot.width, slot.y + slot.height,
      slot.x + slot.width - radius, slot.y + slot.height, radius);
    drawing.lineTo(slot.x + radius, slot.y + slot.height);
    drawing.arcTo(slot.x, slot.y + slot.height, slot.x, slot.y + slot.height - radius, radius);
    drawing.lineTo(slot.x, slot.y + radius);
    drawing.arcTo(slot.x, slot.y, slot.x + radius, slot.y, radius);
    drawing.closePath();
    drawing.clip();
  }
}
