import { media } from '@kit.MediaKit';
import vlcnative from 'libvlcnative.so';
import { InfoLine, makeLine, TrackGroup } from './InfoTypes';

/** What one source (libVLC's parse or the platform's extractor) knows of a media. */
export class MediaFacts {
  durationMs: number = 0;
  width: number = 0;
  height: number = 0;
  groups: TrackGroup[] = [];
}

/** Gives the label of a track without title or language: 'Track <n>'. */
export type TrackNumberLabel = (n: number) => string;

function resolutionOf(width: number, height: number): string {
  return width > 0 && height > 0 ? `${width}x${height}` : '';
}

function group(kind: number, label: string, lines: InfoLine[]): TrackGroup {
  const g: TrackGroup = new TrackGroup();
  g.kind = kind;
  g.label = label;
  g.lines = lines.filter((l: InfoLine) => l.value.length > 0);
  return g;
}

function videoLines(codec: string, width: number, height: number, fps: number): InfoLine[] {
  return [
    makeLine($r('app.string.codec'), codec),
    makeLine($r('app.string.resolution'), resolutionOf(width, height)),
    makeLine($r('app.string.framerate'), fps > 0 ? fps.toFixed(2) : '')
  ];
}

function audioLines(codec: string, channels: number, rate: number, language: string): InfoLine[] {
  return [
    makeLine($r('app.string.codec'), codec),
    makeLine($r('app.string.channels'), channels > 0 ? `${channels}` : ''),
    makeLine($r('app.string.sample_rate'), rate > 0 ? `${rate} Hz` : ''),
    makeLine($r('app.string.language'), language)
  ];
}

function textLines(codec: string, language: string): InfoLine[] {
  return [makeLine($r('app.string.codec'), codec), makeLine($r('app.string.language'), language)];
}

/** Language codes that name no language (ISO 639-2 'und', 'mis', 'zxx', 'mul'). */
const NO_LANGUAGE: string[] = ['und', 'mis', 'zxx', 'mul', 'undefined', 'unknown'];

/** The language as the media gives it, or '' when it names no language. */
function cleanLanguage(language: string): string {
  const l: string = language.trim();
  return NO_LANGUAGE.indexOf(l.toLowerCase()) >= 0 ? '' : l;
}

/**
 * The label beside a group's kind: the track's title, else its language, else nothing
 * (the heading is then the kind alone, e.g. 'Video track').
 */
function labelOf(title: string, language: string, n: number, fallback: TrackNumberLabel): string {
  const t: string = title.trim();
  if (t.length > 0 && NO_LANGUAGE.indexOf(t.toLowerCase()) < 0) {
    return t;
  }
  return language;
}

/** The facts of libVLC's parse (VlcService.describe). */
export function factsFromVlc(info: vlcnative.VlcMediaInfo, fallback: TrackNumberLabel): MediaFacts {
  const f: MediaFacts = new MediaFacts();
  f.durationMs = info.durationMs > 0 ? info.durationMs : 0;
  const tracks: vlcnative.VlcMediaTrack[] = info.tracks === undefined ? [] : info.tracks;
  const counts: number[] = [0, 0, 0];
  for (let i = 0; i < tracks.length; i++) {
    const t: vlcnative.VlcMediaTrack = tracks[i];
    const desc: string = t.description ?? '';
    const lang: string = cleanLanguage(t.language ?? '');
    const codec: string = t.codec ?? '';
    if (t.type === 'video') {
      counts[0]++;
      const fps: number = t.frameRateDen > 0 ? t.frameRateNum / t.frameRateDen : 0;
      f.groups.push(group(0, labelOf(desc, lang, counts[0], fallback),
        videoLines(codec, t.width, t.height, fps)));
      if (f.width === 0 && t.width > 0 && t.height > 0) {
        f.width = t.width;
        f.height = t.height;
      }
    } else if (t.type === 'audio') {
      counts[1]++;
      f.groups.push(group(1, labelOf(desc, lang, counts[1], fallback),
        audioLines(codec, t.channels, t.rate, lang)));
    } else {
      counts[2]++;
      f.groups.push(group(2, labelOf(desc, lang, counts[2], fallback), textLines(codec, lang)));
    }
  }
  return f;
}

function num(d: media.MediaDescription, key: string): number {
  const v: Object | undefined = d[key];
  if (v === undefined || v === null) {
    return 0;
  }
  const n: number = Number(v);
  return Number.isFinite(n) ? n : 0;
}

function str(d: media.MediaDescription, key: string): string {
  const v: Object | undefined = d[key];
  return v === undefined || v === null ? '' : String(v);
}

/** The facts of the platform's AVMetadataExtractor, used where libVLC's parse gave nothing. */
export function factsFromPlatform(meta: media.AVMetadata, fallback: TrackNumberLabel): MediaFacts {
  const f: MediaFacts = new MediaFacts();
  const d: number = Number(meta.duration ?? '0');
  f.durationMs = Number.isFinite(d) && d > 0 ? d : 0;
  const w: number = Number(meta.videoWidth ?? '0');
  const h: number = Number(meta.videoHeight ?? '0');
  if (Number.isFinite(w) && Number.isFinite(h) && w > 0 && h > 0) {
    f.width = w;
    f.height = h;
  }
  const tracks: media.MediaDescription[] = meta.tracks ?? [];
  const counts: number[] = [0, 0, 0];
  for (const t of tracks) {
    const type: number = num(t, 'track_type');
    const name: string = str(t, 'track_name');
    const lang: string = cleanLanguage(str(t, 'language'));
    const codec: string = str(t, 'codec_mime');
    if (type === media.MediaType.MEDIA_TYPE_VID) {
      counts[0]++;
      const tw: number = num(t, 'width');
      const th: number = num(t, 'height');
      let fps: number = num(t, 'frame_rate');
      if (fps > 240) {
        fps = fps / 100;
      }
      f.groups.push(group(0, labelOf(name, lang, counts[0], fallback), videoLines(codec, tw, th, fps)));
      if (f.width === 0 && tw > 0 && th > 0) {
        f.width = tw;
        f.height = th;
      }
    } else if (type === media.MediaType.MEDIA_TYPE_AUD) {
      counts[1]++;
      f.groups.push(group(1, labelOf(name, lang, counts[1], fallback),
        audioLines(codec, num(t, 'channel_count'), num(t, 'sample_rate'), lang)));
    } else if (type === media.MediaType.MEDIA_TYPE_SUBTITLE) {
      counts[2]++;
      f.groups.push(group(2, labelOf(name, lang, counts[2], fallback), textLines(codec, lang)));
    }
  }
  return f;
}
