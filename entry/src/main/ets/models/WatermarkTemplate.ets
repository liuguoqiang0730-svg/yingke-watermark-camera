export enum WatermarkElementType {
  TEXT = 'text',
  IMAGE = 'image'
}

export enum WatermarkPreset {
  TIME_LOCATION = 'time_location',
  MINIMAL_DATE = 'minimal_date',
  CUSTOM = 'custom'
}

export class WatermarkElementConfig {
  id: string = '';
  type: WatermarkElementType = WatermarkElementType.TEXT;
  text: string = '映刻 · 记录此刻';
  imageUri: string = '';
  visible: boolean = true;
  positionX: number = 0.08;
  positionY: number = 0.72;
  scaleFactor: number = 1;
  opacity: number = 0.88;
  sizePercent: number = 4;

  constructor(id: string = '', type: WatermarkElementType = WatermarkElementType.TEXT) {
    this.id = id;
    this.type = type;
  }
}

export class WatermarkTemplateConfig {
  elements: WatermarkElementConfig[] = [];
  brandSizePercent: number = 2.8;
  brandOpacity: number = 0.78;
}

export function createDefaultWatermarkTemplate(): WatermarkTemplateConfig {
  const template = new WatermarkTemplateConfig();
  const element = new WatermarkElementConfig('default_text', WatermarkElementType.TEXT);
  template.elements = [element];
  return template;
}

function padDatePart(value: number): string {
  return value.toString().padStart(2, '0');
}

export function formatWatermarkDate(date: Date): string {
  return `${date.getFullYear()}.${padDatePart(date.getMonth() + 1)}.${padDatePart(date.getDate())}`;
}

export function formatWatermarkDateTime(date: Date): string {
  return `${formatWatermarkDate(date)} ${padDatePart(date.getHours())}:${padDatePart(date.getMinutes())}`;
}

export function createTimeLocationWatermarkTemplate(date: Date, locationText: string,
  coordinateText: string): WatermarkTemplateConfig {
  const template = new WatermarkTemplateConfig();
  const dateTime = new WatermarkElementConfig('preset_time', WatermarkElementType.TEXT);
  dateTime.text = formatWatermarkDateTime(date);
  dateTime.positionX = 0.06;
  dateTime.positionY = 0.66;
  dateTime.sizePercent = 4.5;

  const location = new WatermarkElementConfig('preset_location', WatermarkElementType.TEXT);
  location.text = locationText;
  location.positionX = 0.06;
  location.positionY = 0.76;
  location.sizePercent = 3.5;

  const coordinates = new WatermarkElementConfig('preset_coordinates', WatermarkElementType.TEXT);
  coordinates.text = coordinateText;
  coordinates.positionX = 0.06;
  coordinates.positionY = 0.84;
  coordinates.sizePercent = 2.8;
  coordinates.opacity = 0.82;

  template.elements = [dateTime, location, coordinates];
  return template;
}

export function createMinimalDateWatermarkTemplate(date: Date): WatermarkTemplateConfig {
  const template = new WatermarkTemplateConfig();
  const element = new WatermarkElementConfig('preset_date', WatermarkElementType.TEXT);
  element.text = formatWatermarkDate(date);
  element.positionX = 0.08;
  element.positionY = 0.82;
  element.sizePercent = 4.2;
  template.elements = [element];
  return template;
}

export function cloneWatermarkElement(source: WatermarkElementConfig): WatermarkElementConfig {
  const target = new WatermarkElementConfig(source.id, source.type);
  target.text = source.text;
  target.imageUri = source.imageUri;
  target.visible = source.visible;
  target.positionX = source.positionX;
  target.positionY = source.positionY;
  target.scaleFactor = source.scaleFactor;
  target.opacity = source.opacity;
  target.sizePercent = source.sizePercent;
  return target;
}

export function cloneWatermarkTemplate(source: WatermarkTemplateConfig): WatermarkTemplateConfig {
  const target = new WatermarkTemplateConfig();
  target.brandSizePercent = source.brandSizePercent;
  target.brandOpacity = source.brandOpacity;
  target.elements = source.elements.map((item: WatermarkElementConfig) => cloneWatermarkElement(item));
  return target;
}
