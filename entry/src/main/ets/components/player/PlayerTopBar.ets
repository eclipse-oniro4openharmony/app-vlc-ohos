@ComponentV2
export struct PlayerTopBar {
  @Param title: string = '';
  @Param speedText: string = '';
  @Event onBack: () => void = () => {};

  build() {
    Row() {
      Button() {
        SymbolGlyph($r('sys.symbol.arrow_left'))
          .fontSize($r('app.float.player_icon_size'))
          .fontColor([$r('app.color.player_text')])
      }
      .id('player_overlay_back')
      .width($r('app.float.player_button_size'))
      .height($r('app.float.player_button_size'))
      .backgroundColor(Color.Transparent)
      .accessibilityText($r('app.string.back'))
      .onClick(() => this.onBack())

      Text(this.title)
        .id('player_overlay_title')
        .fontSize($r('app.float.player_title_size'))
        .fontColor($r('app.color.player_text'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ minHeight: 24 })
        .layoutWeight(1)

      if (this.speedText.length > 0) {
        Text(this.speedText)
          .id('playback_speed_quick_action')
          .fontSize($r('app.float.player_text_size'))
          .fontColor($r('app.color.vlc_orange'))
          .constraintSize({ minHeight: 24 })
          .margin({ left: $r('app.float.player_margin'), right: $r('app.float.player_margin') })
      }
    }
    .width('100%')
    .padding({ left: $r('app.float.player_margin'), right: $r('app.float.player_margin'), top: 24 })
    .backgroundColor($r('app.color.player_scrim'))
    .alignItems(VerticalAlign.Center)
  }
}
