import { bundleManager } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { TitleBar } from '../components/common/TitleBar';
import { vlcService } from '../services/VlcService';

@Entry
@ComponentV2
struct AboutPage {
  @Local versionName: string = '';
  @Local engineVersion: string = '';

  aboutToAppear(): void {
    try {
      const info: bundleManager.BundleInfo =
        bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      this.versionName = info.versionName;
    } catch (e) {
      hilog.error(0x0001, 'VlcAbout', 'bundle info failed: %{public}s', JSON.stringify(e));
    }
    try {
      this.engineVersion = vlcService.libvlcVersion();
    } catch (e) {
      hilog.error(0x0001, 'VlcAbout', 'libvlc version failed: %{public}s', JSON.stringify(e));
    }
  }

  build() {
    Column() {
      TitleBar({ title: $r('app.string.about') })
      Scroll() {
        Column() {
          Image($r('app.media.app_icon'))
            .id('logo')
            .width(96)
            .height(96)
            .margin({ top: 8 })
          Text($r('app.string.app_name_full'))
            .id('textView7')
            .constraintSize({ minHeight: 24 })
            .fontSize(22)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .margin({ top: 12 })
          Text($r('app.string.about_text'))
            .id('textView26')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Center)
            .margin({ top: 8, bottom: 16 })
          Column({ space: 8 }) {
            Text($r('app.string.about_version_format', this.versionName))
              .id('app_version')
              .constraintSize({ minHeight: 24 })
              .width('100%')
              .fontSize(16)
              .fontColor($r('app.color.text_primary'))
            Text($r('app.string.about_libvlc_format', this.engineVersion))
              .id('libvlc_version')
              .constraintSize({ minHeight: 24 })
              .width('100%')
              .fontSize(16)
              .fontColor($r('app.color.text_primary'))
          }
          .width('100%')
          .padding(16)
          .borderRadius(8)
          .backgroundColor($r('app.color.card_background'))
          Column({ space: 8 }) {
            Text($r('app.string.about_videolan'))
              .width('100%')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.vlc_orange'))
            Text($r('app.string.copyleft'))
              .id('copyleft')
              .constraintSize({ minHeight: 24 })
              .width('100%')
              .fontSize(14)
              .fontColor($r('app.color.text_primary'))
            Text($r('app.string.license'))
              .id('license')
              .constraintSize({ minHeight: 24 })
              .width('100%')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
          }
          .width('100%')
          .padding(16)
          .margin({ top: 16 })
          .borderRadius(8)
          .backgroundColor($r('app.color.card_background'))
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 24 })
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .backgroundColor($r('app.color.page_background'))
  }
}
