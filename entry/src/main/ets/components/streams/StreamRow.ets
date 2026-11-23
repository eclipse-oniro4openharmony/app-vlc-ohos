@ComponentV2
export struct StreamRow {
  @Param index: number = 0;
  @Param title: string = '';
  @Param uri: string = '';
  @Event onPlay: () => void = () => {};
  @Event onCopy: () => void = () => {};
  @Event onDelete: () => void = () => {};

  @Builder
  menu() {
    Column() {
      Text($r('app.string.copy_to_clipboard'))
        .id('ctx_copy')
        .fontSize($r('app.float.page_text_font_size'))
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 16 })
        .onClick(() => {
          this.onCopy();
        })
      Text($r('app.string.delete'))
        .id('ctx_delete')
        .fontSize($r('app.float.page_text_font_size'))
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 16 })
        .onClick(() => {
          this.onDelete();
        })
    }
    .width(220)
    .backgroundColor($r('app.color.card_background'))
  }

  build() {
    Row() {
      Column() {
        Text(this.title)
          .id('mrl_item_title')
          .fontSize($r('app.float.page_text_font_size'))
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ minHeight: 24 })
        Text(this.uri)
          .id('mrl_item_uri')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ minHeight: 20 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .onClick(() => {
        this.onPlay();
      })

      SymbolGlyph($r('sys.symbol.dot_grid_2x2'))
        .fontSize(24)
        .fontColor([$r('app.color.text_secondary')])
        .width(40)
        .height(40)
        .id(`mrl_ctx_${this.index}`)
        .accessibilityText($r('app.string.more_actions'))
        .bindMenu(this.menu())
    }
    .id(`mrl_row_${this.index}`)
    .width('100%')
    .padding({ left: 16, right: 8, top: 8, bottom: 8 })
    .alignItems(VerticalAlign.Center)
  }
}
