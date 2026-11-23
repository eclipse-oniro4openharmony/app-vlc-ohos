import { preferences } from '@kit.ArkData';
import { ConfigurationConstant } from '@kit.AbilityKit';
import type { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Settings } from './Settings';

const KEY_RESUME: string = 'video_resume_playback';
const KEY_HISTORY: string = 'playback_history';
const KEY_JUMP: string = 'video_jump_delay';
const KEY_THEME: string = 'app_theme';

export class SettingsStore {
  private static instance: SettingsStore | undefined = undefined;
  private prefs: preferences.Preferences | undefined = undefined;
  private settings: Settings = new Settings();
  private context: common.Context | undefined = undefined;

  static getInstance(): SettingsStore {
    if (SettingsStore.instance === undefined) {
      SettingsStore.instance = new SettingsStore();
    }
    return SettingsStore.instance;
  }

  init(context: common.Context): void {
    if (this.prefs === undefined || this.context !== context) {
      this.context = context;
      this.prefs = preferences.getPreferencesSync(context, { name: 'vlc_settings' });
    }
    this.readAll();
  }

  private readAll(): void {
    const p: preferences.Preferences | undefined = this.prefs;
    if (p === undefined) {
      return;
    }
    try {
      this.settings.videoResumePlayback = p.getSync(KEY_RESUME, true) as boolean;
      this.settings.playbackHistory = p.getSync(KEY_HISTORY, true) as boolean;
      this.settings.videoJumpDelay = p.getSync(KEY_JUMP, 10) as number;
      this.settings.appTheme = p.getSync(KEY_THEME, -1) as number;
    } catch (e) {
      hilog.error(0x0001, 'VlcSettings', 'read failed: %{public}s', JSON.stringify(e));
    }
  }

  async load(): Promise<Settings> {
    this.readAll();
    return this.settings;
  }

  current(): Settings {
    return this.settings;
  }

  private async write(key: string, value: boolean | number): Promise<void> {
    const p: preferences.Preferences | undefined = this.prefs;
    if (p === undefined) {
      return;
    }
    try {
      p.putSync(key, value);
      await p.flush();
    } catch (e) {
      hilog.error(0x0001, 'VlcSettings', 'write %{public}s failed: %{public}s', key, JSON.stringify(e));
    }
  }

  async setVideoResumePlayback(on: boolean): Promise<void> {
    this.settings.videoResumePlayback = on;
    await this.write(KEY_RESUME, on);
  }

  async setPlaybackHistory(on: boolean): Promise<void> {
    this.settings.playbackHistory = on;
    await this.write(KEY_HISTORY, on);
  }

  async setVideoJumpDelay(seconds: number): Promise<boolean> {
    if (!Number.isInteger(seconds) || seconds < 1 || seconds > 60) {
      return false;
    }
    this.settings.videoJumpDelay = seconds;
    await this.write(KEY_JUMP, seconds);
    return true;
  }

  async setAppTheme(mode: number): Promise<void> {
    const value: number = (mode === 1 || mode === 2) ? mode : -1;
    this.settings.appTheme = value;
    await this.write(KEY_THEME, value);
  }

  themeName(mode: number): Resource {
    if (mode === 1) {
      return $r('app.string.light_theme');
    }
    if (mode === 2) {
      return $r('app.string.enable_black_theme');
    }
    return $r('app.string.daynight_follow_system_title');
  }

  colorMode(mode: number): number {
    if (mode === 1) {
      return ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    }
    if (mode === 2) {
      return ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    }
    return ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
  }
}
