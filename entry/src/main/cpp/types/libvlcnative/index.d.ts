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
export function mediaPlayerPause(player: VlcMediaPlayer): void;
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

export function mediaPlayerAttachEvent(player: VlcMediaPlayer, eventType: number, callback: (event: any) => void): void;
export function mediaPlayerDetachEvent(player: VlcMediaPlayer, eventType: number): void;
export const mediaPlayerCleanup: (player: any, media: any, instance: any) => void;
