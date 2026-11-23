@ComponentV2
export struct PlayerLock {
  @Event onUnlock: () => void = () => {};

  build() {
    Row() {
      Button() {
        SymbolGlyph($r('sys.symbol.lock'))
          .fontSize($r('app.float.player_icon_size'))
          .fontColor([$r('app.color.player_text')])
      }
      .id('player_overlay_lock')
      .width($r('app.float.player_button_size'))
      .height($r('app.float.player_button_size'))
      .backgroundColor($r('app.color.player_scrim'))
      .accessibilityText($r('app.string.unlock'))
      .onClick(() => this.onUnlock())
    }
    .width('100%')
    .padding({ left: $r('app.float.player_margin'), bottom: 24 })
  }
}

@ComponentV2
export struct PlayerInfoText {
  @Param text: string = '';

  build() {
    Text(this.text)
      .id('player_overlay_textinfo')
      .fontSize($r('app.float.player_title_size'))
      .fontColor($r('app.color.player_text'))
      .backgroundColor($r('app.color.player_scrim'))
      .borderRadius(8)
      .padding(12)
      .constraintSize({ minHeight: 24 })
  }
}
