import { uiObserver } from '@kit.ArkUI';
import type { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Media } from '../model/Media';
import { MediaStore } from '../model/MediaStore';
import { VideoImporter } from '../components/video/VideoImporter';
import { openPlayer } from '../components/player/OpenPlayer';
import { VideoRow } from '../components/video/VideoRow';
import { EmptyVideos } from '../components/video/EmptyVideos';

@ComponentV2
export struct VideoView {
  @Local videos: Media[] = [];
  @Local loaded: boolean = false;
  private pageCallback: (info: uiObserver.RouterPageInfo) => void = (info: uiObserver.RouterPageInfo) => {
    if (info.state === uiObserver.RouterPageState.ON_PAGE_SHOW) {
      this.reload();
    }
  };

  aboutToAppear(): void {
    this.reload();
    this.getUIContext().getUIObserver().on('routerPageUpdate', this.pageCallback);
  }

  aboutToDisappear(): void {
    this.getUIContext().getUIObserver().off('routerPageUpdate', this.pageCallback);
  }

  private async reload(): Promise<void> {
    try {
      this.videos = await MediaStore.getInstance().videos();
      this.loaded = true;
      await VideoImporter.activateStored(this.videos);
      if (await VideoImporter.redescribeMissing(this.context(), this.videos)) {
        this.videos = await MediaStore.getInstance().videos();
      }
    } catch (e) {
      hilog.error(0x0001, 'VlcVideo', 'load failed: %{public}s', JSON.stringify(e));
      this.toast($r('app.string.video_list_error'));
    }
  }

  private toast(message: Resource): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (e) {
      hilog.error(0x0001, 'VlcVideo', 'toast failed: %{public}s', JSON.stringify(e));
    }
  }

  private open(url: string, m: Media): void {
    this.getUIContext().getRouter().pushUrl({ url: url, params: { mediaId: m.id } }).catch((e: Error) => {
      hilog.error(0x0001, 'VlcVideo', 'push %{public}s failed: %{public}s', url, JSON.stringify(e));
    });
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private async pickAndAdd(): Promise<void> {
    const uris: string[] = await VideoImporter.pick(this.context());
    if (uris.length === 0) {
      return;
    }
    const failed: number = await VideoImporter.add(this.context(), uris);
    if (failed > 0) {
      this.toast($r('app.string.video_add_error'));
    }
    await this.reload();
  }

  private async play(m: Media): Promise<void> {
    if (m.isStream || await VideoImporter.canOpenActivated(m.uri)) {
      openPlayer(this.getUIContext().getRouter(), m.id);
    } else {
      this.pickAndAdd();
    }
  }

  private info(m: Media): void {
    this.open('pages/InfoPage', m);
  }

  private async remove(m: Media): Promise<void> {
    try {
      await MediaStore.getInstance().removeFromVideos(m.id);
    } catch (e) {
      hilog.error(0x0001, 'VlcVideo', 'remove failed: %{public}s', JSON.stringify(e));
      this.toast($r('app.string.video_remove_error'));
    }
    await this.reload();
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        Row() {
          Text($r('app.string.EntryAbility_label'))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.title_bar_text'))
        }
        .width('100%')
        .height($r('app.float.title_bar_height'))
        .padding({ left: 16, right: 16 })
        .backgroundColor($r('app.color.title_bar_background'))

        if (this.loaded && this.videos.length === 0) {
          EmptyVideos({
            onPick: () => {
              this.pickAndAdd();
            }
          })
        } else {
          List() {
            ForEach(this.videos, (m: Media, i: number) => {
              ListItem() {
                VideoRow({
                  index: i,
                  title: m.title,
                  length: m.length,
                  videoWidth: m.width,
                  videoHeight: m.height,
                  thumbnail: m.thumbnail,
                  lastPosition: m.lastPosition,
                  onPlay: () => {
                    this.play(m);
                  },
                  onInfo: () => {
                    this.info(m);
                  },
                  onRemove: () => {
                    this.remove(m);
                  }
                })
              }
            }, (m: Media, i: number) =>
              `${i}_${m.id}_${m.title}_${m.length}_${m.width}_${m.height}_${m.thumbnail}_${m.lastPosition}`)
          }
          .width('100%')
          .layoutWeight(1)
          .padding({ bottom: 88 })
        }
      }
      .width('100%')
      .height('100%')

      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.plus'))
          .fontSize(28)
          .fontColor([$r('app.color.player_text')])
      }
      .id('fab')
      .width(56)
      .height(56)
      .backgroundColor($r('app.color.vlc_orange'))
      .margin({ right: 16, bottom: 16 })
      .accessibilityText($r('app.string.add'))
      .onClick(() => {
        this.pickAndAdd();
      })
    }
    .id('video_browser')
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
