@CustomDialog
export struct ThemeDialog {
  controller: CustomDialogController = new CustomDialogController({ builder: undefined });
  current: number = -1;
  onChoose: (mode: number) => void = (mode: number) => {};

  @Builder
  option(index: number, mode: number, label: Resource) {
    Row() {
      Radio({ value: `theme_${index}`, group: 'app_theme_group' })
        .checked(this.current === mode)
        .width(24)
        .height(24)
        .onChange((on: boolean) => {
          if (on) {
            this.choose(mode);
          }
        })
      Text(label)
        .id(`app_theme_option_${index}`)
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .margin({ left: 12 })
    }
    .width('100%')
    .height(48)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.choose(mode);
    })
  }

  private choose(mode: number): void {
    this.onChoose(mode);
    this.controller.close();
  }

  build() {
    Column() {
      Text($r('app.string.daynight_title'))
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .margin({ bottom: 8 })
      this.option(0, -1, $r('app.string.daynight_follow_system_title'))
      this.option(1, 1, $r('app.string.light_theme'))
      this.option(2, 2, $r('app.string.enable_black_theme'))
      Row() {
        Button($r('app.string.cancel'))
          .id('app_theme_cancel')
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .fontColor($r('app.color.vlc_orange'))
          .height(40)
          .onClick(() => {
            this.controller.close();
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
      .margin({ top: 8 })
    }
    .padding(24)
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(16)
  }
}
