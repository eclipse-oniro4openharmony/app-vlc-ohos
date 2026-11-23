import { FormatStore } from '../../model/FormatStore';

@ComponentV2
export struct VideoRow {
  @Param index: number = 0;
  @Param title: string = '';
  @Param length: number = 0;
  @Param videoWidth: number = 0;
  @Param videoHeight: number = 0;
  @Param thumbnail: string = '';
  @Param lastPosition: number = 0;
  @Local thumbFailed: boolean = false;
  @Event onPlay: () => void = () => {
  };
  @Event onInfo: () => void = () => {
  };
  @Event onRemove: () => void = () => {
  };

  private thumbSource(): string {
    return this.thumbnail.startsWith('/') ? `file://${this.thumbnail}` : this.thumbnail;
  }

  private progress(): number {
    if (this.length <= 0) {
      return 0;
    }
    return Math.min(100, Math.round(this.lastPosition * 100 / this.length));
  }

  @Builder
  menu() {
    Menu() {
      MenuItem({ content: $r('app.string.play') })
        .id('ctx_play')
        .onClick(() => {
          this.onPlay();
        })
      MenuItem({ content: $r('app.string.info') })
        .id('ctx_information')
        .onClick(() => {
          this.onInfo();
        })
      MenuItem({ content: $r('app.string.remove') })
        .id('ctx_remove')
        .onClick(() => {
          this.onRemove();
        })
    }
  }

  build() {
    Row() {
      Column() {
        if (this.thumbnail.length > 0 && !this.thumbFailed) {
          Image(this.thumbSource())
            .id('ml_item_thumbnail')
            .width(120)
            .height(68)
            .objectFit(ImageFit.Cover)
            .onError(() => {
              this.thumbFailed = true;
            })
        } else {
          Image($r('app.media.app_icon'))
            .id('ml_item_thumbnail')
            .width(120)
            .height(68)
            .objectFit(ImageFit.Contain)
        }
        if (this.lastPosition > 0) {
          Progress({ value: this.progress(), total: 100, type: ProgressType.Linear })
            .id('ml_item_progress')
            .width(120)
            .height(3)
            .color($r('app.color.vlc_orange'))
        }
      }
      .width(120)
      .borderRadius(4)
      .clip(true)

      Column({ space: 4 }) {
        Text(this.title)
          .id('ml_item_title')
          .constraintSize({ minHeight: 24 })
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Row({ space: 12 }) {
          Text(this.length > 0 ? FormatStore.getInstance().formatTime(this.length) : '')
            .id('ml_item_time')
            .constraintSize({ minHeight: 20 })
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
          Text(FormatStore.getInstance().resolutionClass(this.videoWidth, this.videoHeight))
            .id('ml_item_resolution')
            .constraintSize({ minHeight: 20 })
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
        }
      }
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Center)
      .layoutWeight(1)
      .margin({ left: 12 })

      SymbolGlyph($r('sys.symbol.ellipsis_circle'))
        .id(`item_more_${this.index}`)
        .fontSize(24)
        .fontColor([$r('app.color.text_secondary')])
        .width(40)
        .height(40)
        .accessibilityText($r('app.string.more_actions'))
        .bindMenu(this.menu())
    }
    .id(`video_row_${this.index}`)
    .width('100%')
    .constraintSize({ minHeight: 84 })
    .padding({ left: 16, right: 8, top: 8, bottom: 8 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.onPlay();
    })
  }
}
