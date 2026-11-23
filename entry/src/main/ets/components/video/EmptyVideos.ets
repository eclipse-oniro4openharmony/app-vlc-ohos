@ComponentV2
export struct EmptyVideos {
  @Event onPick: () => void = () => {
  };

  build() {
    Column({ space: 16 }) {
      Image($r('app.media.app_icon'))
        .width(96)
        .height(96)
        .objectFit(ImageFit.Contain)
      Text($r('app.string.nomedia'))
        .id('emptyTextView')
        .constraintSize({ minHeight: 24 })
        .fontSize(16)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
        .padding({ left: 32, right: 32 })
      Button($r('app.string.pick_file'))
        .id('pickFile')
        .backgroundColor($r('app.color.vlc_orange'))
        .fontColor($r('app.color.player_text'))
        .onClick(() => {
          this.onPick();
        })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }
}
