import { fileIo as fs, fileShare, picker } from '@kit.CoreFileKit';
import { media } from '@kit.MediaKit';
import { image } from '@kit.ImageKit';
import type { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Media } from '../../model/Media';
import { MediaStore } from '../../model/MediaStore';
import { vlcService } from '../../services/VlcService';

interface ParsedTrack {
  type: string;
  width: number;
  height: number;
}

interface ParsedInfo {
  status: number;
  durationMs: number;
  title: string;
  tracks: ParsedTrack[];
}

interface PlatformInfo {
  length: number;
  width: number;
  height: number;
}

const TAG: string = 'VlcVideoImport';
const THUMB_AT_US: number = 3000000;
const PARSE_TIMEOUT_MS: number = 12000;

export class VideoImporter {
  /** Opens the system document picker for videos; resolves with the picked uris (empty when cancelled). */
  static async pick(context: common.UIAbilityContext): Promise<string[]> {
    try {
      const options: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 50;
      options.fileSuffixFilters = ['.mp4', '.mkv', '.avi', '.ts', '.flv', '.mov', '.webm'];
      const viewPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
      const uris: string[] = await viewPicker.select(options);
      return uris === undefined ? [] : uris;
    } catch (e) {
      hilog.error(0x0001, TAG, 'picker failed: %{public}s', JSON.stringify(e));
      return [];
    }
  }

  /** True when the stored uri still opens for reading. */
  static canOpen(uri: string): boolean {
    try {
      const file: fs.File = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      fs.closeSync(file);
      return true;
    } catch (e) {
      hilog.warn(0x0001, TAG, 'open failed: %{public}s', JSON.stringify(e));
      return false;
    }
  }

  /** True when the uri opens, activating its persisted grant first when the plain open fails (after a restart). */
  static async canOpenActivated(uri: string): Promise<boolean> {
    if (VideoImporter.canOpen(uri)) {
      return true;
    }
    await VideoImporter.activate([uri]);
    return VideoImporter.canOpen(uri);
  }

  /** Once per app start: activates the persisted read grants of the stored files, so they open without the picker. */
  static async activateStored(rows: Media[]): Promise<void> {
    if (VideoImporter.activated) {
      return;
    }
    VideoImporter.activated = true;
    const uris: string[] = [];
    for (const m of rows) {
      if (!m.isStream && m.uri.startsWith('file://')) {
        uris.push(m.uri);
      }
    }
    if (uris.length > 0) {
      await VideoImporter.activate(uris);
    }
  }

  private static activated: boolean = false;

  private static async activate(uris: string[]): Promise<void> {
    if (!canIUse('SystemCapability.FileManagement.AppFileService.FolderAuthorization')) {
      hilog.info(0x0001, TAG, 'activatePermission not available');
      return;
    }
    const policies: fileShare.PolicyInfo[] = [];
    for (const uri of uris) {
      const policy: fileShare.PolicyInfo = { uri: uri, operationMode: fileShare.OperationMode.READ_MODE };
      policies.push(policy);
    }
    try {
      await fileShare.activatePermission(policies);
      hilog.info(0x0001, TAG, 'activatePermission ok for %{public}d uris', policies.length);
    } catch (e) {
      // Code 201 means ohos.permission.FILE_ACCESS_PERSIST is not granted; 13900001 lists the uris not persisted.
      hilog.warn(0x0001, TAG, 'activatePermission failed: %{public}s', JSON.stringify(e));
    }
  }

  /** Adds each uri to the store, persists its permission, then describes it and makes its thumbnail. */
  static async add(context: common.UIAbilityContext, uris: string[]): Promise<number> {
    const store: MediaStore = MediaStore.getInstance();
    let failed: number = 0;
    for (const uri of uris) {
      let m: Media;
      try {
        await VideoImporter.persist(uri);
        m = await store.addFile(uri);
      } catch (e) {
        hilog.error(0x0001, TAG, 'add failed: %{public}s', JSON.stringify(e));
        failed++;
        continue;
      }
      await VideoImporter.describe(context, m);
    }
    return failed;
  }

  /** Once per app start: describes again the rows whose length is unknown, so they fill when the engine recovers. */
  static async redescribeMissing(context: common.UIAbilityContext, rows: Media[]): Promise<boolean> {
    if (VideoImporter.redescribed) {
      return false;
    }
    VideoImporter.redescribed = true;
    let changed: boolean = false;
    for (const m of rows) {
      if ((m.length <= 0 || m.width <= 0) && VideoImporter.canOpen(m.uri)) {
        await VideoImporter.describe(context, m);
        changed = true;
      }
    }
    return changed;
  }

  private static redescribed: boolean = false;

  private static async persist(uri: string): Promise<void> {
    if (!canIUse('SystemCapability.FileManagement.AppFileService.FolderAuthorization')) {
      hilog.info(0x0001, TAG, 'persistPermission not available');
      return;
    }
    try {
      const policy: fileShare.PolicyInfo = { uri: uri, operationMode: fileShare.OperationMode.READ_MODE };
      await fileShare.persistPermission([policy]);
      hilog.info(0x0001, TAG, 'persistPermission ok: %{private}s', uri);
    } catch (e) {
      hilog.warn(0x0001, TAG, 'persistPermission failed: %{public}s', JSON.stringify(e));
    }
  }

  private static async describe(context: common.UIAbilityContext, m: Media): Promise<void> {
    const store: MediaStore = MediaStore.getInstance();
    let file: fs.File | undefined = undefined;
    try {
      file = fs.openSync(m.uri, fs.OpenMode.READ_ONLY);
    } catch (e) {
      hilog.warn(0x0001, TAG, 'cannot open for describe: %{public}s', JSON.stringify(e));
      return;
    }
    try {
      const size: number = fs.statSync(file.fd).size;
      let length: number = 0;
      let width: number = 0;
      let height: number = 0;
      let title: string = '';
      try {
        const info: ParsedInfo | undefined = await VideoImporter.engineParse(file.fd);
        if (info !== undefined) {
          hilog.info(0x0001, TAG, 'engine parse: status %{public}d, %{public}d ms, %{public}d tracks',
            info.status, info.durationMs, info.tracks.length);
          length = info.durationMs > 0 ? info.durationMs : 0;
          title = info.title;
          for (const t of info.tracks) {
            if (t.type === 'video' && width === 0) {
              width = t.width;
              height = t.height;
            }
          }
        }
      } catch (e) {
        hilog.warn(0x0001, TAG, 'describe failed: %{public}s', JSON.stringify(e));
      }
      if (length <= 0 || width <= 0 || height <= 0) {
        // The engine could not describe the file: ask the platform's demuxer for what it knows.
        const meta: PlatformInfo = await VideoImporter.platformParse(file.fd, size);
        if (length <= 0) {
          length = meta.length;
        }
        if (width <= 0 || height <= 0) {
          width = meta.width;
          height = meta.height;
        }
      }
      await store.describe(m.id, title, length, width, height, size);
      const thumb: string = await VideoImporter.thumbnail(context, m.id, file.fd, size);
      if (thumb.length > 0) {
        await store.setThumbnail(m.id, thumb);
      }
    } catch (e) {
      hilog.error(0x0001, TAG, 'describe step failed: %{public}s', JSON.stringify(e));
    } finally {
      try {
        fs.closeSync(file);
      } catch (e) {
        hilog.warn(0x0001, TAG, 'close failed: %{public}s', JSON.stringify(e));
      }
    }
  }

  /** The engine's parse without playing, or undefined when it does not answer in time. */
  private static async engineParse(fd: number): Promise<ParsedInfo | undefined> {
    let timer: number = -1;
    const timeout: Promise<ParsedInfo | undefined> = new Promise<ParsedInfo | undefined>((resolve) => {
      timer = setTimeout(() => {
        hilog.warn(0x0001, TAG, 'engine parse timed out');
        resolve(undefined);
      }, PARSE_TIMEOUT_MS);
    });
    const parse: Promise<ParsedInfo | undefined> = vlcService.describe(fd).then((info) => info as ParsedInfo);
    try {
      return await Promise.race([parse, timeout]);
    } finally {
      clearTimeout(timer);
    }
  }

  private static toNumber(value: string | undefined): number {
    if (value === undefined || value.length === 0) {
      return 0;
    }
    const n: number = Number(value);
    return isNaN(n) || n < 0 ? 0 : Math.round(n);
  }

  /** Length and video size from the platform's AVMetadataExtractor; zeros when it cannot read the file. */
  private static async platformParse(fd: number, size: number): Promise<PlatformInfo> {
    const out: PlatformInfo = { length: 0, width: 0, height: 0 };
    let extractor: media.AVMetadataExtractor | undefined = undefined;
    try {
      extractor = await media.createAVMetadataExtractor();
      extractor.fdSrc = { fd: fd, offset: 0, length: size };
      const meta: media.AVMetadata = await extractor.fetchMetadata();
      out.length = VideoImporter.toNumber(meta.duration);
      out.width = VideoImporter.toNumber(meta.videoWidth);
      out.height = VideoImporter.toNumber(meta.videoHeight);
      hilog.info(0x0001, TAG, 'platform parse: %{public}d ms, %{public}dx%{public}d', out.length, out.width,
        out.height);
    } catch (e) {
      hilog.warn(0x0001, TAG, 'platform parse failed: %{public}s', JSON.stringify(e));
    } finally {
      if (extractor !== undefined) {
        try {
          await extractor.release();
        } catch (e) {
          hilog.warn(0x0001, TAG, 'extractor release failed: %{public}s', JSON.stringify(e));
        }
      }
    }
    return out;
  }

  private static async thumbnail(context: common.UIAbilityContext, id: number, fd: number,
    size: number): Promise<string> {
    let generator: media.AVImageGenerator | undefined = undefined;
    try {
      generator = await media.createAVImageGenerator();
      generator.fdSrc = { fd: fd, offset: 0, length: size };
      const param: media.PixelMapParams = { width: 320, height: 180 };
      const pixels: image.PixelMap =
        await generator.fetchFrameByTime(THUMB_AT_US, media.AVImageQueryOptions.AV_IMAGE_QUERY_CLOSEST_SYNC, param);
      const packer: image.ImagePacker = image.createImagePacker();
      const data: ArrayBuffer = await packer.packToData(pixels, { format: 'image/jpeg', quality: 80 });
      const dir: string = `${context.filesDir}/thumbs`;
      if (!fs.accessSync(dir)) {
        fs.mkdirSync(dir);
      }
      const path: string = `${dir}/${id}.jpg`;
      const out: fs.File = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      try {
        fs.writeSync(out.fd, data);
      } finally {
        fs.closeSync(out);
      }
      await pixels.release();
      await packer.release();
      return path;
    } catch (e) {
      hilog.warn(0x0001, TAG, 'thumbnail failed, the row shows the cone: %{public}s', JSON.stringify(e));
      return '';
    } finally {
      if (generator !== undefined) {
        try {
          await generator.release();
        } catch (e) {
          hilog.warn(0x0001, TAG, 'generator release failed: %{public}s', JSON.stringify(e));
        }
      }
    }
  }
}
