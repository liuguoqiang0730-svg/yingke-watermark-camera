import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { APP_BACKGROUND_EVENT, APP_FOREGROUND_EVENT } from '../common/constants/AppEvent';
import {
  APPROXIMATE_LOCATION_PERMISSION,
  PermissionManager
} from '../common/permission/PermissionManager';
import { PermissionState } from '../models/PermissionState';
import { TempFileManager } from '../services/TempFileManager';
import { WatermarkLocationService } from '../services/WatermarkLocationService';

const DOMAIN = 0x0000;
const TAG = 'EntryAbility';

export default class EntryAbility extends UIAbility {
  private async prepareLocationWatermark(): Promise<void> {
    const permissionManager = PermissionManager.getInstance();
    let permissionState = permissionManager.checkPermission(
      this.context, APPROXIMATE_LOCATION_PERMISSION);
    if (permissionState !== PermissionState.GRANTED) {
      permissionState = await permissionManager.requestLocationPermissions(this.context);
    }
    if (permissionState !== PermissionState.GRANTED) {
      hilog.info(DOMAIN, TAG, 'Location permission was not granted during app startup.');
      return;
    }
    await WatermarkLocationService.getInstance().getCurrentLocation();
  }

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    TempFileManager.cleanupAll();
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/HomePage', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Succeeded in loading the content.');
      this.prepareLocationWatermark().catch((error: object) => {
        hilog.warn(DOMAIN, TAG, 'Failed to prepare startup location. Cause: %{public}s', JSON.stringify(error));
      });
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onForeground');
    this.context.eventHub.emit(APP_FOREGROUND_EVENT);
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onBackground');
    this.context.eventHub.emit(APP_BACKGROUND_EVENT);
  }
}
