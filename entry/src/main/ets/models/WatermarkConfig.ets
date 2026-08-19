export enum WatermarkPosition {
  TOP_LEFT = 'top_left',
  TOP_RIGHT = 'top_right',
  CENTER = 'center',
  BOTTOM_LEFT = 'bottom_left',
  BOTTOM_RIGHT = 'bottom_right'
}

export class WatermarkConfig {
  text: string = '映刻 · 记录此刻';
  position: WatermarkPosition = WatermarkPosition.BOTTOM_RIGHT;
  opacity: number = 0.8;
  textSizePercent: number = 4;
  logoSizePercent: number = 12;
  showText: boolean = true;
  showLogo: boolean = true;
}
