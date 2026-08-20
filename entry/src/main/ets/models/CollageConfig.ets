export enum CollageLayout {
  VERTICAL = 'vertical',
  HORIZONTAL = 'horizontal',
  GRID = 'grid'
}

export class CollageConfig {
  layout: CollageLayout = CollageLayout.VERTICAL;
  spacing: number = 12;
  backgroundColor: string = '#FFFFFFFF';
  cornerRadius: number = 20;
}
