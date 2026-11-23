import { FormatStore } from '../../model/FormatStore';

@ComponentV2
export struct HistoryRow {
  @Param index: number = 0;
  @Param title: string = '';
  @Param isStream: boolean = false;
  @Param uri: string = '';
  @Param length: number = 0;
  @Param thumbnail: string = '';
  @Event onPlay: () => void = () => {
  };

  private thumbSource(): string {
    return this.thumbnail.startsWith('/') ? `file://${this.thumbnail}` : this.thumbnail;
  }

  private subtitle(): string {
    if (this.isStream) {
      return this.uri;
    }
    return this.length > 0 ? FormatStore.getInstance().formatTime(this.length) : '';
  }

  build() {
    Row() {
      if (this.isStream) {
        SymbolGlyph($r('sys.symbol.link'))
          .id('icon')
          .fontSize(32)
          .fontColor([$r('app.color.vlc_orange')])
          .width(72)
          .height(48)
      } else if (this.thumbnail.length > 0) {
        Image(this.thumbSource())
          .id('icon')
          .width(72)
          .height(48)
          .objectFit(ImageFit.Cover)
          .borderRadius(4)
      } else {
        Image($r('app.media.app_icon'))
          .id('icon')
          .width(72)
          .height(48)
          .objectFit(ImageFit.Contain)
      }
      Column() {
        Text(this.title)
          .id('title')
          .constraintSize({ minHeight: 24 })
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.subtitle())
          .id('subtitle')
          .constraintSize({ minHeight: 20 })
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 12 })
    }
    .id(`history_row_${this.index}`)
    .width('100%')
    .constraintSize({ minHeight: 64 })
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.onPlay();
    })
  }
}
