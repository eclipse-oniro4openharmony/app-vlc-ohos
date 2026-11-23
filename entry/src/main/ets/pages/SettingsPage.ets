import { hilog } from '@kit.PerformanceAnalysisKit';
import { TitleBar } from '../components/common/TitleBar';
import { SettingsStore } from '../model/SettingsStore';
import { Settings } from '../model/Settings';
import { ThemeDialog } from '../components/settings/ThemeDialog';
import { DelayDialog } from '../components/settings/DelayDialog';

@Entry
@ComponentV2
struct SettingsPage {
  @Local settings: Settings = SettingsStore.getInstance().current();
  private store: SettingsStore = SettingsStore.getInstance();
  private themeDialog: CustomDialogController | undefined = undefined;
  private delayDialog: CustomDialogController | undefined = undefined;

  aboutToAppear(): void {
    this.store.load().then((s: Settings) => {
      this.settings = s;
    }).catch((e: Error) => {
      hilog.error(0x0001, 'VlcSettings', 'load failed: %{public}s', JSON.stringify(e));
    });
  }

  private applyTheme(mode: number): void {
    this.store.setAppTheme(mode);
    try {
      this.getUIContext().getHostContext()?.getApplicationContext().setColorMode(this.store.colorMode(mode));
    } catch (e) {
      hilog.error(0x0001, 'VlcSettings', 'setColorMode failed: %{public}s', JSON.stringify(e));
    }
  }

  @Builder
  groupTitle(label: Resource) {
    Text(label)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.vlc_orange'))
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 4 })
  }

  build() {
    Column() {
      TitleBar({ title: $r('app.string.preferences') })
      List() {
        ListItem() {
          this.groupTitle($r('app.string.interface_prefs_screen'))
        }
        ListItem() {
          Column() {
            Text($r('app.string.daynight_title'))
              .fontSize(16)
              .fontColor($r('app.color.text_primary'))
              .width('100%')
            Text(this.store.themeName(this.settings.appTheme))
              .id('app_theme_summary')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .constraintSize({ minHeight: 24 })
          }
          .id('app_theme')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .onClick(() => {
            this.openThemeDialog();
          })
        }
        ListItem() {
          this.groupTitle($r('app.string.video_prefs_category'))
        }
        ListItem() {
          Column() {
            Text($r('app.string.jump_delay'))
              .fontSize(16)
              .fontColor($r('app.color.text_primary'))
              .width('100%')
            Text($r('app.string.jump_delay_summary', this.settings.videoJumpDelay))
              .id('video_jump_delay_summary')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .constraintSize({ minHeight: 24 })
          }
          .id('video_jump_delay')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .onClick(() => {
            this.openDelayDialog();
          })
        }
        ListItem() {
          this.groupTitle($r('app.string.history'))
        }
        ListItem() {
          this.switchRow($r('app.string.playback_history_title'), $r('app.string.playback_history_summary'), true)
        }
        ListItem() {
          this.switchRow($r('app.string.video_resume_playback_title'), $r('app.string.video_resume_playback_summary'), false)
        }
      }
      .id('preferences_list')
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }

  @Builder
  switchRow(title: Resource, summary: Resource, isHistory: boolean) {
    Row() {
      Column() {
        Text(title)
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
        Text(summary)
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
      }
      .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: isHistory ? this.settings.playbackHistory : this.settings.videoResumePlayback })
        .id(isHistory ? 'playback_history' : 'video_resume_playback')
        .selectedColor($r('app.color.vlc_orange'))
        .onChange((on: boolean) => {
          if (isHistory) {
            this.store.setPlaybackHistory(on);
          } else {
            this.store.setVideoResumePlayback(on);
          }
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .alignItems(VerticalAlign.Center)
  }

  private openThemeDialog(): void {
    this.themeDialog = new CustomDialogController({
      builder: ThemeDialog({
        current: this.settings.appTheme,
        onChoose: (mode: number) => {
          this.applyTheme(mode);
        }
      }),
      cancel: () => {}
    });
    this.themeDialog?.open();
  }

  private openDelayDialog(): void {
    this.delayDialog = new CustomDialogController({
      builder: DelayDialog({
        text: `${this.settings.videoJumpDelay}`,
        onConfirm: (seconds: number) => {
          this.store.setVideoJumpDelay(seconds);
        }
      }),
      cancel: () => {}
    });
    this.delayDialog?.open();
  }
}
