import { hilog } from '@kit.PerformanceAnalysisKit';
import { TitleBar } from '../components/common/TitleBar';
import { HistoryRow } from '../components/history/HistoryRow';
import { Media } from '../model/Media';
import { MediaStore } from '../model/MediaStore';
import { openPlayer } from '../components/player/OpenPlayer';

@Entry
@ComponentV2
struct HistoryPage {
  @Local items: Media[] = [];
  @Local loaded: boolean = false;

  onPageShow(): void {
    this.reload();
  }

  private reload(): void {
    MediaStore.getInstance().history().then((rows: Media[]) => {
      this.items = rows;
      this.loaded = true;
    }).catch((e: Error) => {
      hilog.error(0x0001, 'VlcHistory', 'load failed: %{public}s', JSON.stringify(e));
      this.loaded = true;
    });
  }

  private play(id: number): void {
    openPlayer(this.getUIContext().getRouter(), id);
  }

  private confirmClear(): void {
    this.getUIContext().showAlertDialog({
      title: $r('app.string.clear_playback_history'),
      message: $r('app.string.clear_history_message'),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: $r('app.string.cancel'),
        action: () => {
        }
      },
      secondaryButton: {
        value: $r('app.string.clear_history'),
        fontColor: $r('app.color.vlc_orange'),
        action: () => {
          MediaStore.getInstance().clearHistory().then(() => {
            this.reload();
          }).catch((e: Error) => {
            hilog.error(0x0001, 'VlcHistory', 'clear failed: %{public}s', JSON.stringify(e));
          });
        }
      }
    });
  }

  @Builder
  clearAction() {
    if (this.items.length > 0) {
      SymbolGlyph($r('sys.symbol.trash'))
        .fontSize($r('app.float.title_icon_size'))
        .fontColor([$r('app.color.title_bar_text')])
        .width($r('app.float.title_button_size'))
        .height($r('app.float.title_button_size'))
        .id('ml_menu_clean')
        .accessibilityText($r('app.string.clear_history'))
        .onClick(() => {
          this.confirmClear();
        })
    }
  }

  build() {
    Column() {
      TitleBar({ title: $r('app.string.history'), actions: () => { this.clearAction() } })
      if (this.items.length > 0) {
        List() {
          ForEach(this.items, (item: Media, index: number) => {
            ListItem() {
              HistoryRow({
                index: index,
                title: item.title,
                isStream: item.isStream,
                uri: item.uri,
                length: item.length,
                thumbnail: item.thumbnail,
                onPlay: () => {
                  this.play(item.id);
                }
              })
            }
          }, (item: Media, index: number) =>
            `${item.id}_${item.title}_${item.length}_${item.thumbnail}_${item.lastPlayed}_${index}`)
        }
        .id('history_list')
        .layoutWeight(1)
        .width('100%')
      } else {
        Column() {
          Text($r('app.string.nohistory'))
            .id('empty')
            .constraintSize({ minHeight: 24 })
            .fontSize(16)
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Center)
        }
        .id('history_list')
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ left: 24, right: 24 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
