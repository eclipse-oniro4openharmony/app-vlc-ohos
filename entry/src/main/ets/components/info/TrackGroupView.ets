import { InfoRow } from './InfoRow';
import { InfoLine } from './InfoTypes';

@ComponentV2
export struct TrackGroupView {
  @Param kind: number = 0;
  @Param label: string = '';
  @Param lines: InfoLine[] = [];

  private kindTitle(): Resource {
    if (this.kind === 1) {
      return $r('app.string.track_audio');
    }
    if (this.kind === 2) {
      return $r('app.string.track_text');
    }
    return $r('app.string.track_video');
  }

  build() {
    Column() {
      Row() {
        Text(this.kindTitle())
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.vlc_orange'))
        if (this.label.length > 0) {
          Text(this.label)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.vlc_orange'))
            .layoutWeight(1)
            .margin({ left: 8 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 6, bottom: 2 })
      ForEach(this.lines, (line: InfoLine) => {
        InfoRow({ label: line.label, value: line.value })
      }, (line: InfoLine, index: number) => `${index}_${line.value}`)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
