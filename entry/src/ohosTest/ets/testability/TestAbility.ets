import { UIAbility } from '@kit.AbilityKit';
import type { Want, AbilityConstant } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

export default class TestAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'TestAbility onCreate');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('testability/pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'testTag', 'loadContent failed: %{public}s', JSON.stringify(err));
      }
    });
  }
}
