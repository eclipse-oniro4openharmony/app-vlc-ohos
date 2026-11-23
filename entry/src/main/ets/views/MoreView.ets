import { hilog } from '@kit.PerformanceAnalysisKit';
import { Media } from '../model/Media';
import { MediaStore } from '../model/MediaStore';
import { FormatStore } from '../model/FormatStore';
import { openPlayer } from '../components/player/OpenPlayer';

const MAX_HISTORY: number = 10;
const MAX_STREAMS: number = 10;

@ComponentV2
export struct MoreView {
  @Local streams: Media[] = [];
  @Local history: Media[] = [];

  aboutToAppear(): void {
    this.reload();
  }

  private async reload(): Promise<void> {
    try {
      const store: MediaStore = MediaStore.getInstance();
      const s: Media[] = await store.streams();
      const h: Media[] = await store.history();
      this.streams = s.slice(0, MAX_STREAMS);
      this.history = h.slice(0, MAX_HISTORY);
    } catch (e) {
      hilog.error(0x0001, 'VlcMore', 'load failed: %{public}s', JSON.stringify(e));    }
  }

  private open(url: string): void {
    this.getUIContext().getRouter().pushUrl({ url: url }).catch((e: Error) => {
      hilog.error(0x0001, 'VlcMore', 'push %{public}s failed: %{public}s', url, JSON.stringify(e));
    });
  }

  private play(id: number): void {
    openPlayer(this.getUIContext().getRouter(), id);
  }

  private subtitle(m: Media): string {
    return m.isStream ? m.uri : FormatStore.getInstance().formatTime(m.length);
  }

  @Builder
  header(label: Resource, eid: string) {
    Row() {
      Text(label)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.vlc_orange'))
        .layoutWeight(1)
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(22)
        .fontColor([$r('app.color.text_secondary')])
    }
    .id(eid)
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.open(eid === 'streams_entry' ? 'pages/StreamsPage' : 'pages/HistoryPage');
    })
  }

  @Builder
  navRow(icon: Resource, label: Resource, eid: string, url: string) {
    Row({ space: 16 }) {
      SymbolGlyph(icon)
        .fontSize(24)
        .fontColor([$r('app.color.text_secondary')])
      Text(label)
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(22)
        .fontColor([$r('app.color.text_secondary')])
    }
    .id(eid)
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.open(url);
    })
  }

  build() {
    Column() {
      Text($r('app.string.more'))
        .fontSize($r('app.float.title_font_size'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.title_bar_text'))
        .width('100%')
        .height($r('app.float.title_bar_height'))
        .padding({ left: 16, right: 16 })
        .backgroundColor($r('app.color.title_bar_background'))
      Scroll() {
      Column() {
        this.header($r('app.string.streams'), 'streams_entry')
        Scroll() {
          Row({ space: 8 }) {
            ForEach(this.streams, (m: Media) => {
              Column({ space: 4 }) {
                Text(m.title)
                  .id('mrl_item_title')
                  .fontSize(14)
                  .fontColor($r('app.color.text_primary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(m.uri)
                  .id('mrl_item_uri')
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .id('mrl_card_item')
              .alignItems(HorizontalAlign.Start)
              .justifyContent(FlexAlign.Center)
              .width(180)
              .height(64)
              .padding(12)
              .borderRadius(8)
              .backgroundColor($r('app.color.card_background'))
              .onClick(() => {
                this.play(m.id);
              })
            }, (m: Media) => `${m.id}_${m.title}_${m.uri}`)
            Column() {
              Text($r('app.string.new_stream'))
                .fontSize(14)
                .fontColor($r('app.color.vlc_orange'))
            }
            .id('mrl_dummy')
            .justifyContent(FlexAlign.Center)
            .width(140)
            .height(64)
            .padding(12)
            .borderRadius(8)
            .backgroundColor($r('app.color.card_background'))
            .onClick(() => {
              this.open('pages/StreamsPage');
            })
          }
          .padding({ left: 16, right: 16 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
        .height(80)

        this.header($r('app.string.history'), 'history_entry')
        Scroll() {
          Row({ space: 8 }) {
            ForEach(this.history, (m: Media) => {
              Column({ space: 4 }) {
                Text(m.title)
                  .fontSize(14)
                  .fontColor($r('app.color.text_primary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(this.subtitle(m))
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .id('history_item_card')
              .alignItems(HorizontalAlign.Start)
              .justifyContent(FlexAlign.Center)
              .width(180)
              .height(64)
              .padding(12)
              .borderRadius(8)
              .backgroundColor($r('app.color.card_background'))
              .onClick(() => {
                this.play(m.id);
              })
            }, (m: Media) => `${m.id}_${m.title}_${m.length}_${m.isStream}_${m.uri}`)
          }
          .padding({ left: 16, right: 16 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
        .height(this.history.length > 0 ? 80 : 0)

        Column() {
          this.navRow($r('sys.symbol.gearshape'), $r('app.string.preferences'), 'settingsButton',
            'pages/SettingsPage')
          this.navRow($r('sys.symbol.info_circle'), $r('app.string.about'), 'aboutButton', 'pages/AboutPage')
        }
        .margin({ top: 16 })
      }
      .width('100%')
      }
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.Top)
    }
    .id('more_fragment')
    .justifyContent(FlexAlign.Start)
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
    .onVisibleAreaChange([0, 1], (isVisible: boolean) => {
      if (isVisible) {
        this.reload();
      }
    })
  }
}
