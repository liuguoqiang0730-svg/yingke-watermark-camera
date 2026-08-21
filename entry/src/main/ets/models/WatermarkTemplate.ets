export enum WatermarkElementType {
  TEXT = 'text',
  IMAGE = 'image'
}

export enum WatermarkElementSource {
  MANUAL = 'manual',
  CAPTURE_DATE_TIME = 'capture_date_time',
  CAPTURE_LOCATION = 'capture_location',
  CAPTURE_COORDINATES = 'capture_coordinates',
  PHOTO_DATE_TIME = 'photo_date_time',
  PHOTO_LOCATION = 'photo_location',
  EDIT_DATE_TIME = 'edit_date_time',
  EDIT_COORDINATES = 'edit_coordinates',
  EDIT_LOCATION = 'edit_location'
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
  fieldLabel: string = '';
  source: WatermarkElementSource = WatermarkElementSource.MANUAL;
  showSourceBadge: boolean = true;
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
export function isAutomaticWatermarkSource(source: WatermarkElementSource): boolean {
  return source === WatermarkElementSource.CAPTURE_DATE_TIME ||
    source === WatermarkElementSource.CAPTURE_LOCATION ||
    source === WatermarkElementSource.CAPTURE_COORDINATES ||
    source === WatermarkElementSource.EDIT_DATE_TIME ||
    source === WatermarkElementSource.EDIT_LOCATION ||
    source === WatermarkElementSource.EDIT_COORDINATES;
}

export function isPhotoWatermarkSource(source: WatermarkElementSource): boolean {
  return source === WatermarkElementSource.PHOTO_DATE_TIME ||
    source === WatermarkElementSource.PHOTO_LOCATION;
}

export function watermarkSourceLabel(source: WatermarkElementSource): string {
  if (isPhotoWatermarkSource(source)) {
    return '照片信息';
  }
  if (source === WatermarkElementSource.EDIT_DATE_TIME) {
    return '编辑时采集';
  }
  if (source === WatermarkElementSource.EDIT_LOCATION ||
    source === WatermarkElementSource.EDIT_COORDINATES) {
    return '编辑时定位';
  }
  if (isAutomaticWatermarkSource(source)) {
    return source === WatermarkElementSource.CAPTURE_LOCATION ||
      source === WatermarkElementSource.CAPTURE_COORDINATES ? '自动定位' : '自动采集';
  }
  return '手动填写';
}

export function watermarkElementDisplayText(element: WatermarkElementConfig): string {
  if (element.fieldLabel.length > 0 && element.text.length > 0) {
    return `${element.fieldLabel}：${element.text}`;
  }
  return element.text;
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
export function createSourceWatermarkElement(source: WatermarkElementSource,
  id: string = `source_${Date.now()}`): WatermarkElementConfig {
  const element = new WatermarkElementConfig(id, WatermarkElementType.TEXT);
  element.source = source;
  element.positionX = 0.08;
  element.positionY = 0.68;
  element.sizePercent = 3.6;
  if (source === WatermarkElementSource.CAPTURE_DATE_TIME ||
    source === WatermarkElementSource.EDIT_DATE_TIME) {
    element.text = formatWatermarkDateTime(new Date());
  } else if (source === WatermarkElementSource.PHOTO_DATE_TIME) {
    element.text = '等待读取照片时间';
  } else if (source === WatermarkElementSource.CAPTURE_LOCATION ||
    source === WatermarkElementSource.EDIT_LOCATION) {
    element.text = '正在获取位置…';
  } else if (source === WatermarkElementSource.PHOTO_LOCATION) {
    element.text = '等待读取照片位置';
  } else if (source === WatermarkElementSource.CAPTURE_COORDINATES ||
    source === WatermarkElementSource.EDIT_COORDINATES) {
    element.text = '正在获取经纬度…';
    element.sizePercent = 3;
  }
  return element;
}


export function createTimeLocationWatermarkTemplate(date: Date, locationText: string,
  coordinateText: string): WatermarkTemplateConfig {
  const template = new WatermarkTemplateConfig();
  const dateTime = new WatermarkElementConfig('preset_time', WatermarkElementType.TEXT);
  dateTime.text = formatWatermarkDateTime(date);
  dateTime.source = WatermarkElementSource.CAPTURE_DATE_TIME;
  dateTime.positionX = 0.06;
  dateTime.positionY = 0.66;
  dateTime.sizePercent = 4.5;

  const location = new WatermarkElementConfig('preset_location', WatermarkElementType.TEXT);
  location.text = locationText;
  location.source = WatermarkElementSource.CAPTURE_LOCATION;
  location.positionX = 0.06;
  location.positionY = 0.76;
  location.sizePercent = 3.5;

  const coordinates = new WatermarkElementConfig('preset_coordinates', WatermarkElementType.TEXT);
  coordinates.text = coordinateText;
  coordinates.source = WatermarkElementSource.CAPTURE_COORDINATES;
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
  element.source = WatermarkElementSource.CAPTURE_DATE_TIME;
  element.positionX = 0.08;
  element.positionY = 0.82;
  element.sizePercent = 4.2;
  template.elements = [element];
  return template;
}

export function cloneWatermarkElement(source: WatermarkElementConfig): WatermarkElementConfig {
  const target = new WatermarkElementConfig(source.id, source.type);
  target.text = source.text;
  target.fieldLabel = source.fieldLabel;
  target.imageUri = source.imageUri;
  target.source = source.source;
  target.showSourceBadge = source.showSourceBadge;
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
