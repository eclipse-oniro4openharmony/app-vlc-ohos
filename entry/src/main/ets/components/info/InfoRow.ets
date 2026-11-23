@ComponentV2
export struct InfoRow {
  @Param label: Resource = $r('app.string.length');
  @Param value: string = '';
  @Param labelId: string = '';
  @Param valueId: string = '';

  build() {
    Row() {
      Text(this.label)
        .id(this.labelId)
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .width(120)
      Text(this.value)
        .id(this.valueId)
        .constraintSize({ minHeight: 24 })
        .fontSize(14)
        .layoutWeight(1)
        .textAlign(TextAlign.Start)
    }
    .width('100%')
    .constraintSize({ minHeight: 32 })
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
  }
}
