export class DetectionBox {
  left: number;
  top: number;
  width: number;
  height: number;

  constructor(left: number, top: number, width: number, height: number) {
    this.left = left;
    this.top = top;
    this.width = width;
    this.height = height;
  }
}

export class DetectedObject {
  id: number;
  label: string;
  score: number;
  box: DetectionBox;

  constructor(id: number, label: string, score: number, box: DetectionBox) {
    this.id = id;
    this.label = label;
    this.score = score;
    this.box = box;
  }
}

export class ObjectDetectionResult {
  previewUri: string;
  imageWidth: number;
  imageHeight: number;
  objects: DetectedObject[];

  constructor(previewUri: string, imageWidth: number, imageHeight: number, objects: DetectedObject[]) {
    this.previewUri = previewUri;
    this.imageWidth = imageWidth;
    this.imageHeight = imageHeight;
    this.objects = objects;
  }
}
