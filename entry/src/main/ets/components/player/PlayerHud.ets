import { PlayerSymbols } from './PlayerSymbols';

@ComponentV2
export struct PlayerHud {
  @Param timeText: string = '';
  @Param lengthText: string = '';
  @Param progress: number = 0;
  @Param length: number = 0;
  @Param playing: boolean = false;
  @Param jumpText: string = '';
  @Event onSeekMoving: (ms: number) => void = () => {};
  @Event onSeekEnd: (ms: number) => void = () => {};
  @Event onTogglePlay: () => void = () => {};
  @Event onRewind: () => void = () => {};
  @Event onForward: () => void = () => {};
  @Event onLock: () => void = () => {};
  @Event onTracks: () => void = () => {};
  @Event onResize: () => void = () => {};
  @Event onToggleLength: () => void = () => {};
  @Event onInteract: () => void = () => {};
  @Event onSpeed: () => void = () => {};
  @Local menuShown: boolean = false;

  @Builder
  iconButton(symbol: Resource, id: string, label: Resource, action: () => void) {
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
    .onClick(action)
  }

  @Builder
  speedMenu() {
    Menu() {
      MenuItem({ content: $r('app.string.playback_speed') })
        .id('playback_speed_option')
        .onClick(() => {
          // The menu closes before the sheet opens, so no menu layer is left over the player.
          this.menuShown = false;
          this.onSpeed();
        })
    }
  }

  build() {
    Column() {
      Row() {
        Text(this.timeText)
          .id('player_overlay_time')
          .fontSize($r('app.float.player_text_size'))
          .fontColor($r('app.color.player_text'))
          .constraintSize({ minHeight: 24, minWidth: 44 })
        Slider({
          value: this.progress,
          min: 0,
          max: this.length > 0 ? this.length : 1,
          step: 1,
          style: SliderStyle.OutSet
        })
          .id('player_overlay_seekbar')
          .blockColor($r('app.color.vlc_orange'))
          .selectedColor($r('app.color.vlc_orange'))
          .trackColor($r('app.color.player_track'))
          .layoutWeight(1)
          .onChange((value: number, mode: SliderChangeMode) => {
            if (mode === SliderChangeMode.Moving) {
              this.onSeekMoving(value);
            } else if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
              this.onSeekEnd(value);
            }
          })
        Text(this.lengthText)
          .id('player_overlay_length')
          .fontSize($r('app.float.player_text_size'))
          .fontColor($r('app.color.player_text'))
          .constraintSize({ minHeight: 40, minWidth: 48 })
          .textAlign(TextAlign.End)
          .align(Alignment.End)
          .onClick(() => {
            this.onToggleLength();
            this.onInteract();
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: $r('app.float.player_margin'), right: $r('app.float.player_margin') })

      Row() {
        this.iconButton(PlayerSymbols.lock, 'player_overlay_lock', $r('app.string.lock'), () => this.onLock())
        this.iconButton(PlayerSymbols.tracks, 'player_overlay_tracks', $r('app.string.tracks'),
          () => this.onTracks())
        Column() {
          this.iconButton(PlayerSymbols.rewind, 'player_overlay_rewind', $r('app.string.rewind'),
            () => this.onRewind())
          Text(this.jumpText)
            .id('player_overlay_rewind_text')
            .fontSize($r('app.float.player_text_size'))
            .fontColor($r('app.color.player_text'))
            .constraintSize({ minHeight: 16 })
        }
        Button() {
          SymbolGlyph(this.playing ? $r('sys.symbol.pause') : $r('sys.symbol.play_fill'))
            .fontSize($r('app.float.player_play_icon'))
            .fontColor([$r('app.color.player_text')])
        }
        .id('player_overlay_play')
        .width($r('app.float.player_play_size'))
        .height($r('app.float.player_play_size'))
        .backgroundColor(Color.Transparent)
        .accessibilityText(this.playing ? $r('app.string.pause') : $r('app.string.play'))
        .onClick(() => this.onTogglePlay())
        Column() {
          this.iconButton(PlayerSymbols.forward, 'player_overlay_forward', $r('app.string.forward'),
            () => this.onForward())
          Text(this.jumpText)
            .id('player_overlay_forward_text')
            .fontSize($r('app.float.player_text_size'))
            .fontColor($r('app.color.player_text'))
            .constraintSize({ minHeight: 16 })
        }
        this.iconButton(PlayerSymbols.aspect, 'player_resize', $r('app.string.aspect_ratio'),
          () => this.onResize())
        Button() {
          SymbolGlyph(PlayerSymbols.menu)
            .fontSize($r('app.float.player_icon_size'))
            .fontColor([$r('app.color.player_text')])
        }
        .id('player_overlay_adv_function')
        .width($r('app.float.player_button_size'))
        .height($r('app.float.player_button_size'))
        .backgroundColor(Color.Transparent)
        .accessibilityText($r('app.string.advanced'))
        .bindMenu(this.menuShown, this.speedMenu(), {
          onDisappear: () => {
            this.menuShown = false;
          }
        })
        .onClick(() => {
          this.menuShown = true;
          this.onInteract();
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceEvenly)
      .alignItems(VerticalAlign.Center)
      .padding({ bottom: 16 })
    }
    .width('100%')
    .backgroundColor($r('app.color.player_scrim'))
  }
}
