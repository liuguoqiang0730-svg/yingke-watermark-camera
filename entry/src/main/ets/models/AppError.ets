export enum AppErrorCode {
  PERMISSION_DENIED = 'permission_denied',
  CAMERA_UNAVAILABLE = 'camera_unavailable',
  CAMERA_BUSY = 'camera_busy',
  IMAGE_DECODE_FAILED = 'image_decode_failed',
  IMAGE_PROCESS_FAILED = 'image_process_failed',
  OCR_FAILED = 'ocr_failed',
  SAVE_FAILED = 'save_failed',
  SHARE_FAILED = 'share_failed',
  USER_CANCELLED = 'user_cancelled',
  UNKNOWN = 'unknown'
}

export class AppError extends Error {
  readonly code: AppErrorCode;
  readonly message: string;

  constructor(code: AppErrorCode, message: string) {
    super(message);
    this.code = code;
    this.message = message;
  }
}
