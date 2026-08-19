import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { PermissionState } from '../../models/PermissionState';

const DOMAIN: number = 0x0000;
const TAG: string = 'PermissionManager';

export const CAMERA_PERMISSION: Permissions = 'ohos.permission.CAMERA';

export class PermissionManager {
  private static instance: PermissionManager = new PermissionManager();
  private readonly atManager = abilityAccessCtrl.createAtManager();
  private requesting: boolean = false;

  private constructor() {
  }

  static getInstance(): PermissionManager {
    return PermissionManager.instance;
  }

  checkPermission(context: common.UIAbilityContext, permission: Permissions): PermissionState {
    try {
      const grantStatus = this.atManager.checkAccessTokenSync(
        context.applicationInfo.accessTokenId,
        permission
      );
      return grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED ?
        PermissionState.GRANTED : PermissionState.DENIED;
    } catch (error) {
      const businessError = error as BusinessError;
      hilog.error(DOMAIN, TAG, 'Check permission failed. code=%{public}d, message=%{public}s',
        businessError.code, businessError.message);
      return PermissionState.ERROR;
    }
  }

  async requestPermission(context: common.UIAbilityContext, permission: Permissions): Promise<PermissionState> {
    const currentState = this.checkPermission(context, permission);
    if (currentState === PermissionState.GRANTED) {
      return currentState;
    }
    if (this.requesting) {
      return PermissionState.REQUESTING;
    }

    this.requesting = true;
    try {
      const result = await this.atManager.requestPermissionsFromUser(context, [permission]);
      const permissionIndex = result.permissions.indexOf(permission);
      if (permissionIndex < 0 || permissionIndex >= result.authResults.length) {
        return PermissionState.ERROR;
      }
      return result.authResults[permissionIndex] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED ?
        PermissionState.GRANTED : PermissionState.DENIED;
    } catch (error) {
      const businessError = error as BusinessError;
      hilog.error(DOMAIN, TAG, 'Request permission failed. code=%{public}d, message=%{public}s',
        businessError.code, businessError.message);
      return PermissionState.ERROR;
    } finally {
      this.requesting = false;
    }
  }

  async requestPermissionOnSetting(context: common.UIAbilityContext,
    permission: Permissions): Promise<PermissionState> {
    const currentState = this.checkPermission(context, permission);
    if (currentState === PermissionState.GRANTED) {
      return currentState;
    }
    if (this.requesting) {
      return PermissionState.REQUESTING;
    }

    this.requesting = true;
    try {
      const grantStatusList = await this.atManager.requestPermissionOnSetting(context, [permission]);
      return grantStatusList[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED ?
        PermissionState.GRANTED : PermissionState.DENIED;
    } catch (error) {
      const businessError = error as BusinessError;
      hilog.error(DOMAIN, TAG, 'Request permission on setting failed. code=%{public}d, message=%{public}s',
        businessError.code, businessError.message);
      return PermissionState.ERROR;
    } finally {
      this.requesting = false;
    }
  }
}