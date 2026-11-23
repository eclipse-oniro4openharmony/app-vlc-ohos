import { fileIo as fs, fileShare } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import type { common } from '@kit.AbilityKit';
import { Media } from '../../model/Media';
import { MediaStore } from '../../model/MediaStore';
import { vlcService } from '../../services/VlcService';

/** The media one player page plays: found from the router params, loaded into the engine, released at the end. */
export class PlayerSession {
  mediaId: number = -1;
  private file: fs.File | undefined = undefined;

  private closed: boolean = false;

  /** Finds the media ({ mediaId }) and loads it into the player; null when unknown or closed meanwhile. */
  async open(ctx: common.Context, params: Record<string, Object> | undefined): Promise<Media | null> {
    let media: Media | null = null;
    if (params !== undefined && params !== null) {
      const id: Object | undefined = params['mediaId'];
      if (typeof id === 'number') {
        media = await MediaStore.getInstance().get(id);
      }
    }
    if (media === null || this.closed) {
      return null;
    }
    this.mediaId = media.id;
    if (media.isStream) {
      vlcService.loadLocation(media.uri);
      return media;
    }
    const file: fs.File = await this.openFile(media.uri);
    if (this.closed) {
      // The page was left while the file was being opened: no player is created for it.
      fs.closeSync(file);
      return null;
    }
    this.file = file;
    vlcService.loadMediaFd(file.fd);
    return media;
  }

  /** Opens a picked file; after a restart its persisted grant is activated first when the plain open fails. */
  private async openFile(uri: string): Promise<fs.File> {
    try {
      return fs.openSync(uri, fs.OpenMode.READ_ONLY);
    } catch (e) {
      hilog.warn(0x0001, 'PlayerSession', 'open failed, activating the grant: %{public}s', JSON.stringify(e));
    }
    if (canIUse('SystemCapability.FileManagement.AppFileService.FolderAuthorization')) {
      try {
        const policy: fileShare.PolicyInfo = { uri: uri, operationMode: fileShare.OperationMode.READ_MODE };
        await fileShare.activatePermission([policy]);
      } catch (e) {
        hilog.warn(0x0001, 'PlayerSession', 'activatePermission failed: %{public}s', JSON.stringify(e));
      }
    }
    return fs.openSync(uri, fs.OpenMode.READ_ONLY);
  }

  /** The stored title, or the file name when the engine left an mrl such as fd://46 in it. */
  displayTitle(media: Media): string {
    if (media.title.indexOf('://') < 0) {
      return media.title;
    }
    return MediaStore.getInstance().titleFromUri(media.uri);
  }

  /** Tears the player down (mediaPlayerCleanup) and closes the file; runs once. */
  close(): void {
    if (this.closed) {
      return;
    }
    this.closed = true;
    vlcService.destroy();
    if (this.file !== undefined) {
      try {
        fs.closeSync(this.file);
      } catch (e) {
        hilog.warn(0x0001, 'PlayerSession', 'close failed: %{public}s', JSON.stringify(e));
      }
      this.file = undefined;
    }
  }
}
