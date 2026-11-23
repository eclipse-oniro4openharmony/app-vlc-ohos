import { FormatStore } from '../../model/FormatStore';

@ComponentV2
export struct SpeedSheet {
  @Param rate: number = 1;
  @Param isStream: boolean = false;
  @Event onRate: (rate: number) => void = () => {};

  @Builder
  preset(label: Resource, id: string, value: number) {
    Button(label)
      .id(id)
      .height($r('app.float.player_preset_height'))
      .layoutWeight(1)
      .margin({ left: 2, right: 2 })
      .fontSize($r('app.float.player_text_size'))
      .fontColor($r('app.color.player_text'))
      .backgroundColor(Math.abs(this.rate - value) < 0.005 ? $r('app.color.vlc_orange') :
      $r('app.color.player_track'))
      .onClick(() => this.onRate(value))
  }

  @Builder
  stepButton(symbol: Resource, id: string, label: Resource, delta: number) {
    Button() {
      SymbolGlyph(symbol)
        .fontSize($r('app.float.player_icon_size'))
        .fontColor([$r('app.color.player_text')])
    }
    .id(id)
    .width($r('app.float.player_button_size'))
    .height($r('app.float.player_button_size'))
    .backgroundColor(Color.Transparent)
    .accessibilityText(label)
    .accessibilityDescription(label)
    .onClick(() => this.onRate(FormatStore.getInstance().clampRate(this.rate + delta)))
  }

  build() {
    Column() {
      Text($r('app.string.playback_speed'))
        .id('textView12')
        .fontSize($r('app.float.player_title_size'))
        .fontColor($r('app.color.player_text'))
        .constraintSize({ minHeight: 24 })
        .margin({ top: 8, bottom: 8 })
      Row() {
        this.stepButton($r('sys.symbol.minus'), 'button_speed_minus', $r('app.string.decrease_speed'), -0.01)
        Text(FormatStore.getInstance().formatRate(this.rate))
          .id('playback_speed_value')
          .fontSize($r('app.float.player_title_size'))
          .fontColor($r('app.color.player_text'))
          .constraintSize({ minHeight: 24, minWidth: 80 })
          .textAlign(TextAlign.Center)
        this.stepButton($r('sys.symbol.plus'), 'button_speed_plus', $r('app.string.increase_speed'), 0.01)
      }
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)

      Slider({ value: this.rate, min: 0.25, max: 4, step: 0.01, style: SliderStyle.OutSet })
        .id('playback_speed_seek')
        .blockColor($r('app.color.vlc_orange'))
        .selectedColor($r('app.color.vlc_orange'))
        .trackColor($r('app.color.player_track'))
        .onChange((value: number, mode: SliderChangeMode) => {
          this.onRate(FormatStore.getInstance().clampRate(value));
        })

      Row() {
        this.preset($r('app.string.speed_08'), 'button_speed_08', 0.8)
        this.preset($r('app.string.speed_1'), 'button_speed_1', 1)
        this.preset($r('app.string.speed_125'), 'button_speed_125', 1.25)
        this.preset($r('app.string.speed_15'), 'button_speed_15', 1.5)
        this.preset($r('app.string.speed_2'), 'button_speed_2', 2)
      }
      .width('100%')
      .margin({ top: 12 })

      if (this.isStream && this.rate > 1) {
        Text($r('app.string.stream_warning'))
          .id('stream_warning')
          .fontSize($r('app.float.player_text_size'))
          .fontColor($r('app.color.player_text_secondary'))
          .margin({ top: 12 })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: 32 })
  }
}
