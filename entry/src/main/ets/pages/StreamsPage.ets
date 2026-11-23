import { window } from '@kit.ArkUI';
import type { common } from '@kit.AbilityKit';
import { pasteboard, BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { TitleBar } from '../components/common/TitleBar';
import { StreamRow } from '../components/streams/StreamRow';
import { Media } from '../model/Media';
import { MediaStore } from '../model/MediaStore';

const TAG: string = 'VlcStreams';
/** How long to wait at most for the keyboard to close before opening the player. */
const KEYBOARD_WAIT_MS: number = 1200;
/** Poll step while waiting for the keyboard, and the settle time after it has gone. */
const KEYBOARD_POLL_MS: number = 100;
const KEYBOARD_SETTLE_MS: number = 250;

@Entry
@ComponentV2
struct StreamsPage {
  @Local address: string = '';
  @Local streams: Media[] = [];

  private busy: boolean = false;
  private editing: boolean = false;
  private keyboardHeight: number = 0;
  private win: window.Window | undefined = undefined;
  private keyboardListener: (height: number) => void = (height: number) => {
    this.keyboardHeight = height;
  };
  private inputController: TextAreaController = new TextAreaController();
  private pendingId: number = -1;
  private pendingOpened: number = 0;
  private pushTimer: number = -1;

  aboutToAppear(): void {
    const ctx: common.Context = this.getUIContext().getHostContext() as common.Context;
    window.getLastWindow(ctx).then((w: window.Window) => {
      this.win = w;
      w.on('keyboardHeightChange', this.keyboardListener);
    }).catch((e: BusinessError) => {
      hilog.warn(0x0001, TAG, 'window not found: %{public}s', JSON.stringify(e));
    });
  }

  aboutToDisappear(): void {
    if (this.pushTimer >= 0) {
      clearTimeout(this.pushTimer);
      this.pushTimer = -1;
    }
    if (this.win !== undefined) {
      try {
        this.win.off('keyboardHeightChange', this.keyboardListener);
      } catch (e) {
        hilog.warn(0x0001, TAG, 'keyboard listener off failed: %{public}s', JSON.stringify(e));
      }
      this.win = undefined;
    }
  }

  onPageShow(): void {
    this.busy = false;
    this.reload();
  }

  /** A stream that was new when played stays remembered only if the player recorded it as opened. */
  private async forgetUnplayed(): Promise<void> {
    const id: number = this.pendingId;
    this.pendingId = -1;
    if (id < 0) {
      return;
    }
    const store: MediaStore = MediaStore.getInstance();
    const m: Media | null = await store.get(id);
    if (m !== null && m.lastOpened === this.pendingOpened) {
      hilog.warn(0x0001, TAG, 'stream %{public}d was not opened by the player; forgotten', id);
      await store.removeStream(id);
    } else {
      hilog.info(0x0001, TAG, 'stream %{public}d was played; remembered', id);
    }
  }

  private reload(): void {
    this.forgetUnplayed().then(() => {
      return MediaStore.getInstance().streams();
    }).then((list: Media[]) => {
      this.streams = list;
    }).catch((e: Error) => {
      hilog.error(0x0001, TAG, 'load failed: %{public}s', JSON.stringify(e));
    });
  }

  private keyboardShown(): boolean {
    return this.editing || this.keyboardHeight > 0;
  }

  private hideKeyboard(): void {
    try {
      this.inputController.stopEditing();
      this.getUIContext().getFocusController().clearFocus();
    } catch (e) {
      hilog.warn(0x0001, TAG, 'hide keyboard failed: %{public}s', JSON.stringify(e));
    }
  }

  /**
   * Opens the player only once the keyboard is gone: pushed while the input method is
   * still closing, the player's surface is laid out under a resizing window.
   */
  private openWhenKeyboardGone(id: number, waited: number): void {
    if (this.keyboardShown() && waited < KEYBOARD_WAIT_MS) {
      this.pushTimer = setTimeout(() => {
        this.openWhenKeyboardGone(id, waited + KEYBOARD_POLL_MS);
      }, KEYBOARD_POLL_MS);
      return;
    }
    hilog.info(0x0001, TAG, 'keyboard gone after %{public}d ms (height %{public}d)', waited, this.keyboardHeight);
    this.pushTimer = setTimeout(() => {
      this.pushTimer = -1;
      this.openPlayer(id);
    }, waited > 0 ? KEYBOARD_SETTLE_MS : 0);
  }

  private openPlayer(id: number): void {
    hilog.info(0x0001, TAG, 'pushUrl pages/PlayerPage mediaId=%{public}d', id);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/PlayerPage', params: { mediaId: id } }).then(() => {
      hilog.info(0x0001, TAG, 'pushUrl done mediaId=%{public}d', id);
    }).catch((e: BusinessError) => {
      this.busy = false;
      this.pendingId = -1;
      hilog.error(0x0001, TAG, 'pushUrl failed: %{public}s', JSON.stringify(e));
    });
  }

  private play(uri: string): void {
    const text: string = uri.replace(/[\r\n]/g, '').trim();
    hilog.info(0x0001, TAG, 'play address="%{private}s" busy=%{public}s keyboard=%{public}s', text,
      `${this.busy}`, `${this.keyboardShown()}`);
    if (this.busy || text.length === 0 || text.indexOf('://') < 0) {
      return;
    }
    this.busy = true;
    this.hideKeyboard();
    const store: MediaStore = MediaStore.getInstance();
    store.findByUri(text).then((known: Media | null) => {
      const wasRemembered: boolean = known !== null && known.inStreams;
      return store.addStream(text).then((m: Media) => {
        this.pendingId = wasRemembered ? -1 : m.id;
        this.pendingOpened = m.lastOpened;
        this.openWhenKeyboardGone(m.id, 0);
      });
    }).catch((e: Error) => {
      this.busy = false;
      hilog.error(0x0001, TAG, 'addStream failed: %{public}s', JSON.stringify(e));
    });
  }

  private copy(uri: string): void {
    try {
      const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, uri);
      pasteboard.getSystemPasteboard().setData(data).catch((e: Error) => {
        hilog.error(0x0001, TAG, 'copy failed: %{public}s', JSON.stringify(e));
      });
    } catch (e) {
      hilog.error(0x0001, TAG, 'copy failed: %{public}s', JSON.stringify(e));
    }
  }

  private remove(id: number): void {
    MediaStore.getInstance().removeStream(id).then(() => {
      this.reload();
    }).catch((e: Error) => {
      hilog.error(0x0001, TAG, 'remove failed: %{public}s', JSON.stringify(e));
    });
  }

  build() {
    Column() {
      TitleBar({ title: $r('app.string.streams') })
      Row() {
        TextArea({
          placeholder: $r('app.string.open_mrl_dialog_msg'),
          text: this.address,
          controller: this.inputController
        })
          .id('mrl_edit')
          .layoutWeight(1)
          .constraintSize({ minHeight: 48 })
          .placeholderFont({ size: $r('app.float.page_text_font_size') })
          .fontSize($r('app.float.page_text_font_size'))
          .enterKeyType(EnterKeyType.Go)
          .onEditChange((isEditing: boolean) => {
            this.editing = isEditing;
          })
          .onChange((value: string) => {
            if (value.indexOf('\n') >= 0) {
              // An input method that types Enter as a line break: take it as Go.
              this.address = value.replace(/[\r\n]/g, '');
              this.play(this.address);
              return;
            }
            this.address = value;
          })
          .onSubmit(() => {
            this.play(this.address);
          })
        Button() {
          SymbolGlyph($r('sys.symbol.play_fill'))
            .fontSize(28)
            .fontColor([$r('app.color.card_background')])
        }
        .id('play')
        .type(ButtonType.Circle)
        .width(48)
        .height(48)
        .margin({ left: 8 })
        .backgroundColor($r('app.color.vlc_orange'))
        .accessibilityText($r('app.string.play'))
        .onClick(() => {
          this.play(this.address);
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .alignItems(VerticalAlign.Center)

      List() {
        ForEach(this.streams, (m: Media, i: number) => {
          ListItem() {
            StreamRow({
              index: i,
              title: m.title,
              uri: m.uri,
              onPlay: () => {
                this.play(m.uri);
              },
              onCopy: () => {
                this.copy(m.uri);
              },
              onDelete: () => {
                this.remove(m.id);
              }
            })
          }
        }, (m: Media, i: number) => `${m.id}_${m.title}_${m.uri}_${i}`)
      }
      .id('mrl_list')
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
