import vlcnative from 'libvlcnative.so';
import type { common } from '@kit.AbilityKit';
import { vlcService } from '../../services/VlcService';

export class TrackItem {
  id: number = 0;
  label: string = '';
}

export class VlcXComponentController extends XComponentController {
  surfaceCreatedCallback: (surfaceId: string) => void = () => {};
  surfaceDestroyedCallback: () => void = () => {};
  surfaceSizeCallback: (width: number, height: number) => void = () => {};

  onSurfaceCreated(surfaceId: string): void {
    this.surfaceCreatedCallback(surfaceId);
  }

  onSurfaceChanged(surfaceId: string, rect: SurfaceRect): void {
    vlcService.setDisplaySize(rect.surfaceWidth, rect.surfaceHeight);
    this.surfaceSizeCallback(rect.surfaceWidth, rect.surfaceHeight);
  }

  onSurfaceDestroyed(surfaceId: string): void {
    this.surfaceDestroyedCallback();
  }
}

/** One pending timeout at a time. */
export class OneShotTimer {
  private id: number = -1;

  get pending(): boolean {
    return this.id !== -1;
  }

  start(ms: number, action: () => void): void {
    this.cancel();
    this.id = setTimeout(() => {
      this.id = -1;
      action();
    }, ms);
  }

  cancel(): void {
    if (this.id !== -1) {
      clearTimeout(this.id);
      this.id = -1;
    }
  }
}

/** The player's sheets: dark, fitted to their content, no mask over the picture (a tap on it closes them). */
export function playerSheetOptions(onClose: () => void, heightVp?: number): SheetOptions {
  return {
    height: heightVp !== undefined ? heightVp : SheetSize.FIT_CONTENT,
    backgroundColor: $r('app.color.player_sheet_background'),
    showClose: false,
    enableOutsideInteractive: true,
    onDisappear: onClose
  };
}

/** The tracks sheet's height in vp: both section titles, every row (48 vp), the drag bar and the bottom padding. */
export function tracksSheetHeight(audioRows: number, subtitleRows: number, pageHeight: number): number {
  // Disable alone comes with the 'No track' line, about one row more.
  const rows: number = Math.max(1, audioRows) + Math.max(2, subtitleRows);
  const wanted: number = 150 + rows * 48;
  return pageHeight > 0 ? Math.min(wanted, pageHeight * 0.85) : wanted;
}

/** Below this time a subtitle selection replays the media from 0. */
export const SUBTITLE_REPLAY_MS: number = 30000;

/**
 * Where to seek after a subtitle track is selected, so that a cue already begun shows. The mkv seek
 * prerolls only the indexed tracks (video, audio): a seek to the current time does not read again
 * the block of a cue begun earlier (seen on the device). Near the start the media is replayed from
 * 0, which reads it; further in, the seek to the current time shows the cues starting from there.
 */
export function subtitleSeekTarget(nowMs: number): number {
  return nowMs < SUBTITLE_REPLAY_MS ? 0 : nowMs;
}

/** The names of the resize modes, in VLC's order: Best fit, Fit screen, Fill, 16:9, 4:3, Center. */
export const MODE_NAMES: string[] = ['surface_best_fit', 'surface_fit_screen', 'surface_fill', 'surface_16_9',
  'surface_4_3', 'surface_original'];

/** The shape of the surface: the video's own, fixed once known (the vout does not follow later resizes). */
export function surfaceAspectOf(videoWidth: number, videoHeight: number): number {
  if (videoWidth <= 0 || videoHeight <= 0) {
    return 16 / 9;
  }
  return videoWidth / videoHeight;
}

/** The resize modes scale the drawn surface: [x, y] factors; videoWidthVp is the video's own width in vp. */
export function modeScaleOf(mode: number, pageWidth: number, pageHeight: number, aspect: number,
  videoWidthVp: number): number[] {
  const surfaceHeight: number = pageWidth / aspect;
  if (pageWidth <= 0 || surfaceHeight <= 0) {
    return [1, 1];
  }
  if (mode === 2) {
    return [1, pageHeight / surfaceHeight];
  }
  if (mode === 3) {
    return [1, (pageWidth * 9 / 16) / surfaceHeight];
  }
  if (mode === 4) {
    return [1, (pageWidth * 3 / 4) / surfaceHeight];
  }
  if (mode === 5 && videoWidthVp > 0) {
    const k: number = videoWidthVp / pageWidth;
    return [k, k];
  }
  return [1, 1];
}

/** The rows of a track section; the subtitles start with Disable (id -1). */
export function buildTrackItems(ctx: common.Context, list: vlcnative.VlcTrackDescription[],
  withDisable: boolean): TrackItem[] {
  const out: TrackItem[] = [];
  if (withDisable) {
    const off: TrackItem = new TrackItem();
    off.id = -1;
    off.label = ctx.resourceManager.getStringByNameSync('disable_track');
    out.push(off);
  }
  let n: number = 0;
  for (const t of list) {
    if (t.id < 0) {
      continue;
    }
    n++;
    const item: TrackItem = new TrackItem();
    item.id = t.id;
    const label: string = trackLabelParts(t.name);
    item.label = label.length > 0 ? label : ctx.resourceManager.getStringByNameSync('track_number', n);
    out.push(item);
  }
  return out;
}

/** The label of a track as VLC shows it: its title, else its language, else Track <n>. */
export function trackLabelParts(name: string): string {
  const generic: RegExpMatchArray | null = name.match(/^Track (\d+)(?: - \[(.+)\])?$/);
  if (generic !== null) {
    return generic[2] !== undefined ? generic[2] : '';
  }
  const cut: number = name.indexOf(' - [');
  return cut > 0 ? name.substring(0, cut) : name;
}
