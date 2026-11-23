import { router } from '@kit.ArkUI';
import type { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { media } from '@kit.MediaKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import vlcnative from 'libvlcnative.so';
import { InfoTitleBar } from '../components/info/InfoTitleBar';
import { InfoRow } from '../components/info/InfoRow';
import { isUsableCover } from '../components/info/CoverCheck';
import { TrackGroup } from '../components/info/InfoTypes';
import { factsFromPlatform, factsFromVlc, MediaFacts } from '../components/info/TrackBuilder';
import { TrackGroupView } from '../components/info/TrackGroupView';
import { FormatStore } from '../model/FormatStore';
import { Media } from '../model/Media';
import { MediaStore } from '../model/MediaStore';
import { vlcService } from '../services/VlcService';

@Entry
@ComponentV2
struct InfoPage {
  @Local mediaTitle: string = '';
  @Local lengthText: string = '';
  @Local sizeText: string = '';
  @Local isStream: boolean = false;
  @Local location: string = '';
  @Local resolution: string = '';
  @Local thumbnail: string = '';
  @Local groups: TrackGroup[] = [];
  @Local parsed: boolean = false;
  private fmt: FormatStore = FormatStore.getInstance();
  private durationMs: number = 0;
  private videoWidth: number = 0;
  private videoHeight: number = 0;
  private vlcLength: boolean = false;
  private vlcSize: boolean = false;
  private vlcTracks: boolean = false;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object> | undefined;
    const raw: Object | undefined = params === undefined ? undefined : params['mediaId'];
    const id: number = raw === undefined ? 0 : Number(raw);
    this.load(id).catch((e: Error) => {
      hilog.error(0x0001, 'VlcInfo', 'load failed: %{public}s', JSON.stringify(e));
    });
  }

  private resolutionText(width: number, height: number): string {
    return width > 0 && height > 0 ? `${width}x${height}` : '';
  }

  private fileName(uri: string): string {
    const clean: string = uri.split('?')[0];
    const last: string = clean.substring(clean.lastIndexOf('/') + 1);
    try {
      return decodeURIComponent(last);
    } catch (e) {
      return last;
    }
  }

  private trackLabel(n: number): string {
    try {
      const ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      return ctx.resourceManager.getStringByNameSync('track_number', n);
    } catch (e) {
      hilog.warn(0x0001, 'VlcInfo', 'track label failed: %{public}s', JSON.stringify(e));
      return `${n}`;
    }
  }

  /** Shows what one source knows; libVLC's parse wins over the platform's extractor. */
  private applyFacts(f: MediaFacts, fromVlc: boolean): void {
    if (f.durationMs > 0 && (fromVlc || !this.vlcLength)) {
      this.durationMs = f.durationMs;
      this.lengthText = this.fmt.formatTime(f.durationMs);
      this.vlcLength = this.vlcLength || fromVlc;
    }
    if (f.width > 0 && f.height > 0 && (fromVlc || !this.vlcSize)) {
      this.videoWidth = f.width;
      this.videoHeight = f.height;
      this.resolution = this.resolutionText(f.width, f.height);
      this.vlcSize = this.vlcSize || fromVlc;
    }
    if (f.groups.length > 0 && (fromVlc || !this.vlcTracks)) {
      this.groups = f.groups;
      this.vlcTracks = this.vlcTracks || fromVlc;
    }
  }

  private async describeWithVlc(source: string | number): Promise<void> {
    try {
      const info: vlcnative.VlcMediaInfo = await vlcService.describe(source);
      hilog.info(0x0001, 'VlcInfo', 'vlc parse status %{public}d duration %{public}d tracks %{public}d',
        info.status, info.durationMs, info.tracks === undefined ? -1 : info.tracks.length);
      this.applyFacts(factsFromVlc(info, (n: number) => this.trackLabel(n)), true);
    } catch (e) {
      hilog.warn(0x0001, 'VlcInfo', 'vlc describe failed: %{public}s', JSON.stringify(e));
    }
  }

  private async describeWithPlatform(fd: number, size: number): Promise<void> {
    let extractor: media.AVMetadataExtractor | undefined = undefined;
    try {
      extractor = await media.createAVMetadataExtractor();
      extractor.fdSrc = { fd: fd, offset: 0, length: size };
      const meta: media.AVMetadata = await extractor.fetchMetadata();
      const f: MediaFacts = factsFromPlatform(meta, (n: number) => this.trackLabel(n));
      hilog.info(0x0001, 'VlcInfo', 'platform metadata duration %{public}d size %{public}dx%{public}d tracks %{public}d',
        f.durationMs, f.width, f.height, f.groups.length);
      this.applyFacts(f, false);
    } catch (e) {
      hilog.warn(0x0001, 'VlcInfo', 'platform metadata failed: %{public}s', JSON.stringify(e));
    } finally {
      if (extractor !== undefined) {
        try {
          await extractor.release();
        } catch (e) {
          hilog.warn(0x0001, 'VlcInfo', 'extractor release failed: %{public}s', JSON.stringify(e));
        }
      }
    }
  }

  /** Shows the stored frame only when it is a real picture; the cone stays otherwise. */
  private async checkCover(stored: string): Promise<void> {
    if (await isUsableCover(stored)) {
      this.thumbnail = stored.startsWith('/') ? `file://${stored}` : stored;
    }
  }

  /** Writes back what the store lacked, so the Video list shows it too. */
  private async remember(m: Media, size: number): Promise<void> {
    const needLength: boolean = m.length <= 0 && this.durationMs > 0;
    const needSize: boolean = (m.width <= 0 || m.height <= 0) && this.videoWidth > 0;
    if (!needLength && !needSize && !(m.size <= 0 && size > 0)) {
      return;
    }
    try {
      await MediaStore.getInstance().describe(m.id, '', this.durationMs > 0 ? this.durationMs : m.length,
        this.videoWidth > 0 ? this.videoWidth : m.width, this.videoHeight > 0 ? this.videoHeight : m.height,
        size > 0 ? size : m.size);
    } catch (e) {
      hilog.warn(0x0001, 'VlcInfo', 'store update failed: %{public}s', JSON.stringify(e));
    }
  }

  private async load(id: number): Promise<void> {
    const media: Media | null = await MediaStore.getInstance().get(id);
    this.vlcLength = false;
    this.vlcSize = false;
    this.vlcTracks = false;
    if (media === null) {
      this.parsed = true;
      return;
    }
    const stored: string = media.title;
    this.mediaTitle = stored.length > 0 && !stored.startsWith('fd://') ? stored :
      (media.isStream ? media.uri : this.fileName(media.uri));
    this.isStream = media.isStream;
    this.location = media.isStream ? media.uri : this.fileName(media.uri);
    this.lengthText = media.length > 0 ? this.fmt.formatTime(media.length) : '';
    this.sizeText = media.size > 0 ? this.fmt.formatSize(media.size) : '';
    this.resolution = this.resolutionText(media.width, media.height);
    this.thumbnail = '';
    this.checkCover(media.thumbnail).catch((e: Error) => {
      hilog.warn(0x0001, 'VlcInfo', 'cover failed: %{public}s', JSON.stringify(e));
    });
    if (media.length > 0) {
      this.durationMs = media.length;
    }
    if (media.width > 0 && media.height > 0) {
      this.videoWidth = media.width;
      this.videoHeight = media.height;
    }
    let file: fs.File | undefined = undefined;
    try {
      if (media.isStream) {
        await this.describeWithVlc(media.uri);
      } else {
        file = fs.openSync(media.uri, fs.OpenMode.READ_ONLY);
        const fd: number = file.fd;
        const size: number = fs.statSync(fd).size;
        if (size > 0 && media.size <= 0) {
          this.sizeText = this.fmt.formatSize(size);
        }
        await Promise.all([this.describeWithVlc(fd), this.describeWithPlatform(fd, size)]);
        await this.remember(media, size);
      }
    } catch (e) {
      hilog.warn(0x0001, 'VlcInfo', 'describe failed: %{public}s', JSON.stringify(e));
    } finally {
      if (file !== undefined) {
        try {
          fs.closeSync(file);
        } catch (e) {
          hilog.warn(0x0001, 'VlcInfo', 'close failed: %{public}s', JSON.stringify(e));
        }
      }
      this.parsed = true;
    }
  }

  build() {
    Column() {
      InfoTitleBar({ title: this.mediaTitle })
      Scroll() {
        Column() {
          Row() {
            if (this.thumbnail.length > 0) {
              Image(this.thumbnail)
                .id('playlist_cover')
                .width(120)
                .height(68)
                .objectFit(ImageFit.Cover)
                .borderRadius(4)
                .onError(() => {
                  this.thumbnail = '';
                })
            } else {
              Image($r('app.media.app_icon'))
                .id('playlist_cover')
                .width(120)
                .height(68)
                .objectFit(ImageFit.Contain)
            }
            Column() {
              Text(this.mediaTitle)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(this.resolution)
                .id('ml_item_resolution')
                .constraintSize({ minHeight: 24, minWidth: 96 })
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
                .margin({ top: 4 })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            .margin({ left: 16 })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          InfoRow({ label: $r('app.string.length'), value: this.lengthText,
            labelId: 'length_title', valueId: 'length_value' })
          if (!this.isStream) {
            InfoRow({ label: $r('app.string.file_size'), value: this.sizeText,
              labelId: 'size_title', valueId: 'size_value' })
          }
          InfoRow({ label: $r('app.string.location'), value: this.location,
            labelId: 'extra_title', valueId: 'extra_value' })
          Column() {
            if (this.groups.length > 0) {
              ForEach(this.groups, (g: TrackGroup, index: number) => {
                TrackGroupView({ kind: g.kind, label: g.label, lines: g.lines })
              }, (g: TrackGroup, index: number) => `${index}_${g.kind}_${g.label}`)
            } else if (this.parsed) {
              Text($r('app.string.no_track'))
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
                .padding({ left: 16, top: 12 })
            }
          }
          .id('list')
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Start)
      }
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
