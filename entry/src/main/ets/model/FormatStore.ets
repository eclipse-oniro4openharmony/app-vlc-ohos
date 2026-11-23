export class FormatStore {
  private static instance: FormatStore | undefined = undefined;

  static getInstance(): FormatStore {
    if (FormatStore.instance === undefined) {
      FormatStore.instance = new FormatStore();
    }
    return FormatStore.instance;
  }

  /** VLC's Tools.millisToString: m:ss under an hour, h:mm:ss from an hour, leading minus when negative. */
  formatTime(ms: number): string {
    const negative: boolean = ms < 0;
    const total: number = Math.floor(Math.abs(ms) / 1000);
    const h: number = Math.floor(total / 3600);
    const m: number = Math.floor((total % 3600) / 60);
    const s: number = total % 60;
    const ss: string = s < 10 ? `0${s}` : `${s}`;
    let text: string;
    if (h > 0) {
      const mm: string = m < 10 ? `0${m}` : `${m}`;
      text = `${h}:${mm}:${ss}`;
    } else {
      text = `${m}:${ss}`;
    }
    return negative ? `-${text}` : text;
  }

  formatRate(rate: number): string {
    return `${rate.toFixed(2)}x`;
  }

  clampRate(rate: number): number {
    const rounded: number = Math.round(rate * 100) / 100;
    return Math.min(4.0, Math.max(0.25, rounded));
  }

  /** VLC's generateResolutionClass. */
  resolutionClass(width: number, height: number): string {
    if (width <= 0 || height <= 0) {
      return '';
    }
    if (width >= 7680 || height >= 4320) {
      return '8K';
    }
    if (width >= 3840 || height >= 2160) {
      return '4K';
    }
    if (width >= 2560 || height >= 1440) {
      return '1440p';
    }
    if (width >= 1920 || height >= 1080) {
      return '1080p';
    }
    if (width >= 1280 || height >= 720) {
      return '720p';
    }
    return 'SD';
  }

  formatSize(bytes: number): string {
    if (bytes < 1024) {
      return `${Math.max(0, Math.floor(bytes))} B`;
    }
    const units: string[] = ['KB', 'MB', 'GB'];
    let value: number = bytes / 1024;
    let unit: number = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value = value / 1024;
      unit++;
    }
    return `${value.toFixed(1)} ${units[unit]}`;
  }
}
