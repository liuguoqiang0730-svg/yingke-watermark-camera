import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { APP_BACKGROUND_EVENT, APP_FOREGROUND_EVENT } from '../common/constants/AppEvent';
import {
  APPROXIMATE_LOCATION_PERMISSION,
  CAMERA_PERMISSION,
  PermissionManager
} from '../common/permission/PermissionManager';
import { WatermarkBrandBadge } from '../components/WatermarkBrandBadge';
import { WatermarkElementOverlay } from '../components/WatermarkElementOverlay';
import { PermissionGuide } from '../components/PermissionGuide';
import { PermissionState } from '../models/PermissionState';
import {
  cloneWatermarkElement,
  createDefaultWatermarkTemplate,
  createMinimalDateWatermarkTemplate,
  createSourceWatermarkElement,
  createTimeLocationWatermarkTemplate,
  formatWatermarkDate,
  formatWatermarkDateTime,
  isAutomaticWatermarkSource,
  watermarkElementDisplayText,
  WatermarkElementConfig,
  WatermarkElementSource,
  WatermarkElementType,
  WatermarkPreset,
  watermarkSourceLabel,
  WatermarkTemplateConfig
} from '../models/WatermarkTemplate';
import { SettingsRepository, WatermarkDefaults } from '../services/SettingsRepository';
import { WatermarkLocationInfo, WatermarkLocationService } from '../services/WatermarkLocationService';
import { CameraViewModel } from '../viewmodels/CameraViewModel';
import { ErrorMessageUtil } from '../utils/ErrorMessageUtil';
import { AppLogger } from '../utils/AppLogger';

const TAG: string = 'CameraPage';

class CameraParams {
  watermarkPreset?: WatermarkPreset;
  editorMode?: boolean;
}

@Entry
@Component
struct CameraPage {
  @State private permissionState: PermissionState = PermissionState.UNKNOWN;
  @State private statusText: string = '正在准备相机…';
  @State private ready: boolean = false;
  @State private capturing: boolean = false;
  @State private flashEnabled: boolean = false;
  @State private flashAvailable: boolean = false;
  @State private switching: boolean = false;
  @State private viewportWidth: number = 0;
  @State private viewportHeight: number = 0;
  @State private photoOutputWidth: number = 0;
  @State private photoOutputHeight: number = 0;
  @State private showSettings: boolean = false;
  @State private editorMode: boolean = false;
  @State private editorTab: number = 1;
  @State private watermarkText: string = '映刻 · 记录此刻';
  @State private watermarkOpacity: number = 80;
  @State private textSize: number = 4;
  @State private logoSize: number = 5;
  @State private watermarkScale: number = 1;
  @State private showText: boolean = true;
  @State private showLogo: boolean = true;
  @State private positionX: number = 0.78;
  @State private positionY: number = 0.62;
  @State private watermarkElements: WatermarkElementConfig[] = [];
  @State private selectedWatermarkId: string = '';
  @State private brandSizePercent: number = 2.8;
  @State private brandOpacity: number = 0.78;
  private selectedPreset: WatermarkPreset = WatermarkPreset.TIME_LOCATION;
  private locationText: string = '正在获取位置…';
  private coordinateText: string = '正在获取经纬度…';
  private locationTask?: Promise<void>;

  private readonly controller: XComponentController = new XComponentController();
  private readonly viewModel: CameraViewModel = new CameraViewModel();
  private readonly settingsRepository: SettingsRepository = new SettingsRepository();
  private readonly locationService: WatermarkLocationService = WatermarkLocationService.getInstance();
  private readonly abilityContext: common.UIAbilityContext =
    this.getUIContext().getHostContext() as common.UIAbilityContext;
  private surfaceId: string = '';

  private readonly foregroundCallback = (): void => {
    this.resumeCamera();
  };
  private readonly backgroundCallback = (): void => {
    this.pauseCamera();
  };

  aboutToAppear(): void {
    this.setImmersive(true);
    this.selectedPreset = this.resolveWatermarkPreset();
    this.editorMode = this.resolveEditorMode();
    this.showSettings = this.editorMode;
    this.loadWatermarkPreset();
    this.abilityContext.eventHub.on(APP_FOREGROUND_EVENT, this.foregroundCallback);
    this.abilityContext.eventHub.on(APP_BACKGROUND_EVENT, this.backgroundCallback);
    this.checkAndRequestPermission();
  }

  private resolveWatermarkPreset(): WatermarkPreset {
    const params = this.getUIContext().getRouter().getParams() as CameraParams;
    if (params?.watermarkPreset === WatermarkPreset.MINIMAL_DATE) {
      return WatermarkPreset.MINIMAL_DATE;
    }
    if (params?.watermarkPreset === WatermarkPreset.CUSTOM) {
      return WatermarkPreset.CUSTOM;
    }
    return WatermarkPreset.TIME_LOCATION;
  }

  private resolveEditorMode(): boolean {
    const params = this.getUIContext().getRouter().getParams() as CameraParams;
    return params?.editorMode === true;
  }


  private loadWatermarkPreset(): void {
    if (this.selectedPreset === WatermarkPreset.CUSTOM) {
      this.loadCustomWatermark();
      return;
    }
    if (this.selectedPreset === WatermarkPreset.TIME_LOCATION &&
      PermissionManager.getInstance().checkPermission(
        this.abilityContext, APPROXIMATE_LOCATION_PERMISSION) === PermissionState.GRANTED) {
      const cachedLocation = this.locationService.getCachedLocation();
      if (cachedLocation) {
        this.locationText = cachedLocation.locationText;
        this.coordinateText = cachedLocation.coordinateText;
      }
    }
    const template = this.selectedPreset === WatermarkPreset.MINIMAL_DATE ?
      createMinimalDateWatermarkTemplate(new Date()) :
      createTimeLocationWatermarkTemplate(new Date(), this.locationText, this.coordinateText);
    this.applyTemplate(template);
  }

  private loadCustomWatermark(): void {
    try {
      const settings = this.settingsRepository.load(this.abilityContext);
      this.applyTemplate(settings.template);
      this.refreshDynamicWatermark();
    } catch (error) {
      AppLogger.warn(TAG, `读取默认水印设置失败：${JSON.stringify(error)}`);
      this.applyTemplate(createDefaultWatermarkTemplate());
    }
  }

  private applyTemplate(template: WatermarkTemplateConfig): void {
    this.watermarkElements = template.elements.map((item: WatermarkElementConfig) =>
      cloneWatermarkElement(item));
    this.brandSizePercent = template.brandSizePercent;
    this.brandOpacity = template.brandOpacity;
    this.selectedWatermarkId = this.watermarkElements.length > 0 ? this.watermarkElements[0].id : '';
    const firstText = this.watermarkElements.find(
      (item: WatermarkElementConfig) => item.type === WatermarkElementType.TEXT);
    if (firstText) {
      this.watermarkText = firstText.text;
      this.showText = firstText.visible;
      this.watermarkOpacity = Math.round(firstText.opacity * 100);
      this.textSize = firstText.sizePercent;
      this.watermarkScale = firstText.scaleFactor;
      this.positionX = firstText.positionX;
      this.positionY = firstText.positionY;
    }
    this.showLogo = true;
  }

  private requiresLocationWatermark(): boolean {
    return this.watermarkElements.some((item: WatermarkElementConfig) =>
      item.source === WatermarkElementSource.CAPTURE_LOCATION ||
      item.source === WatermarkElementSource.CAPTURE_COORDINATES);
  }

  private refreshDynamicWatermark(): void {
    if (this.selectedPreset === WatermarkPreset.CUSTOM) {
      const now = new Date();
      this.watermarkElements = this.watermarkElements.map((item: WatermarkElementConfig) => {
        const updated = cloneWatermarkElement(item);
        if (item.source === WatermarkElementSource.CAPTURE_DATE_TIME) {
          updated.text = item.id === 'preset_date' ? formatWatermarkDate(now) : formatWatermarkDateTime(now);
        } else if (item.source === WatermarkElementSource.CAPTURE_LOCATION) {
          updated.text = this.locationText;
        } else if (item.source === WatermarkElementSource.CAPTURE_COORDINATES) {
          updated.text = this.coordinateText;
        }
        return updated;
      });
    } else {
      const template = this.selectedPreset === WatermarkPreset.MINIMAL_DATE ?
        createMinimalDateWatermarkTemplate(new Date()) :
        createTimeLocationWatermarkTemplate(new Date(), this.locationText, this.coordinateText);
      this.watermarkElements = this.watermarkElements.map((item: WatermarkElementConfig) => {
        const dynamicElement = template.elements.find(
          (candidate: WatermarkElementConfig) => candidate.id === item.id);
        if (!dynamicElement) {
          return item;
        }
        const updated = cloneWatermarkElement(item);
        updated.text = dynamicElement.text;
        return updated;
      });
    }
    const firstText = this.watermarkElements.find(
      (item: WatermarkElementConfig) => item.type === WatermarkElementType.TEXT);
    this.watermarkText = firstText?.text ?? this.watermarkText;
  }

  private loadCurrentLocationWatermark(): Promise<void> {
    if (!this.locationTask) {
      this.locationTask = this.runCurrentLocationWatermarkTask();
    }
    return this.locationTask;
  }

  private async runCurrentLocationWatermarkTask(): Promise<void> {
    try {
      await this.resolveCurrentLocationWatermark();
    } catch (error) {
      this.locationText = '位置未获取';
      this.coordinateText = '经纬度未获取';
      AppLogger.warn(TAG, '定位任务异常结束：' + JSON.stringify(error));
    } finally {
      if (this.locationText === '正在获取位置…') {
        this.locationText = '位置未获取';
      }
      if (this.coordinateText === '正在获取经纬度…') {
        this.coordinateText = '经纬度未获取';
      }
      this.refreshDynamicWatermark();
      if (this.ready && (this.statusText === '正在获取位置信息…' ||
        this.statusText === '正在获取拍摄位置…' || this.statusText === '地点水印需要定位权限')) {
        this.statusText = '';
      }
      this.locationTask = undefined;
    }
  }

  private applyCurrentLocation(location: WatermarkLocationInfo): void {
    this.locationText = location.locationText;
    this.coordinateText = location.coordinateText;
  }

  private async resolveCurrentLocationWatermark(): Promise<void> {
    let permissionState = PermissionManager.getInstance().checkPermission(
      this.abilityContext, APPROXIMATE_LOCATION_PERMISSION);
    if (permissionState !== PermissionState.GRANTED) {
      this.statusText = '地点水印需要定位权限';
      permissionState = await PermissionManager.getInstance()
        .requestLocationPermissions(this.abilityContext);
    }
    if (permissionState !== PermissionState.GRANTED) {
      this.locationText = '位置未授权';
      this.coordinateText = '经纬度未授权';
      this.refreshDynamicWatermark();
      if (this.ready) {
        this.statusText = '';
      }
      this.showToast('未获得定位权限，时间水印仍可正常使用');
      return;
    }
    const cachedLocation = this.locationService.getCachedLocation();
    if (cachedLocation) {
      this.applyCurrentLocation(cachedLocation);
      this.refreshDynamicWatermark();
      if (this.ready) {
        this.statusText = '';
      }
      return;
    }
    this.locationText = '正在获取位置…';
    this.coordinateText = '正在获取经纬度…';
    this.refreshDynamicWatermark();
    if (this.ready) {
      this.statusText = '正在获取位置信息…';
    }
    try {
      const location: WatermarkLocationInfo = await this.locationService.getCurrentLocation();
      this.applyCurrentLocation(location);
    } catch (error) {
      this.locationText = '位置未获取';
      this.coordinateText = '经纬度未获取';
      AppLogger.warn(TAG, `获取水印位置失败：${JSON.stringify(error)}`);
    }
    this.refreshDynamicWatermark();
    if (this.ready) {
      this.statusText = '';
    }
  }

  aboutToDisappear(): void {
    this.setImmersive(false);
    this.abilityContext.eventHub.off(APP_FOREGROUND_EVENT, this.foregroundCallback);
    this.abilityContext.eventHub.off(APP_BACKGROUND_EVENT, this.backgroundCallback);
    this.pauseCamera();
  }

  private async setImmersive(enabled: boolean): Promise<void> {
    try {
      const mainWindow = await window.getLastWindow(this.abilityContext);
      await mainWindow.setWindowLayoutFullScreen(enabled);
      await mainWindow.setWindowSystemBarEnable(enabled ? [] : ['status', 'navigation']);
    } catch (error) {
      AppLogger.warn(TAG, `切换沉浸式显示失败：${JSON.stringify(error)}`);
    }
  }

  private async checkAndRequestPermission(): Promise<void> {
    this.permissionState = PermissionManager.getInstance()
      .checkPermission(this.abilityContext, CAMERA_PERMISSION);
    if (this.permissionState !== PermissionState.GRANTED) {
      this.permissionState = PermissionState.REQUESTING;
      this.permissionState = await PermissionManager.getInstance()
        .requestPermission(this.abilityContext, CAMERA_PERMISSION);
    }
    if (this.permissionState === PermissionState.GRANTED) {
      await this.startCamera();
      await this.setImmersive(true);
      if (this.requiresLocationWatermark()) {
        this.loadCurrentLocationWatermark();
      }
    } else {
      this.statusText = '未获得相机权限';
    }
  }

  private async openPermissionSetting(): Promise<void> {
    this.permissionState = PermissionState.REQUESTING;
    this.permissionState = await PermissionManager.getInstance()
      .requestPermissionOnSetting(this.abilityContext, CAMERA_PERMISSION);
    if (this.permissionState === PermissionState.GRANTED) {
      await this.startCamera();
    }
  }

  private async startCamera(): Promise<void> {
    if (!this.surfaceId || this.ready || this.switching) {
      return;
    }
    this.statusText = '正在启动相机…';
    try {
      await this.viewModel.start(this.abilityContext, this.surfaceId);
      const photoSize = this.viewModel.getPhotoOutputSize();
      this.photoOutputWidth = photoSize.width;
      this.photoOutputHeight = photoSize.height;
      this.ready = true;
      this.flashAvailable = this.viewModel.hasFlash();
      this.statusText = '';
    } catch (error) {
      this.ready = false;
      this.statusText = ErrorMessageUtil.from(error as object, '相机启动失败，请重试。');
    }
  }

  private async pauseCamera(): Promise<void> {
    this.ready = false;
    this.flashEnabled = false;
    await this.viewModel.stop();
  }

  private async resumeCamera(): Promise<void> {
    this.permissionState = PermissionManager.getInstance()
      .checkPermission(this.abilityContext, CAMERA_PERMISSION);
    if (this.permissionState === PermissionState.GRANTED) {
      await this.startCamera();
      await this.setImmersive(true);
      if (this.requiresLocationWatermark()) {
        await this.loadCurrentLocationWatermark();
      }
    }
  }

  private async takePhoto(): Promise<void> {
    if (!this.ready || this.capturing) {
      return;
    }
    this.capturing = true;
    if (this.requiresLocationWatermark()) {
      this.statusText = '正在获取拍摄位置…';
      await this.loadCurrentLocationWatermark();
    }
    this.statusText = '正在拍摄…';
    this.refreshDynamicWatermark();
    try {
      const uri = await this.viewModel.capture(this.abilityContext);
      await this.viewModel.stop();
      this.ready = false;
      await this.getUIContext().getRouter().replaceUrl({
        url: 'pages/ResultPage',
        params: {
          sourceUri: uri,
          resultOnly: true,
          watermarkText: this.watermarkText,
          watermarkOpacity: this.watermarkOpacity,
          textSizePercent: this.textSize,
          logoSizePercent: this.logoSize,
          scaleFactor: this.watermarkScale,
          showText: this.showText,
          showLogo: this.showLogo,
          positionX: this.positionX,
          positionY: this.positionY,
          watermarkElements: this.watermarkElements.map((item: WatermarkElementConfig) =>
            cloneWatermarkElement(item)),
          brandSizePercent: this.brandSizePercent,
          brandOpacity: this.brandOpacity
        }
      });
    } catch (error) {
      const message = ErrorMessageUtil.from(error as object, '拍照失败，请重试。');
      this.statusText = message;
      this.showToast(message);
    } finally {
      this.capturing = false;
    }
  }

  private async switchCamera(): Promise<void> {
    if (!this.ready || this.switching) {
      return;
    }
    this.switching = true;
    this.ready = false;
    this.statusText = '正在切换摄像头…';
    try {
      await this.viewModel.switchCamera(this.abilityContext, this.surfaceId);
      this.ready = true;
      this.flashEnabled = false;
      this.flashAvailable = this.viewModel.hasFlash();
      this.statusText = '';
    } catch (error) {
      this.statusText = ErrorMessageUtil.from(error as object, '摄像头切换失败。');
    } finally {
      this.switching = false;
    }
  }

  private toggleFlash(): void {
    if (!this.ready || !this.flashAvailable) {
      this.showToast('当前摄像头不支持闪光灯。');
      return;
    }
    const target = !this.flashEnabled;
    if (this.viewModel.setFlash(target)) {
      this.flashEnabled = target;
      this.showToast(target ? '闪光灯已开启' : '闪光灯已关闭');
    } else {
      this.showToast('当前摄像头不支持该闪光灯模式。');
    }
  }

  private selectedElementIndex(): number {
    return this.watermarkElements.findIndex(
      (item: WatermarkElementConfig) => item.id === this.selectedWatermarkId);
  }

  private selectWatermark(id: string): void {
    this.selectedWatermarkId = id;
    const index = this.selectedElementIndex();
    if (index < 0) {
      return;
    }
    const element = this.watermarkElements[index];
    this.watermarkText = element.text;
    this.showText = element.visible;
    this.watermarkOpacity = Math.round(element.opacity * 100);
    this.textSize = element.sizePercent;
    this.watermarkScale = element.scaleFactor;
    this.positionX = element.positionX;
    this.positionY = element.positionY;
  }

  private selectedElementIsAutomatic(): boolean {
    const index = this.selectedElementIndex();
    return index >= 0 && isAutomaticWatermarkSource(this.watermarkElements[index].source);
  }

  private addQuickManualField(label: string): void {
    if (this.watermarkElements.length >= 8) {
      this.showToast('最多可以添加 8 个水印元素');
      return;
    }
    const element = new WatermarkElementConfig(`capture_field_${Date.now()}`, WatermarkElementType.TEXT);
    element.fieldLabel = label;
    element.text = label === '姓名' ? '请输入姓名' : '请输入内容';
    element.source = WatermarkElementSource.MANUAL;
    element.positionX = 0.08;
    element.positionY = Math.min(0.82, 0.18 + this.watermarkElements.length * 0.1);
    element.sizePercent = 3.5;
    this.watermarkElements = this.watermarkElements.concat([element]);
    this.selectWatermark(element.id);
  }

  private selectEditorPreset(preset: WatermarkPreset): void {
    this.selectedPreset = preset;
    if (preset === WatermarkPreset.MINIMAL_DATE) {
      this.applyTemplate(createMinimalDateWatermarkTemplate(new Date()));
    } else if (preset === WatermarkPreset.TIME_LOCATION) {
      this.applyTemplate(createTimeLocationWatermarkTemplate(
        new Date(), this.locationText, this.coordinateText));
      this.loadCurrentLocationWatermark();
    } else {
      this.loadCustomWatermark();
    }
    this.editorTab = 1;
  }

  private addQuickSource(source: WatermarkElementSource): void {
    if (this.watermarkElements.length >= 8) {
      this.showToast('最多可以添加 8 个水印元素');
      return;
    }
    if (this.watermarkElements.some((item: WatermarkElementConfig) => item.source === source)) {
      this.showToast('这个自动信息已经添加');
      return;
    }
    const element = createSourceWatermarkElement(source, `capture_source_${Date.now()}`);
    element.positionY = Math.min(0.82, 0.18 + this.watermarkElements.length * 0.1);
    this.watermarkElements = this.watermarkElements.concat([element]);
    this.selectWatermark(element.id);
    if (source === WatermarkElementSource.CAPTURE_LOCATION ||
      source === WatermarkElementSource.CAPTURE_COORDINATES) {
      this.loadCurrentLocationWatermark();
    }
  }

  private deleteSelectedElement(): void {
    const index = this.selectedElementIndex();
    if (index < 0 || this.watermarkElements.length <= 1) {
      this.showToast('至少保留一个水印内容');
      return;
    }
    this.watermarkElements = this.watermarkElements.filter((item: WatermarkElementConfig) =>
      item.id !== this.selectedWatermarkId);
    this.selectWatermark(this.watermarkElements[0].id);
  }

  private saveCurrentAsDefault(): void {
    try {
      const settings = new WatermarkDefaults();
      settings.template.elements = this.watermarkElements.map((item: WatermarkElementConfig) =>
        cloneWatermarkElement(item));
      settings.template.brandSizePercent = this.brandSizePercent;
      settings.template.brandOpacity = this.brandOpacity;
      const firstText = this.watermarkElements.find((item: WatermarkElementConfig) =>
        item.type === WatermarkElementType.TEXT);
      settings.text = firstText?.text ?? '';
      settings.showText = firstText?.visible ?? false;
      settings.showLogo = true;
      settings.opacity = Math.round((firstText?.opacity ?? 0.88) * 100);
      this.settingsRepository.save(this.abilityContext, settings);
      this.selectedPreset = WatermarkPreset.CUSTOM;
      this.showToast('已保存为默认水印模板');
    } catch (error) {
      this.showToast(ErrorMessageUtil.from(error as object, '保存默认模板失败'));
    }
  }

  private replaceWatermarkElement(updated: WatermarkElementConfig): void {
    this.watermarkElements = this.watermarkElements.map((item: WatermarkElementConfig) =>
      item.id === updated.id ? updated : item);
  }

  private updateElementPosition(id: string, x: number, y: number): void {
    const index = this.watermarkElements.findIndex((item: WatermarkElementConfig) => item.id === id);
    if (index < 0) {
      return;
    }
    const updated = cloneWatermarkElement(this.watermarkElements[index]);
    updated.positionX = x;
    updated.positionY = y;
    this.replaceWatermarkElement(updated);
    if (id === this.selectedWatermarkId) {
      this.positionX = x;
      this.positionY = y;
    }
  }

  private updateElementScale(id: string, scale: number): void {
    const index = this.watermarkElements.findIndex((item: WatermarkElementConfig) => item.id === id);
    if (index < 0) {
      return;
    }
    const updated = cloneWatermarkElement(this.watermarkElements[index]);
    updated.scaleFactor = scale;
    this.replaceWatermarkElement(updated);
    if (id === this.selectedWatermarkId) {
      this.watermarkScale = scale;
    }
  }

  private updateSelectedText(value: string): void {
    const index = this.selectedElementIndex();
    if (index >= 0 && isAutomaticWatermarkSource(this.watermarkElements[index].source)) {
      this.showToast('自动信息由设备获取，不能手动修改');
      return;
    }
    this.watermarkText = value;
    if (index < 0 || this.watermarkElements[index].type !== WatermarkElementType.TEXT) {
      return;
    }
    const updated = cloneWatermarkElement(this.watermarkElements[index]);
    updated.text = value;
    this.replaceWatermarkElement(updated);
  }

  private updateSelectedOpacity(value: number): void {
    const index = this.selectedElementIndex();
    this.watermarkOpacity = value;
    if (index < 0) {
      return;
    }
    const updated = cloneWatermarkElement(this.watermarkElements[index]);
    updated.opacity = value / 100;
    this.replaceWatermarkElement(updated);
  }

  private updateSelectedSize(value: number): void {
    const index = this.selectedElementIndex();
    this.textSize = value;
    if (index < 0) {
      return;
    }
    const updated = cloneWatermarkElement(this.watermarkElements[index]);
    updated.sizePercent = value;
    this.replaceWatermarkElement(updated);
  }

  private updatePosition(x: number, y: number): void {
    this.positionX = x;
    this.positionY = y;
    if (this.selectedWatermarkId.length > 0) {
      this.updateElementPosition(this.selectedWatermarkId, x, y);
    }
  }

  private updateScale(scale: number): void {
    this.watermarkScale = scale;
    if (this.selectedWatermarkId.length > 0) {
      this.updateElementScale(this.selectedWatermarkId, scale);
    }
  }

  private orientedPhotoWidth(): number {
    if (this.photoOutputWidth <= 0 || this.photoOutputHeight <= 0) {
      return Math.max(1, this.cameraViewportWidth());
    }
    const viewportLandscape = this.isLandscape();
    const photoLandscape = this.photoOutputWidth >= this.photoOutputHeight;
    return viewportLandscape === photoLandscape ? this.photoOutputWidth : this.photoOutputHeight;
  }

  private orientedPhotoHeight(): number {
    if (this.photoOutputWidth <= 0 || this.photoOutputHeight <= 0) {
      return Math.max(1, this.cameraViewportHeight());
    }
    const viewportLandscape = this.isLandscape();
    const photoLandscape = this.photoOutputWidth >= this.photoOutputHeight;
    return viewportLandscape === photoLandscape ? this.photoOutputHeight : this.photoOutputWidth;
  }

  private exportImageWidth(): number {
    const width = this.orientedPhotoWidth();
    const height = this.orientedPhotoHeight();
    const scale = Math.min(1, 3072 / Math.max(width, height));
    return Math.max(1, Math.round(width * scale));
  }

  private exportImageHeight(): number {
    const width = this.orientedPhotoWidth();
    const height = this.orientedPhotoHeight();
    const scale = Math.min(1, 3072 / Math.max(width, height));
    return Math.max(1, Math.round(height * scale));
  }

  private previewImageScale(): number {
    if (this.cameraViewportWidth() <= 0 || this.cameraViewportHeight() <= 0) {
      return 1;
    }
    return Math.min(this.cameraViewportWidth() / this.exportImageWidth(),
      this.cameraViewportHeight() / this.exportImageHeight());
  }

  private previewImageWidth(): number {
    return this.exportImageWidth() * this.previewImageScale();
  }

  private previewImageHeight(): number {
    return this.exportImageHeight() * this.previewImageScale();
  }

  private previewImageX(): number {
    return (this.cameraViewportWidth() - this.previewImageWidth()) / 2;
  }

  private previewImageY(): number {
    return (this.cameraViewportHeight() - this.previewImageHeight()) / 2;
  }


  private previewToExportScale(): number {
    return this.previewImageWidth() / this.exportImageWidth();
  }

  private watermarkMargin(): number {
    const exportMargin = Math.max(18,
      Math.round(Math.min(this.exportImageWidth(), this.exportImageHeight()) * 0.025));
    return exportMargin * this.previewToExportScale();
  }

  private watermarkFrameX(): number {
    return this.previewImageX() + this.watermarkMargin();
  }

  private watermarkFrameY(): number {
    return this.previewImageY() + this.watermarkMargin();
  }

  private watermarkFrameWidth(): number {
    return Math.max(1, this.previewImageWidth() - this.watermarkMargin() * 2);
  }

  private watermarkFrameHeight(): number {
    return Math.max(1, this.previewImageHeight() - this.watermarkMargin() * 2);
  }

  private clampElementScale(scale: number): number {
    return Math.min(2.5, Math.max(0.5, scale));
  }

  private previewElementSize(element: WatermarkElementConfig): number {
    const scale = this.clampElementScale(element.scaleFactor);
    const exportSize = Math.max(24,
      Math.round(this.exportImageWidth() * element.sizePercent / 100 * scale));
    return exportSize * this.previewToExportScale() / scale;
  }

  private previewTextMaxWidth(): number {
    return Math.round(this.exportImageWidth() * 0.68) * this.previewToExportScale();
  }

  private elementRenderKey(element: WatermarkElementConfig): string {
    return element.id + ':' + element.type + ':' + element.text + ':' + element.imageUri + ':' +
      Math.round(this.previewImageWidth()) + 'x' + Math.round(this.previewImageHeight());
  }

  private brandDisplaySize(): number {
    const exportSize = Math.max(20,
      Math.round(this.exportImageWidth() * this.brandSizePercent / 100));
    return exportSize * this.previewToExportScale();
  }

  private brandLabelSize(): number {
    const exportIconSize = Math.max(20,
      Math.round(this.exportImageWidth() * this.brandSizePercent / 100));
    return Math.max(14, Math.round(exportIconSize * 0.38)) * this.previewToExportScale();
  }

  private brandPadding(): number {
    const exportLabelSize = this.brandLabelSize() / this.previewToExportScale();
    return Math.max(7, Math.round(exportLabelSize * 0.32)) * this.previewToExportScale();
  }

  private brandGap(): number {
    const exportLabelSize = this.brandLabelSize() / this.previewToExportScale();
    return Math.max(4, Math.round(exportLabelSize * 0.22)) * this.previewToExportScale();
  }

  private brandBadgeWidth(): number {
    return Math.max(this.brandDisplaySize(), this.brandLabelSize() * 6) + this.brandPadding() * 2;
  }

  private brandBadgeHeight(): number {
    return this.brandPadding() * 2 + this.brandDisplaySize() +
      this.brandGap() + this.brandLabelSize() * 1.28;
  }
  private isWide(): boolean {
    return this.viewportWidth >= 700;
  }

  private isLandscape(): boolean {
    return this.viewportWidth >= this.viewportHeight;
  }

  private editorPanelWidth(): number {
    return this.editorMode && this.isLandscape() ? 420 : 0;
  }

  private editorPanelHeight(): number {
    if (!this.editorMode || this.isLandscape()) {
      return 0;
    }
    return Math.min(600, Math.max(360, this.viewportHeight * 0.46));
  }

  private cameraViewportWidth(): number {
    return Math.max(1, this.viewportWidth - this.editorPanelWidth());
  }

  private cameraViewportHeight(): number {
    return Math.max(1, this.viewportHeight - this.editorPanelHeight());
  }


  private toggleText(value: boolean): void {
    const index = this.selectedElementIndex();
    this.showText = value;
    if (index < 0 || this.watermarkElements[index].type !== WatermarkElementType.TEXT) {
      return;
    }
    const updated = cloneWatermarkElement(this.watermarkElements[index]);
    updated.visible = value;
    this.replaceWatermarkElement(updated);
  }

  private toggleLogo(_value: boolean): void {
    this.showLogo = true;
    this.showToast('映刻标识会以小尺寸始终显示');
  }
  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (_) {
    }
  }

  @Builder
  private settingsGlyph() {
    Column({ space: 4 }) {
      Row() {
        Divider().width(19).strokeWidth(2).color(Color.White)
        Circle().width(5).height(5).fill(Color.White).position({ x: 4, y: 0 })
      }.width(24).height(5)
      Row() {
        Divider().width(19).strokeWidth(2).color(Color.White)
        Circle().width(5).height(5).fill(Color.White).position({ x: 14, y: 0 })
      }.width(24).height(5)
      Row() {
        Divider().width(19).strokeWidth(2).color(Color.White)
        Circle().width(5).height(5).fill(Color.White).position({ x: 8, y: 0 })
      }.width(24).height(5)
    }.width(24)
  }

  @Builder
  private settingsPanel() {
    Stack({ alignContent: this.editorMode && !this.isLandscape() ? Alignment.Bottom : Alignment.End }) {
      if (!this.editorMode) {
        Column().width('100%').height('100%').backgroundColor('#77000000')
          .onClick(() => this.showSettings = false)
      }

      Column() {
        Row({ space: 12 }) {
          Column({ space: 3 }) {
            Text('实时水印编辑').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#3B2117')
            Text('直接在取景画面上编辑并拍摄').fontSize(12).fontColor('#9A725C')
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Button('保存').height(38).padding({ left: 16, right: 16 }).type(ButtonType.Normal)
            .fontSize(13).fontWeight(FontWeight.Bold).fontColor(Color.White)
            .backgroundColor('#E96832').borderRadius(19)
            .onClick(() => this.saveCurrentAsDefault())
          if (!this.editorMode) {
            Button('×').width(38).height(38).fontSize(22).type(ButtonType.Normal)
              .fontColor('#5A3829').backgroundColor('#FFF0E3').borderRadius(19)
              .onClick(() => this.showSettings = false)
          }
        }.width('100%').padding({ left: 20, right: 18, top: 18, bottom: 12 })

        Row() {
          Button('模板').layoutWeight(1).height(40).type(ButtonType.Normal).fontSize(13)
            .fontWeight(this.editorTab === 0 ? FontWeight.Bold : FontWeight.Regular)
            .fontColor(this.editorTab === 0 ? Color.White : '#765442')
            .backgroundColor(this.editorTab === 0 ? '#D96735' : Color.Transparent)
            .borderRadius(14).onClick(() => this.editorTab = 0)
          Button('内容').layoutWeight(1).height(40).type(ButtonType.Normal).fontSize(13)
            .fontWeight(this.editorTab === 1 ? FontWeight.Bold : FontWeight.Regular)
            .fontColor(this.editorTab === 1 ? Color.White : '#765442')
            .backgroundColor(this.editorTab === 1 ? '#D96735' : Color.Transparent)
            .borderRadius(14).onClick(() => this.editorTab = 1)
          Button('样式').layoutWeight(1).height(40).type(ButtonType.Normal).fontSize(13)
            .fontWeight(this.editorTab === 2 ? FontWeight.Bold : FontWeight.Regular)
            .fontColor(this.editorTab === 2 ? Color.White : '#765442')
            .backgroundColor(this.editorTab === 2 ? '#D96735' : Color.Transparent)
            .borderRadius(14).onClick(() => this.editorTab = 2)
        }.width('calc(100% - 40vp)').padding(4).backgroundColor('#F7E8DB').borderRadius(18)

        Scroll() {
          Column({ space: 15 }) {
            if (this.editorTab === 0) {
              Text('选择拍摄模板').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#4A3025').width('100%')
              Button('时间地点  ·  时间 / 地址 / 经纬度').width('100%').height(50).type(ButtonType.Normal)
                .fontSize(13).fontColor('#6A412F').backgroundColor('#FFF1E5').borderRadius(14)
                .onClick(() => this.selectEditorPreset(WatermarkPreset.TIME_LOCATION))
              Button('极简日期  ·  只显示拍摄日期').width('100%').height(50).type(ButtonType.Normal)
                .fontSize(13).fontColor('#6A412F').backgroundColor('#FFF1E5').borderRadius(14)
                .onClick(() => this.selectEditorPreset(WatermarkPreset.MINIMAL_DATE))
              Button('我的模板  ·  使用已保存内容').width('100%').height(50).type(ButtonType.Normal)
                .fontSize(13).fontColor('#6A412F').backgroundColor('#FFF1E5').borderRadius(14)
                .onClick(() => this.selectEditorPreset(WatermarkPreset.CUSTOM))
              Text('切换模板后，水印会立即显示在实时取景画面中。')
                .fontSize(11).lineHeight(17).fontColor('#9A725C').width('100%')
            } else if (this.editorTab === 1) {
              Row() {
                Text('当前内容').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#4A3025')
                Blank()
                Text(`${this.watermarkElements.length}/8`).fontSize(11).fontColor('#A07A63')
              }.width('100%')
              ForEach(this.watermarkElements, (element: WatermarkElementConfig) => {
                Row({ space: 10 }) {
                  Text(element.type === WatermarkElementType.IMAGE ? '▧' : '⠿')
                    .fontSize(17).fontColor('#B36A43')
                  Column({ space: 3 }) {
                    Text(watermarkElementDisplayText(element)).fontSize(13).fontColor('#4A3025')
                      .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
                    if (element.type === WatermarkElementType.TEXT) {
                      Text(watermarkSourceLabel(element.source)).fontSize(10)
                        .fontColor(isAutomaticWatermarkSource(element.source) ? '#47745D' : '#9B623E')
                    }
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  if (element.id === this.selectedWatermarkId) {
                    Text('编辑中').fontSize(10).fontColor('#E96832')
                  }
                }.width('100%').padding(12)
                  .backgroundColor(element.id === this.selectedWatermarkId ? '#FFF0E3' : '#FFF9F3')
                  .borderRadius(14).onClick(() => {
                    this.selectWatermark(element.id);
                    this.editorTab = 2;
                  })
              }, (element: WatermarkElementConfig) => element.id)
              Row({ space: 8 }) {
                Button('＋姓名').layoutWeight(1).height(38).type(ButtonType.Normal).fontSize(11)
                  .fontColor('#78472E').backgroundColor('#FFF0E3').borderRadius(12)
                  .onClick(() => this.addQuickManualField('姓名'))
                Button('＋自定义').layoutWeight(1).height(38).type(ButtonType.Normal).fontSize(11)
                  .fontColor('#78472E').backgroundColor('#FFF0E3').borderRadius(12)
                  .onClick(() => this.addQuickManualField('自定义字段'))
              }.width('100%')
              Row({ space: 8 }) {
                Button('＋日期时间').layoutWeight(1).height(38).type(ButtonType.Normal).fontSize(11)
                  .fontColor('#356149').backgroundColor('#E9F3EC').borderRadius(12)
                  .onClick(() => this.addQuickSource(WatermarkElementSource.CAPTURE_DATE_TIME))
                Button('＋地点').layoutWeight(1).height(38).type(ButtonType.Normal).fontSize(11)
                  .fontColor('#356149').backgroundColor('#E9F3EC').borderRadius(12)
                  .onClick(() => this.addQuickSource(WatermarkElementSource.CAPTURE_LOCATION))
                Button('＋经纬度').layoutWeight(1).height(38).type(ButtonType.Normal).fontSize(11)
                  .fontColor('#356149').backgroundColor('#E9F3EC').borderRadius(12)
                  .onClick(() => this.addQuickSource(WatermarkElementSource.CAPTURE_COORDINATES))
              }.width('100%')
              Row({ space: 8 }) {
                Text('◆ 自动信息锁定').fontSize(11).fontColor('#47745D')
                Blank()
                Text('✎ 手动信息标注').fontSize(11).fontColor('#9B623E')
              }.width('100%').padding(12).backgroundColor('#FFF4E9').borderRadius(13)
            } else {
              if (this.selectedElementIsAutomatic()) {
                Column({ space: 7 }) {
                  Text(`◆ ${watermarkSourceLabel(this.watermarkElements[this.selectedElementIndex()].source)}`)
                    .fontSize(12).fontWeight(FontWeight.Bold).fontColor('#47745D').width('100%')
                  Text(this.watermarkText).fontSize(14).fontColor('#355544').width('100%')
                  Text('拍摄时由设备自动获取，内容不可手动修改').fontSize(11).fontColor('#718D7B').width('100%')
                }.width('100%').padding(14).backgroundColor('#EAF4ED').borderRadius(14)
              } else {
                Text('手动填写内容').fontSize(14).fontWeight(FontWeight.Medium)
                  .fontColor('#5A3829').width('100%')
                TextArea({ text: this.watermarkText, placeholder: '输入姓名或自定义内容' })
                  .width('100%').height(80).maxLength(100).backgroundColor('#FFF8F1')
                  .onChange((value: string) => this.updateSelectedText(value))
                Text('✎ 手动填写 · 不代表拍摄现场自动信息').fontSize(11).fontColor('#9B623E').width('100%')
              }
              Column({ space: 6 }) {
                Text(`透明度 ${Math.round(this.watermarkOpacity)}%`).fontSize(13).fontColor('#5A3829').width('100%')
                Slider({ value: this.watermarkOpacity, min: 20, max: 100, step: 5 })
                  .selectedColor('#E96832').onChange((value: number) => this.updateSelectedOpacity(value))
              }.width('100%')
              Column({ space: 6 }) {
                Text(`大小 ${this.textSize.toFixed(1)}%`).fontSize(13).fontColor('#5A3829').width('100%')
                Slider({ value: this.textSize, min: 2, max: 10, step: 0.5 })
                  .selectedColor('#E96832').onChange((value: number) => this.updateSelectedSize(value))
              }.width('100%')
              Column({ space: 6 }) {
                Text(`整体缩放 ${Math.round(this.watermarkScale * 100)}%`).fontSize(13).fontColor('#5A3829').width('100%')
                Slider({ value: this.watermarkScale, min: 0.5, max: 2.5, step: 0.05 })
                  .selectedColor('#E96832').onChange((value: number) => this.updateScale(value))
              }.width('100%')
              Row({ space: 8 }) {
                Button('左下').layoutWeight(1).height(38).type(ButtonType.Normal).fontSize(11)
                  .fontColor('#5A3829').backgroundColor('#FFF0E3').onClick(() => this.updatePosition(0.1, 0.72))
                Button('居中').layoutWeight(1).height(38).type(ButtonType.Normal).fontSize(11)
                  .fontColor('#5A3829').backgroundColor('#FFF0E3').onClick(() => this.updatePosition(0.5, 0.5))
                Button('右下').layoutWeight(1).height(38).type(ButtonType.Normal).fontSize(11)
                  .fontColor(Color.White).backgroundColor('#E96832').onClick(() => this.updatePosition(0.9, 0.72))
              }.width('100%')
              Button('删除当前内容').width('100%').height(40).type(ButtonType.Normal).fontSize(12)
                .fontColor('#A24C3A').backgroundColor('#FFF5F0').borderRadius(13)
                .onClick(() => this.deleteSelectedElement())
              Text('也可以直接在取景画面中拖动、双指缩放水印。')
                .fontSize(11).fontColor('#9A725C').width('100%').textAlign(TextAlign.Center)
            }
          }.width('100%').padding({ left: 20, right: 20, top: 16, bottom: 28 })
        }.layoutWeight(1).width('100%')
      }
      .width(this.editorMode ? (this.isLandscape() ? 420 : '100%') :
        (this.isWide() ? 390 : '92%'))
      .height(this.editorMode ? (this.isLandscape() ? '100%' : this.editorPanelHeight()) : '100%')
      .backgroundColor('#FFFFFBF7')
      .border({ width: 1, color: '#E8C7AE' })
      .shadow({ radius: 24, color: '#44000000', offsetX: -8 })
    }.width('100%').height('100%').zIndex(20)
      .hitTestBehavior(HitTestMode.Transparent)
  }


  build() {
    Stack({ alignContent: Alignment.Center }) {
      XComponent({ id: 'cameraPreview', type: XComponentType.SURFACE, controller: this.controller })
        .width(this.previewImageWidth()).height(this.previewImageHeight())
        .position({ x: this.previewImageX(), y: this.previewImageY() })
        .onLoad(() => {
          this.surfaceId = this.controller.getXComponentSurfaceId();
          if (this.permissionState === PermissionState.GRANTED) {
            this.startCamera();
          }
        })
        .onDestroy(() => {
          this.surfaceId = '';
          this.pauseCamera();
        })


      Column() {
        Row({ space: 10 }) {
          Button('‹').width(50).height(50).fontSize(28).type(ButtonType.Normal)
            .backgroundColor('#66000000').fontColor(Color.White).borderRadius(25)
            .onClick(() => this.getUIContext().getRouter().back())
          Column({ space: 2 }) {
            Text('映刻相机').fontSize(18).fontWeight(FontWeight.Bold).fontColor(Color.White)
            Text('拖动移动 · 双指缩放 · 双击编辑').fontSize(11).fontColor('#CCFFFFFF')
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)

          Column({ space: 1 }) {
            Text('ϟ').fontSize(25).fontWeight(FontWeight.Bold)
              .fontColor(this.flashEnabled ? '#FFD166' : Color.White)
            Text(this.flashEnabled ? '已开' : '闪光').fontSize(9)
              .fontColor(this.flashEnabled ? '#FFD166' : '#DDFFFFFF')
          }
          .width(52).height(52).justifyContent(FlexAlign.Center)
          .backgroundColor(this.flashEnabled ? '#664B3700' : '#66000000').borderRadius(26)
          .opacity(this.flashAvailable ? 1 : 0.5).onClick(() => this.toggleFlash())

          Column({ space: 1 }) {
            Text('↻').fontSize(25).fontWeight(FontWeight.Bold).fontColor(Color.White)
            Text('翻转').fontSize(9).fontColor('#DDFFFFFF')
          }
          .width(52).height(52).justifyContent(FlexAlign.Center)
          .backgroundColor('#66000000').borderRadius(26)
          .opacity(this.switching ? 0.5 : 1).onClick(() => this.switchCamera())
          if (!this.editorMode) {
            Column({ space: 2 }) {
              this.settingsGlyph()
              Text('设置').fontSize(9).fontColor('#DDFFFFFF')
            }
            .width(52).height(52).justifyContent(FlexAlign.Center)
            .backgroundColor('#66000000').borderRadius(26)
            .onClick(() => this.showSettings = true)
          }

        }.width('100%').padding({ left: 18, right: 18, top: 18 })
        Blank()

        if (this.statusText) {
          Text(this.statusText).fontSize(14).fontColor(Color.White)
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
            .backgroundColor('#88000000').borderRadius(18).margin({ bottom: 14 })
        } else {
          Text('拖动移动 · 双指缩放 · 双击编辑').fontSize(12).fontColor(Color.White)
            .padding({ left: 14, right: 14, top: 7, bottom: 7 })
            .backgroundColor('#66000000').borderRadius(16).margin({ bottom: 12 })
        }

        Row() {
          Button('').width(82).height(82).borderRadius(41).backgroundColor(Color.White)
            .border({ width: 6, color: '#88FFFFFF', radius: 41 })
            .enabled(this.ready && !this.capturing).onClick(() => this.takePhoto())
        }.width('100%').justifyContent(FlexAlign.Center)
          .padding({ left: 30, right: 30, bottom: 26 })
      }.width(this.cameraViewportWidth()).height(this.cameraViewportHeight())
        .position({ x: 0, y: 0 })
        .hitTestBehavior(HitTestMode.Transparent)

      if (this.permissionState === PermissionState.GRANTED) {
        ForEach(this.watermarkElements, (element: WatermarkElementConfig) => {
          if (element.visible) {
            WatermarkElementOverlay({
              elementId: element.id,
              elementType: element.type,
              text: watermarkElementDisplayText(element),
              sourceBadgeText: element.type === WatermarkElementType.TEXT && element.showSourceBadge ?
                watermarkSourceLabel(element.source) : '',
              sourceBadgeAutomatic: isAutomaticWatermarkSource(element.source),
              imageUri: element.imageUri,
              opacityValue: element.opacity,
              sizeValue: this.previewElementSize(element),
              scaleFactor: element.scaleFactor,
              positionX: element.positionX,
              positionY: element.positionY,
              frameX: this.watermarkFrameX(),
              frameY: this.watermarkFrameY(),
              frameWidth: this.watermarkFrameWidth(),
              frameHeight: this.watermarkFrameHeight(),
              textMaxWidthValue: this.previewTextMaxWidth(),
              textRenderScale: 1 / this.getUIContext().vp2px(1),
              interactionPadding: 0,
              selected: element.id === this.selectedWatermarkId,
              editable: true,
              onSelect: (id: string) => this.selectWatermark(id),
              onPositionChange: (id: string, x: number, y: number) => this.updateElementPosition(id, x, y),
              onScaleChange: (id: string, scale: number) => this.updateElementScale(id, scale),
              onEditRequest: (id: string) => {
                this.selectWatermark(id);
                this.showSettings = true;
              }
            })
          }
        }, (element: WatermarkElementConfig) => this.elementRenderKey(element))
        WatermarkBrandBadge({
          iconSize: this.brandDisplaySize(),
          badgeWidth: this.brandBadgeWidth(),
          badgeHeight: this.brandBadgeHeight(),
          labelSizeValue: this.brandLabelSize() / this.getUIContext().vp2px(1),
          paddingValue: this.brandPadding(),
          gapValue: this.brandGap(),
          opacityValue: this.brandOpacity
        })
        .position({
          x: this.previewImageX() + this.previewImageWidth() -
            this.watermarkMargin() - this.brandBadgeWidth(),
          y: this.previewImageY() + this.previewImageHeight() -
            this.watermarkMargin() - this.brandBadgeHeight()
        })
      }

      if (this.showSettings) {
        this.settingsPanel()
      }

      if (this.permissionState !== PermissionState.GRANTED) {
        PermissionGuide({
          permissionState: this.permissionState,
          requestPermission: () => this.checkAndRequestPermission(),
          openSettings: () => this.openPermissionSetting()
        })
      }
    }
    .width('100%').height('100%').backgroundColor('#0E1118')
    .onAreaChange((_oldValue, newValue) => {
      this.viewportWidth = Number(newValue.width);
      this.viewportHeight = Number(newValue.height);
    })
  }
}