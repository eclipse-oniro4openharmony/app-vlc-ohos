import vlcnative from "libvlcnative.so";

export class VlcService {
  private instance: vlcnative.VlcInstance | undefined = undefined;
  private player: vlcnative.VlcMediaPlayer | undefined = undefined;
  private media: vlcnative.VlcMedia | undefined = undefined;

  constructor() {
    const args: string[] = [
      "--verbose=2",
      "--plugin-path=/data/storage/el1/bundle/libs/arm64",
      "--vout=OHOSVout",
      "--aout=OHOSAout",
      "--no-xlib",
    ];
    this.instance = vlcnative.vlcNew(args);
    this.player = vlcnative.mediaPlayerNew(this.instance);
  }

  loadMedia(path: string): void {
    if (!this.instance || !this.player) return;

    if (this.media) {
      vlcnative.mediaRelease(this.media);
    }

    this.media = vlcnative.mediaNewPath(this.instance, path);
    vlcnative.mediaPlayerSetMedia(this.player, this.media);
  }

  loadLocation(url: string): void {
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

  pause(): void {
    if (this.player) {
      vlcnative.mediaPlayerPause(this.player);
    }
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

  setNativeWindow(surfaceId: string): void {
    if (this.player) {
      vlcnative.mediaPlayerSetNativeWindow(this.player, surfaceId);
    }
  }

  onEvent(eventType: number, callback: (event: object) => void): void {
    if (this.player) {
      vlcnative.mediaPlayerAttachEvent(this.player, eventType, callback);
    }
  }

  detachEvent(eventType: number): void {
    if (this.player) {
      vlcnative.mediaPlayerDetachEvent(this.player, eventType);
    }
  }

  destroy(): void {
    if (this.player) {
      vlcnative.mediaPlayerStop(this.player);
      this.player = undefined;
    }
    if (this.media) {
      vlcnative.mediaRelease(this.media);
      this.media = undefined;
    }
    if (this.instance) {
      vlcnative.vlcRelease(this.instance);
      this.instance = undefined;
    }
  }

  getPlayer(): vlcnative.VlcMediaPlayer | undefined {
    return this.player;
  }
}

export const vlcService = new VlcService();
