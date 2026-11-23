@CustomDialog
export struct DelayDialog {
  controller: CustomDialogController = new CustomDialogController({ builder: undefined });
  @State text: string = '';
  onConfirm: (seconds: number) => void = (seconds: number) => {};

  private valid(): boolean {
    if (!/^[0-9]+$/.test(this.text)) {
      return false;
    }
    const n: number = parseInt(this.text, 10);
    return n >= 1 && n <= 60;
  }

  build() {
    Column() {
      Text($r('app.string.jump_delay'))
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .margin({ bottom: 12 })
      TextInput({ text: this.text })
        .id('jump_delay_input')
        .type(InputType.Number)
        .maxLength(3)
        .height(48)
        .onChange((value: string) => {
          this.text = value;
        })
      Text($r('app.string.jump_delay_hint'))
        .id('jump_delay_hint')
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .constraintSize({ minHeight: 24 })
        .margin({ top: 4 })
      Row() {
        Button($r('app.string.cancel'))
          .id('jump_delay_cancel')
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .fontColor($r('app.color.vlc_orange'))
          .height(40)
          .onClick(() => {
            this.controller.close();
          })
        Button($r('app.string.ok'))
          .id('jump_delay_ok')
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .fontColor($r('app.color.vlc_orange'))
          .height(40)
          .enabled(this.valid())
          .onClick(() => {
            this.onConfirm(parseInt(this.text, 10));
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
