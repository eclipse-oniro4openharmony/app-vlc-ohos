import { TrackItem } from './PlayerTypes';

/** One track row: the radio (filled orange with a tick when selected, an empty grey ring otherwise) and its label. */
@ComponentV2
struct TrackRow {
  @Param label: string = '';
  @Param labelId: string = '';
  @Param radioValue: string = '';
  @Param group: string = '';
  @Param selected: boolean = false;
  @Event onSelect: () => void = () => {};

  build() {
    Row({ space: 12 }) {
      Radio({ value: this.radioValue, group: this.group, indicatorType: RadioIndicatorType.TICK })
        .checked(this.selected)
        .radioStyle({
          checkedBackgroundColor: $r('app.color.vlc_orange'),
          uncheckedBorderColor: $r('app.color.player_text_secondary'),
          indicatorColor: $r('app.color.player_text')
        })
        .onChange((isChecked: boolean) => {
          // Only a tap selects: the checked state set from the engine does not apply again.
          if (isChecked && !this.selected) {
            this.onSelect();
          }
        })
      Text(this.label)
        .id(this.labelId)
        .fontSize($r('app.float.player_text_size'))
        .fontColor(this.selected ? $r('app.color.vlc_orange') : $r('app.color.player_text'))
        .fontWeight(this.selected ? FontWeight.Medium : FontWeight.Normal)
        .constraintSize({ minHeight: 24 })
        .layoutWeight(1)
    }
    .width('100%')
    .height($r('app.float.player_row_height'))
    .onClick(() => {
      if (!this.selected) {
        this.onSelect();
      }
    })
  }
}

@ComponentV2
export struct TracksSheet {
  @Param audio: TrackItem[] = [];
  @Param subtitles: TrackItem[] = [];
  @Param audioSelected: number = -1;
  @Param subtitleSelected: number = -1;
  @Event onAudio: (id: number) => void = () => {};
  @Event onSubtitle: (id: number) => void = () => {};

  /** The subtitle shown as selected: the engine's, or Disable (-1) when it names none of the listed tracks. */
  private shownSubtitle(): number {
    for (const item of this.subtitles) {
      if (item.id === this.subtitleSelected) {
        return this.subtitleSelected;
      }
    }
    return -1;
  }

  build() {
    Scroll() {
      Column() {
        Text($r('app.string.track_audio'))
          .id('audio_tracks')
          .fontSize($r('app.float.player_title_size'))
          .fontColor($r('app.color.vlc_orange'))
          .constraintSize({ minHeight: 24 })
          .margin({ top: 8, bottom: 8 })
        if (this.audio.length === 0) {
          Text($r('app.string.no_track'))
            .fontSize($r('app.float.player_text_size'))
            .fontColor($r('app.color.player_text_secondary'))
        }
        ForEach(this.audio, (item: TrackItem, index: number) => {
          TrackRow({
            label: item.label,
            labelId: `audio_track_${index}`,
            radioValue: `audio_${item.id}`,
            group: 'audio_group',
            selected: item.id === this.audioSelected,
            onSelect: () => this.onAudio(item.id)
          })
        }, (item: TrackItem, index: number) => `${index}_${item.id}_${item.label}_${item.id === this.audioSelected}`)

        Text($r('app.string.subtitles'))
          .id('subtitle_tracks')
          .fontSize($r('app.float.player_title_size'))
          .fontColor($r('app.color.vlc_orange'))
          .constraintSize({ minHeight: 24 })
          .margin({ top: 16, bottom: 8 })
        if (this.subtitles.length <= 1) {
          Text($r('app.string.no_track'))
            .fontSize($r('app.float.player_text_size'))
            .fontColor($r('app.color.player_text_secondary'))
            .margin({ bottom: 4 })
        }
        ForEach(this.subtitles, (item: TrackItem, index: number) => {
          TrackRow({
            label: item.label,
            labelId: `subtitle_track_${index}`,
            radioValue: `subtitle_${item.id}`,
            group: 'subtitle_group',
            selected: item.id === this.shownSubtitle(),
            onSelect: () => this.onSubtitle(item.id)
          })
        }, (item: TrackItem, index: number) =>
        `${index}_${item.id}_${item.label}_${item.id === this.shownSubtitle()}`)
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 32 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
  }
}
