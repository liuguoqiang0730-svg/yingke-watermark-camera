import { geoLocationManager } from '@kit.LocationKit';

export class WatermarkLocationInfo {
  locationText: string = '位置未获取';
  coordinateText: string = '经纬度未获取';
}

export class WatermarkLocationService {
  private static readonly instance: WatermarkLocationService = new WatermarkLocationService();
  private static readonly CACHE_DURATION_MS: number = 5 * 60 * 1000;
  private static readonly LOCATION_TIMEOUT_MS: number = 8000;
  private static readonly LOCATION_GUARD_TIMEOUT_MS: number = 10000;
  private static readonly ADDRESS_TIMEOUT_MS: number = 3000;
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
      const location = await this.requestCurrentLocation();
      info.coordinateText = `纬度 ${location.latitude.toFixed(6)} · 经度 ${location.longitude.toFixed(6)}`;
      info.locationText = await this.resolveAddressWithTimeout(location.latitude, location.longitude);
      this.cachedInfo = this.cloneInfo(info);
      this.cachedAt = Date.now();
    } catch (_) {
    }
    return info;
  }

  private requestCurrentLocation(): Promise<geoLocationManager.Location> {
    return new Promise((resolve: (location: geoLocationManager.Location) => void,
      reject: (reason: Object) => void): void => {
      let settled = false;
      const timer = setTimeout((): void => {
        if (!settled) {
          settled = true;
          reject(new Error('定位请求超时'));
        }
      }, WatermarkLocationService.LOCATION_GUARD_TIMEOUT_MS);
      geoLocationManager.getCurrentLocation({
        priority: geoLocationManager.LocationRequestPriority.FIRST_FIX,
        maxAccuracy: 1000,
        timeoutMs: WatermarkLocationService.LOCATION_TIMEOUT_MS
      }).then((location: geoLocationManager.Location): void => {
        if (!settled) {
          settled = true;
          clearTimeout(timer);
          resolve(location);
        }
      }).catch((error: Object): void => {
        if (!settled) {
          settled = true;
          clearTimeout(timer);
          reject(error);
        }
      });
    });
  }

  private resolveAddressWithTimeout(latitude: number, longitude: number): Promise<string> {
    return new Promise((resolve: (address: string) => void): void => {
      let settled = false;
      const timer = setTimeout((): void => {
        if (!settled) {
          settled = true;
          resolve('当前位置');
        }
      }, WatermarkLocationService.ADDRESS_TIMEOUT_MS);
      this.resolveAddress(latitude, longitude).then((address: string): void => {
        if (!settled) {
          settled = true;
          clearTimeout(timer);
          resolve(address);
        }
      }).catch((): void => {
        if (!settled) {
          settled = true;
          clearTimeout(timer);
          resolve('当前位置');
        }
      });
    });
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