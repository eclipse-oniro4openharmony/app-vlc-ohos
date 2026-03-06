import vlcnative from "libvlcnative.so";

export enum VlcEvent {
  MediaChanged = 0x100,
  NothingSpecial = 0x101,
  Opening = 0x102,
  Buffering = 0x103,
  Playing = 0x104,
  Paused = 0x105,
  Stopped = 0x106,
  Forward = 0x107,
  Backward = 0x108,
  EndReached = 0x109,
  EncounteredError = 0x10a,
  TimeChanged = 0x10b,
  PositionChanged = 0x10c,
  LengthChanged = 0x111,
}

export interface VlcEventData {
  type: number;
  time?: number;
  position?: number;
  buffering?: number;
}

export interface VlcVideoSize {
  width: number;
  height: number;
}

export type VlcEventCallback = (event: VlcEventData) => void;

export class VlcService {
  private instance: vlcnative.VlcInstance | undefined = undefined;
  private player: vlcnative.VlcMediaPlayer | undefined = undefined;
  private media: vlcnative.VlcMedia | undefined = undefined;

  constructor() {
    this.ensureInitialized();
  }

  private ensureInitialized(): void {
    if (!this.instance) {
      const args: string[] = [
        "--verbose=2",
        "--plugin-path=/data/storage/el1/bundle/libs/arm64",
        "--vout=OHOSVout",
        "--aout=OHOSAout",
        "--no-xlib",
      ];
      this.instance = vlcnative.vlcNew(args);
    }
    if (!this.player) {
      this.player = vlcnative.mediaPlayerNew(this.instance);
    }
  }

  loadMedia(path: string): void {
    this.ensureInitialized();
    if (!this.instance || !this.player) return;

    if (this.media) {
      vlcnative.mediaRelease(this.media);
    }

    this.media = vlcnative.mediaNewPath(this.instance, path);
    vlcnative.mediaPlayerSetMedia(this.player, this.media);
  }

  loadMediaFd(fd: number): void {
    this.ensureInitialized();
    if (!this.instance || !this.player) return;

    if (this.media) {
      vlcnative.mediaRelease(this.media);
    }

    this.media = vlcnative.mediaNewFd(this.instance, fd);
    vlcnative.mediaPlayerSetMedia(this.player, this.media);
  }

  loadLocation(url: string): void {
    this.ensureInitialized();
    if (!this.instance || !this.player) return;

    if (this.media) {
      vlcnative.mediaRelease(this.media);
    }

    this.media = vlcnative.mediaNewLocation(this.instance, url);
    vlcnative.mediaPlayerSetMedia(this.player, this.media);
  }

  play(): void {
    if (this.player) {
      vlcnative.mediaPlayerPlay(this.player);
    }
  }

  setPause(doPause: boolean): void {
    if (this.player) {
      vlcnative.mediaPlayerSetPause(this.player, doPause);
    }
  }

  pause(): void {
    if (this.player) {
      vlcnative.mediaPlayerPause(this.player);
    }
  }

  isPlaying(): boolean {
    if (this.player) {
      return vlcnative.mediaPlayerIsPlaying(this.player);
    }
    return false;
  }

  stop(): void {
    if (this.player) {
      vlcnative.mediaPlayerStop(this.player);
    }
  }

  getTime(): number {
    return this.player ? vlcnative.mediaPlayerGetTime(this.player) : 0;
  }

  getLength(): number {
    return this.player ? vlcnative.mediaPlayerGetLength(this.player) : 0;
  }

  getPosition(): number {
    return this.player ? vlcnative.mediaPlayerGetPosition(this.player) : 0;
  }

  setPosition(pos: number): void {
    if (this.player) {
      vlcnative.mediaPlayerSetPosition(this.player, pos);
    }
  }

  seekTo(ms: number): void {
    if (this.player) {
      vlcnative.mediaPlayerSetTime(this.player, ms);
    }
  }

  getVideoSize(): VlcVideoSize {
    if (this.player) {
      return vlcnative.mediaPlayerGetVideoSize(this.player);
    }
    return { width: 0, height: 0 };
  }

  setDisplaySize(width: number, height: number): void {
    if (this.player) {
      vlcnative.mediaPlayerSetDisplaySize(this.player, width, height);
    }
  }

  setNativeWindow(surfaceId: string): void {
    if (this.player) {
      vlcnative.mediaPlayerSetNativeWindow(this.player, surfaceId);
    }
  }

  setAspectRatio(aspect: string): void {
    if (this.player) {
      vlcnative.mediaPlayerSetAspectRatio(this.player, aspect);
    }
  }

  setCrop(crop: string): void {
    if (this.player) {
      vlcnative.mediaPlayerSetCrop(this.player, crop);
    }
  }

  onEvent(eventType: VlcEvent, callback: VlcEventCallback): void {
    if (this.player) {
      vlcnative.mediaPlayerAttachEvent(
        this.player,
        eventType as number,
        callback as (event: object) => void,
      );
    }
  }

  detachEvent(eventType: VlcEvent): void {
    if (this.player) {
      vlcnative.mediaPlayerDetachEvent(this.player, eventType as number);
    }
  }

  destroy(): void {
    if (this.player || this.media) {
      // Async cleanup handles stop and release of player and media in the background.
      // We explicitly pass 'undefined' for the instance to keep it alive.
      vlcnative.mediaPlayerCleanup(this.player, this.media, undefined);

      this.player = undefined;
      this.media = undefined;
      // this.instance persists
    }
  }

  getPlayer(): vlcnative.VlcMediaPlayer | undefined {
    return this.player;
  }
}

export const vlcService = new VlcService();
