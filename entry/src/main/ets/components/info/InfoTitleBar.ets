import { router } from '@kit.ArkUI';

@ComponentV2
export struct InfoTitleBar {
  @Param title: string = '';

  build() {
    Row() {
      SymbolGlyph($r('sys.symbol.arrow_left'))
        .fontSize($r('app.float.title_icon_size'))
        .fontColor([$r('app.color.title_bar_text')])
        .width($r('app.float.title_button_size'))
        .height($r('app.float.title_button_size'))
        .id('back_button')
        .accessibilityText($r('app.string.back'))
        .onClick(() => {
          router.back();
        })
      Text(this.title.length > 0 ? this.title : $r('app.string.info'))
        .fontSize($r('app.float.title_font_size'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.title_bar_text'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .margin({ left: 8 })
    }
    .width('100%')
    .height($r('app.float.title_bar_height'))
    .padding({ left: 8, right: 8 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor($r('app.color.title_bar_background'))
  }
}
