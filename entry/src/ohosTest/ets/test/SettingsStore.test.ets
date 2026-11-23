import { describe, it, expect } from '@ohos/hypium';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { SettingsStore } from '../../../main/ets/model/SettingsStore';
import { Settings } from '../../../main/ets/model/Settings';

export default function settingsStoreTest() {
  describe('SettingsStoreTest', () => {
    it('defaultsAndPersistence', 0, async () => {
      const s: SettingsStore = SettingsStore.getInstance();
      s.init(abilityDelegatorRegistry.getAbilityDelegator().getAppContext().getApplicationContext());
      await s.setVideoResumePlayback(true);
      await s.setPlaybackHistory(true);
      await s.setVideoJumpDelay(10);
      await s.setAppTheme(-1);
      const fresh: SettingsStore = new SettingsStore();
      fresh.init(abilityDelegatorRegistry.getAbilityDelegator().getAppContext().getApplicationContext());
      let loaded: Settings = await fresh.load();
      expect(loaded.videoResumePlayback).assertEqual(true);
      expect(loaded.playbackHistory).assertEqual(true);
      expect(loaded.videoJumpDelay).assertEqual(10);
      expect(loaded.appTheme).assertEqual(-1);
      await s.setPlaybackHistory(false);
      await s.setVideoJumpDelay(20);
      await s.setAppTheme(2);
      const second: SettingsStore = new SettingsStore();
      second.init(abilityDelegatorRegistry.getAbilityDelegator().getAppContext().getApplicationContext());
      loaded = await second.load();
      expect(loaded.playbackHistory).assertEqual(false);
      expect(loaded.videoJumpDelay).assertEqual(20);
      expect(loaded.appTheme).assertEqual(2);
      expect(second.current().videoJumpDelay).assertEqual(20);
      await s.setPlaybackHistory(true);
      await s.setVideoJumpDelay(10);
      await s.setAppTheme(-1);
    })
    it('jumpDelayRange', 0, async () => {
      const s: SettingsStore = SettingsStore.getInstance();
      s.init(abilityDelegatorRegistry.getAbilityDelegator().getAppContext().getApplicationContext());
      expect(await s.setVideoJumpDelay(0)).assertEqual(false);
      expect(await s.setVideoJumpDelay(61)).assertEqual(false);
      expect(await s.setVideoJumpDelay(1.5)).assertEqual(false);
      expect(await s.setVideoJumpDelay(1)).assertEqual(true);
      expect(await s.setVideoJumpDelay(60)).assertEqual(true);
      expect(s.current().videoJumpDelay).assertEqual(60);
      await s.setVideoJumpDelay(10);
    })
    it('themeValues', 0, async () => {
      const s: SettingsStore = SettingsStore.getInstance();
      s.init(abilityDelegatorRegistry.getAbilityDelegator().getAppContext().getApplicationContext());
      await s.setAppTheme(7);
      expect(s.current().appTheme).assertEqual(-1);
      expect(s.colorMode(-1)).assertEqual(-1);
      expect(s.colorMode(1)).assertEqual(1);
    })
  })
}
