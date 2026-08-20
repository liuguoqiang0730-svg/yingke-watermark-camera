import { geoLocationManager } from '@kit.LocationKit';

export class WatermarkLocationInfo {
  locationText: string = '位置未获取';
  coordinateText: string = '经纬度未获取';
}

export class WatermarkLocationService {
  private static readonly instance: WatermarkLocationService = new WatermarkLocationService();
  private static readonly CACHE_DURATION_MS: number = 5 * 60 * 1000;
  private cachedInfo?: WatermarkLocationInfo;
  private cachedAt: number = 0;
  private locationTask?: Promise<WatermarkLocationInfo>;

  private constructor() {
  }

  static getInstance(): WatermarkLocationService {
    return WatermarkLocationService.instance;
  }

  getCachedLocation(): WatermarkLocationInfo | undefined {
    if (!this.cachedInfo || Date.now() - this.cachedAt > WatermarkLocationService.CACHE_DURATION_MS) {
      return undefined;
    }
    return this.cloneInfo(this.cachedInfo);
  }

  async getCurrentLocation(): Promise<WatermarkLocationInfo> {
    const cached = this.getCachedLocation();
    if (cached) {
      return cached;
    }
    if (this.locationTask) {
      return this.locationTask;
    }
    this.locationTask = this.resolveCurrentLocation();
    try {
      return await this.locationTask;
    } finally {
      this.locationTask = undefined;
    }
  }

  private async resolveCurrentLocation(): Promise<WatermarkLocationInfo> {
    const info = new WatermarkLocationInfo();
    try {
      const location = await geoLocationManager.getCurrentLocation({
        priority: geoLocationManager.LocationRequestPriority.ACCURACY,
        maxAccuracy: 1000
      });
      info.coordinateText = `纬度 ${location.latitude.toFixed(6)} · 经度 ${location.longitude.toFixed(6)}`;
      info.locationText = await this.resolveAddress(location.latitude, location.longitude);
      this.cachedInfo = this.cloneInfo(info);
      this.cachedAt = Date.now();
    } catch (_) {
    }
    return info;
  }

  private cloneInfo(source: WatermarkLocationInfo): WatermarkLocationInfo {
    const target = new WatermarkLocationInfo();
    target.locationText = source.locationText;
    target.coordinateText = source.coordinateText;
    return target;
  }

  private async resolveAddress(latitude: number, longitude: number): Promise<string> {
    try {
      if (!geoLocationManager.isGeocoderAvailable()) {
        return '当前位置';
      }
      const addresses = await geoLocationManager.getAddressesFromLocation({
        latitude: latitude,
        longitude: longitude,
        maxItems: 1,
        locale: 'zh-CN'
      });
      if (addresses.length === 0) {
        return '当前位置';
      }
      const address = addresses[0];
      if (address.placeName && address.placeName.length > 0) {
        return address.placeName;
      }
      const text = `${address.administrativeArea ?? ''}${address.locality ?? ''}` +
        `${address.subLocality ?? ''}${address.roadName ?? ''}${address.premises ?? ''}`;
      return text.length > 0 ? text : '当前位置';
    } catch (_) {
      return '当前位置';
    }
  }
}