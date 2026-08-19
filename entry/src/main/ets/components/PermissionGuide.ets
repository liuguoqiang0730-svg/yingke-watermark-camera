import { PermissionState } from '../models/PermissionState';

@Component
export struct PermissionGuide {
  @Prop permissionState: PermissionState;
  requestPermission: () => void = (): void => {};
  openSettings: () => void = (): void => {};

  build() {
    Column({ space: 16 }) {
      Text('需要相机权限').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#172033')
      Text('仅在你进入拍摄页时申请。照片只在设备本地处理，不会上传。')
        .fontSize(15).fontColor('#5B6475').lineHeight(22).textAlign(TextAlign.Center)
      Button(this.permissionState === PermissionState.REQUESTING ? '正在申请…' : '允许使用相机')
        .width('100%').height(48).enabled(this.permissionState !== PermissionState.REQUESTING)
        .onClick(() => this.requestPermission())
      if (this.permissionState === PermissionState.DENIED || this.permissionState === PermissionState.ERROR) {
        Button('前往设置授权').width('100%').height(44).type(ButtonType.Normal)
          .backgroundColor(Color.Transparent).fontColor('#365CF5')
          .border({ width: 1, color: '#365CF5', radius: 22 }).onClick(() => this.openSettings())
      }
    }
    .width('88%').padding(24).backgroundColor('#FFFFFF').borderRadius(24)
    .alignItems(HorizontalAlign.Center)
  }
}
