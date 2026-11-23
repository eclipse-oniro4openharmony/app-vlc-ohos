import { SymbolGlyphModifier } from '@kit.ArkUI';
import { VideoView } from '../views/VideoView';
import { MoreView } from '../views/MoreView';

const TAB_VIDEO: number = 0;
const TAB_MORE: number = 1;

@Entry
@ComponentV2
struct Index {
  @Local currentTab: number = TAB_VIDEO;
  // Bumped when the page is shown again, so the More tab is rebuilt and reloads its lists.
  @Local epoch: number = 0;

  onPageShow(): void {
    this.epoch++;
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentTab }) {
      TabContent() {
        Column() {
          if (this.currentTab === TAB_VIDEO) {
            VideoView()
          }
        }
        .width('100%')
        .height('100%')
      }
      .tabBar(BottomTabBarStyle.of({ normal: new SymbolGlyphModifier($r('sys.symbol.play_fill')) },$r('app.string.video')))

      TabContent() {
        Column() {
          if (this.currentTab === TAB_MORE) {
            ForEach([this.epoch], (e: number) => {
              MoreView()
            }, (e: number) => `more_${e}`)
          }
        }
        .width('100%')
        .height('100%')
      }
      .tabBar(BottomTabBarStyle.of({ normal: new SymbolGlyphModifier($r('sys.symbol.more')) },$r('app.string.more')))
    }
    .width('100%')
    .height('100%')
    .scrollable(false)
    .animationDuration(0)
    .onChange((index: number) => {
      this.currentTab = index;
    })
  }
}
