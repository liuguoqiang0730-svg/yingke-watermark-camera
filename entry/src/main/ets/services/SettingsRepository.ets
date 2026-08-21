import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import {
  createDefaultWatermarkTemplate,
  WatermarkElementConfig,
  WatermarkElementType,
  WatermarkElementSource,
  WatermarkTemplateConfig
} from '../models/WatermarkTemplate';

export class WatermarkDefaults {
  text: string = '映刻 · 记录此刻';
  showText: boolean = true;
  showLogo: boolean = true;
  opacity: number = 80;
  template: WatermarkTemplateConfig = createDefaultWatermarkTemplate();
}

export class SettingsRepository {
  private static readonly STORE_NAME: string = 'app_settings';

  load(context: common.UIAbilityContext): WatermarkDefaults {
    const store = preferences.getPreferencesSync(context, { name: SettingsRepository.STORE_NAME });
    const settings = new WatermarkDefaults();
    settings.text = store.getSync('watermark_text', settings.text) as string;
    settings.showText = store.getSync('show_text', settings.showText) as boolean;
    settings.showLogo = true;
    settings.opacity = store.getSync('watermark_opacity', settings.opacity) as number;
    const count = store.getSync('template_element_count', 0) as number;
    if (count <= 0) {
      settings.template.elements[0].text = settings.text;
      settings.template.elements[0].opacity = settings.opacity / 100;
      return settings;
    }

    const template = new WatermarkTemplateConfig();
    template.brandSizePercent = store.getSync('template_brand_size', template.brandSizePercent) as number;
    template.brandOpacity = store.getSync('template_brand_opacity', template.brandOpacity) as number;
    for (let index = 0; index < Math.min(8, count); index++) {
      const prefix = `template_element_${index}`;
      const typeValue = store.getSync(`${prefix}_type`, WatermarkElementType.TEXT) as string;
      const type = typeValue === WatermarkElementType.IMAGE ?
        WatermarkElementType.IMAGE : WatermarkElementType.TEXT;
      const element = new WatermarkElementConfig(
        store.getSync(`${prefix}_id`, `element_${index}`) as string, type);
      element.text = store.getSync(`${prefix}_text`, element.text) as string;
      element.fieldLabel = store.getSync(`${prefix}_field_label`, '') as string;
      element.source = store.getSync(`${prefix}_source`, WatermarkElementSource.MANUAL) as WatermarkElementSource;
      element.showSourceBadge = store.getSync(`${prefix}_show_source_badge`, true) as boolean;
      element.imageUri = store.getSync(`${prefix}_image_uri`, '') as string;
      element.visible = store.getSync(`${prefix}_visible`, true) as boolean;
      element.positionX = store.getSync(`${prefix}_position_x`, element.positionX) as number;
      element.positionY = store.getSync(`${prefix}_position_y`, element.positionY) as number;
      element.scaleFactor = store.getSync(`${prefix}_scale`, element.scaleFactor) as number;
      element.opacity = store.getSync(`${prefix}_opacity`, element.opacity) as number;
      element.sizePercent = store.getSync(`${prefix}_size`, element.sizePercent) as number;
      template.elements.push(element);
    }
    settings.template = template;
    if (template.elements.length > 0 && template.elements[0].type === WatermarkElementType.TEXT) {
      settings.text = template.elements[0].text;
      settings.opacity = Math.round(template.elements[0].opacity * 100);
    }
    return settings;
  }

  save(context: common.UIAbilityContext, settings: WatermarkDefaults): void {
    const store = preferences.getPreferencesSync(context, { name: SettingsRepository.STORE_NAME });
    store.putSync('watermark_text', settings.text);
    store.putSync('show_text', settings.showText);
    store.putSync('show_logo', true);
    store.putSync('watermark_opacity', settings.opacity);
    store.putSync('template_brand_size', settings.template.brandSizePercent);
    store.putSync('template_brand_opacity', settings.template.brandOpacity);
    store.putSync('template_element_count', settings.template.elements.length);
    settings.template.elements.forEach((element: WatermarkElementConfig, index: number): void => {
      const prefix = `template_element_${index}`;
      store.putSync(`${prefix}_id`, element.id);
      store.putSync(`${prefix}_type`, element.type);
      store.putSync(`${prefix}_text`, element.text);
      store.putSync(`${prefix}_field_label`, element.fieldLabel);
      store.putSync(`${prefix}_source`, element.source);
      store.putSync(`${prefix}_show_source_badge`, element.showSourceBadge);
      store.putSync(`${prefix}_image_uri`, element.imageUri);
      store.putSync(`${prefix}_visible`, element.visible);
      store.putSync(`${prefix}_position_x`, element.positionX);
      store.putSync(`${prefix}_position_y`, element.positionY);
      store.putSync(`${prefix}_scale`, element.scaleFactor);
      store.putSync(`${prefix}_opacity`, element.opacity);
      store.putSync(`${prefix}_size`, element.sizePercent);
    });
    store.flushSync();
  }
}