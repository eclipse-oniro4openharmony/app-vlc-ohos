export interface VlcInstance { }
export interface VlcMedia { }
export interface VlcMediaPlayer { }

export function vlcNew(args: string[]): VlcInstance;
export function vlcRelease(instance: VlcInstance): void;

export function mediaNewPath(instance: VlcInstance, path: string): VlcMedia;
export function mediaNewLocation(instance: VlcInstance, url: string): VlcMedia;
export function mediaNewFd(instance: VlcInstance, fd: number): VlcMedia;
export function mediaRelease(media: VlcMedia): void;

export function mediaPlayerNew(instance: VlcInstance): VlcMediaPlayer;
export function mediaPlayerSetMedia(player: VlcMediaPlayer, media: VlcMedia): void;
export function mediaPlayerPlay(player: VlcMediaPlayer): void;
export function mediaPlayerSetPause(player: VlcMediaPlayer, doPause: boolean): void;
export function mediaPlayerPause(player: VlcMediaPlayer): void;
export function mediaPlayerIsPlaying(player: VlcMediaPlayer): boolean;
export function mediaPlayerStop(player: VlcMediaPlayer): void;

export function mediaPlayerGetTime(player: VlcMediaPlayer): number;
export function mediaPlayerSetTime(player: VlcMediaPlayer, time: number): void;
export function mediaPlayerGetLength(player: VlcMediaPlayer): number;
export function mediaPlayerGetPosition(player: VlcMediaPlayer): number;
export function mediaPlayerSetPosition(player: VlcMediaPlayer, position: number): void;
export function mediaPlayerGetVideoSize(player: VlcMediaPlayer): { width: number, height: number };
export function mediaPlayerSetDisplaySize(player: VlcMediaPlayer, width: number, height: number): void;
export function mediaPlayerSetNativeWindow(player: VlcMediaPlayer, surfaceId: string): void;
export function mediaPlayerSetAspectRatio(player: VlcMediaPlayer, aspect: string): void;
export function mediaPlayerSetCrop(player: VlcMediaPlayer, crop: string): void;
/** 0 fits the picture in the surface; any other value zooms the video's own size. */
export function mediaPlayerSetScale(player: VlcMediaPlayer, scale: number): void;

export interface VlcTrackDescription { id: number, name: string }
export interface VlcMediaTrack {
  type: 'audio' | 'video' | 'text',
  codec: string,
  description: string,
  language: string,
  width: number,
  height: number,
  frameRateNum: number,
  frameRateDen: number,
  channels: number,
  rate: number
}
export interface VlcMediaInfo {
  status: number, // libvlc_media_parsed_status_t: 1 skipped, 2 failed, 3 timeout, 4 done
  durationMs: number,
  title: string,
  tracks: Array<VlcMediaTrack>
}
export function mediaPlayerSetRate(player: VlcMediaPlayer, rate: number): boolean;
export function mediaPlayerGetRate(player: VlcMediaPlayer): number;
export function mediaPlayerGetAudioTracks(player: VlcMediaPlayer): Array<VlcTrackDescription>;
export function mediaPlayerGetSpuTracks(player: VlcMediaPlayer): Array<VlcTrackDescription>;
export function mediaPlayerGetAudioTrack(player: VlcMediaPlayer): number;
export function mediaPlayerSetAudioTrack(player: VlcMediaPlayer, id: number): boolean;
export function mediaPlayerGetSpu(player: VlcMediaPlayer): number;
export function mediaPlayerSetSpu(player: VlcMediaPlayer, id: number): boolean;
export function mediaParse(media: VlcMedia, timeoutMs: number): Promise<VlcMediaInfo>;
export function libvlcVersion(): string;

export function mediaPlayerAttachEvent(player: VlcMediaPlayer, eventType: number, callback: (event: any) => void): void;
export function mediaPlayerDetachEvent(player: VlcMediaPlayer, eventType: number): void;
export const mediaPlayerCleanup: (player: any, media: any, instance: any) => void;
