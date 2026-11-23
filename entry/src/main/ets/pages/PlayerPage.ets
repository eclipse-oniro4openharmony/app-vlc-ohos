import { vlcService, VlcEvent, VlcEventData, VlcVideoSize } from '../services/VlcService';
import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import type { common } from '@kit.AbilityKit';
import { Media } from '../model/Media';
import { MediaStore } from '../model/MediaStore';
import { SettingsStore } from '../model/SettingsStore';
import { FormatStore } from '../model/FormatStore';
import { TrackItem, VlcXComponentController, buildTrackItems, MODE_NAMES, ModeLayout,
  modeLayoutOf, OneShotTimer, playerSheetOptions, tracksSheetHeight, subtitleSeekTarget } from '../components/player/PlayerTypes';
import { PlayerSession } from '../components/player/PlayerSession';
import { PlayerTopBar } from '../components/player/PlayerTopBar';
import { PlayerHud } from '../components/player/PlayerHud';
import { PlayerLock, PlayerInfoText } from '../components/player/PlayerLock';
import { TracksSheet } from '../components/player/TracksSheet';
import { SpeedSheet } from '../components/player/SpeedSheet';

const TAG: string = 'PlayerPage';
const HIDE_DELAY_MS: number = 4000;
const INFO_DELAY_MS: number = 2000;
const SEEK_HOLD_MS: number = 1500;

@Entry
@ComponentV2
struct PlayerPage {
  private controller: VlcXComponentController = new VlcXComponentController();
  private session: PlayerSession = new PlayerSession();
  private surfaceId: string = '';
  private surfaceWidth: number = 0;
  private surfaceHeight: number = 0;
  private mediaLoaded: boolean = false;
  private started: boolean = false;
  private left: boolean = false;
  private recorded: boolean = false;
  private resumeAt: number = 0;
  private userPaused: boolean = false;
  private hasPlayed: boolean = false;
  private hideTimer: OneShotTimer = new OneShotTimer();
  private infoTimer: OneShotTimer = new OneShotTimer();
  private holdUntil: number = 0;
  private autoShown: boolean = true;
  @Local playing: boolean = false;
  @Local currentTime: number = 0;
  @Local length: number = 0;
  @Local overlayVisible: boolean = true;
  @Local locked: boolean = false;
  @Local showRemaining: boolean = false;
  @Local title: string = '';
  @Local isStream: boolean = false;
  @Local rate: number = 1;
  @Local resizeMode: number = 0;
  @Local infoText: string = '';
  private videoWidth: number = 0;
  private videoHeight: number = 0;
  @Local pageWidth: number = 0;
  @Local pageHeight: number = 0;
  @Local showTracks: boolean = false;
  @Local showSpeed: boolean = false;
  @Local audioItems: TrackItem[] = [];
  @Local spuItems: TrackItem[] = [];
  @Local audioSelected: number = -1;
  @Local spuSelected: number = -1;

  aboutToAppear(): void {
    // The player exists before the surface does, so the native window is attached
    // on surface creation and always before play().
    vlcService.prepare();
    this.controller.surfaceCreatedCallback = (surfaceId: string) => {
      this.surfaceId = surfaceId;
      vlcService.setNativeWindow(surfaceId);
      this.tryStart();
    };
    this.controller.surfaceSizeCallback = (width: number, height: number) => {
      // Rotation or a new layout: Fit screen and Fill depend on the surface's shape.
      this.surfaceWidth = width;
      this.surfaceHeight = height;
      this.applyResize();
    };
    this.controller.surfaceDestroyedCallback = () => {
      this.surfaceId = '';
      vlcService.setNativeWindow('');
    };
    this.registerEvents();
    hilog.info(0x0001, TAG, 'player page opened');
    this.armHide();
    this.loadMedia().catch((e: Error) => {
      hilog.error(0x0001, TAG, 'load failed: %{public}s', JSON.stringify(e));
      this.fail();
    });
  }

  aboutToDisappear(): void {
    if (!this.left) {
      this.teardown();
    }
  }

  onPageHide(): void {
    // Home or another app: the process may be killed in the background, so the
    // resume point is saved now and not only when the page is left.
    if (!this.left && this.hasPlayed && this.session.mediaId >= 0) {
      MediaStore.getInstance().savePosition(this.session.mediaId, this.currentTime).catch((e: Error) => {
        hilog.error(0x0001, TAG, 'save position failed: %{public}s', JSON.stringify(e));
      });
    }
  }

  onBackPress(): boolean {
    if (this.showTracks || this.showSpeed) {
      this.closeSheets();
      return true;
    }
    this.leave(true, false);
    return true;
  }

  private registerEvents(): void {
    vlcService.onEvent(VlcEvent.TimeChanged, (event: VlcEventData) => {
      // While the user has paused, the position is the one the user set.
      if (this.left || this.userPaused || Date.now() < this.holdUntil) {
        return;
      }
      this.currentTime = event.time ?? 0;
    });
    vlcService.onEvent(VlcEvent.LengthChanged, () => {
      if (!this.left) {
        this.length = vlcService.getLength();
      }
    });
    vlcService.onEvent(VlcEvent.Playing, () => {
      if (!this.left) {
        this.onPlaying();
      }
    });
    vlcService.onEvent(VlcEvent.Paused, () => {
      if (!this.left) {
        this.playing = false;
        this.hideTimer.cancel();
        this.overlayVisible = true;
      }
    });
    vlcService.onEvent(VlcEvent.Stopped, () => {
      if (!this.left) {
        this.playing = false;
      }
    });
    vlcService.onEvent(VlcEvent.EndReached, () => {
      hilog.info(0x0001, TAG, 'end reached');
      this.leave(true, true);
    });
    vlcService.onEvent(VlcEvent.EncounteredError, () => {
      hilog.error(0x0001, TAG, 'engine error (played before: %{public}s)', `${this.hasPlayed}`);
      if (!this.hasPlayed) {
        this.fail();
      }
    });
  }

  private async loadMedia(): Promise<void> {
    const params: Record<string, Object> | undefined = router.getParams() as Record<string, Object> | undefined;
    const ctx: common.Context = this.getUIContext().getHostContext() as common.Context;
    const media: Media | null = await this.session.open(ctx, params);
    if (media === null) {
      this.fail();
      return;
    }
    this.title = this.session.displayTitle(media);
    this.isStream = media.isStream;
    this.resumeAt = await MediaStore.getInstance().resumePosition(media.id);
    this.length = media.length;
    this.videoWidth = media.width;
    this.videoHeight = media.height;
    this.applyResize();
    this.mediaLoaded = true;
    this.tryStart();
  }

  private tryStart(): void {
    if (this.started || !this.mediaLoaded || this.surfaceId.length === 0 || this.left) {
      return;
    }
    this.started = true;
    vlcService.play();
  }

  private async onPlaying(): Promise<void> {
    this.playing = true;
    this.userPaused = false;
    this.hasPlayed = true;
    const first: boolean = !this.recorded && this.session.mediaId >= 0;
    hilog.info(0x0001, TAG, 'playing (first %{public}s, resume %{public}d, engine time %{public}d)',
      `${first}`, this.resumeAt, vlcService.getTime());
    // The resume position was read before play(): seek at once, before the hide timer starts.
    if (first && this.resumeAt > 0) {
      this.holdUntil = Date.now() + SEEK_HOLD_MS;
      this.currentTime = this.resumeAt;
      vlcService.seekTo(this.resumeAt);
    }
    // The tap that opened the player is the last interaction: its timer keeps running.
    if (!this.hideTimer.pending) {
      this.armHide();
    }
    const size: VlcVideoSize = vlcService.getVideoSize();
    if (size.width > 0 && size.height > 0 && (this.videoWidth <= 0 || this.videoHeight <= 0)) {
      this.videoWidth = size.width;
      this.videoHeight = size.height;
      this.applyResize();
    }
    if (this.rate !== 1) {
      vlcService.setRate(this.rate);
    }
    if (!first) {
      return;
    }
    this.recorded = true;
    try {
      await MediaStore.getInstance().recordPlayback(this.session.mediaId);
    } catch (e) {
      hilog.error(0x0001, TAG, 'record failed: %{public}s', JSON.stringify(e));
    }
  }

  private fail(): void {
    if (this.left) {
      return;
    }
    const message: Resource = this.isStream ? $r('app.string.stream_error') : $r('app.string.file_error');
    this.getUIContext().getPromptAction().showToast({ message: message });
    this.leave(false, false);
  }

  private teardown(): void {
    this.left = true;
    this.hideTimer.cancel();
    this.infoTimer.cancel();
    this.session.close();
  }

  private async leave(save: boolean, atEnd: boolean): Promise<void> {
    if (this.left) {
      return;
    }
    const position: number = atEnd ? 0 : this.currentTime;
    const id: number = this.session.mediaId;
    this.teardown();
    if (save && id >= 0) {
      try {
        await MediaStore.getInstance().savePosition(id, position);
      } catch (e) {
        hilog.error(0x0001, TAG, 'save position failed: %{public}s', JSON.stringify(e));
      }
    }
    router.back();
  }

  private armHide(): void {
    this.hideTimer.cancel();
    if (!this.canHide() || !this.overlayVisible) {
      return;
    }
    this.hideTimer.start(HIDE_DELAY_MS, () => {
      if (this.canHide() && !this.showTracks && !this.showSpeed) {
        this.overlayVisible = false;
        this.autoShown = false;
      }
    });
  }

  private closeSheets(): void {
    if (this.canHide()) {
      this.overlayVisible = false;
    }
    this.showTracks = false;
    this.showSpeed = false;
  }

  /** A sheet was closed: as VLC, the picture comes back without the overlay, unless paused. */
  private onSheetClosed(): void {
    if (this.canHide()) {
      this.hideTimer.cancel();
      this.overlayVisible = false;
      this.autoShown = false;
    } else {
      this.armHide();
    }
  }

  /** The overlay hides while playing, and while the media is still opening; never while paused. */
  private canHide(): boolean {
    return this.playing || (!this.hasPlayed && !this.userPaused);
  }

  private toggleOverlay(): void {
    if (this.showTracks || this.showSpeed) {
      // A tap beside an open sheet closes it.
      this.closeSheets();
      return;
    }
    if (this.overlayVisible && this.autoShown) {
      // The overlay the player showed by itself at start: the first tap on the picture
      // is taken as a wish to use it, so it stays and its timer starts again.
      this.autoShown = false;
      this.armHide();
      return;
    }
    if (this.overlayVisible) {
      this.overlayVisible = false;
      this.hideTimer.cancel();
    } else {
      this.overlayVisible = true;
      this.armHide();
    }
  }

  private seekTo(ms: number): void {
    let target: number = Math.max(0, ms);
    if (this.length > 0) {
      target = Math.min(target, this.length);
    }
    this.holdUntil = Date.now() + SEEK_HOLD_MS;
    this.currentTime = target;
    vlcService.seekTo(target);
    this.armHide();
  }

  private step(sign: number): void {
    const seconds: number = SettingsStore.getInstance().current().videoJumpDelay;
    this.seekTo(this.currentTime + sign * seconds * 1000);
  }

  private togglePlay(): void {
    if (this.playing) {
      this.playing = false;
      this.userPaused = true;
      vlcService.setPause(true);
      this.hideTimer.cancel();
    } else {
      this.playing = true;
      this.userPaused = false;
      vlcService.play();
      this.armHide();
    }
  }

  private showInfo(name: string): void {
    const ctx: common.Context = this.getUIContext().getHostContext() as common.Context;
    this.infoText = ctx.resourceManager.getStringByNameSync(name);
    this.infoTimer.start(INFO_DELAY_MS, () => {
      this.infoText = '';
    });
  }

  private cycleResize(): void {
    this.resizeMode = (this.resizeMode + 1) % MODE_NAMES.length;
    this.applyResize();
    this.showInfo(MODE_NAMES[this.resizeMode]);
    this.armHide();
  }

  /** The surface covers the page: the engine places the picture in it for the resize mode. */
  private applyResize(): void {
    const layout: ModeLayout = modeLayoutOf(this.resizeMode, this.surfaceWidth, this.surfaceHeight,
      this.videoWidth, this.videoHeight);
    vlcService.setAspectRatio(layout.aspect);
    vlcService.setScale(layout.scale);
  }

  private applyRate(value: number): void {
    this.rate = FormatStore.getInstance().clampRate(value);
    vlcService.setRate(this.rate);
  }

  private openTracks(): void {
    const ctx: common.Context = this.getUIContext().getHostContext() as common.Context;
    this.audioItems = buildTrackItems(ctx, vlcService.audioTracks(), false);
    this.spuItems = buildTrackItems(ctx, vlcService.spuTracks(), true);
    this.audioSelected = vlcService.getAudioTrack();
    this.spuSelected = vlcService.getSpu();
    this.hideTimer.cancel();
    this.showTracks = true;
  }

  private selectAudio(id: number): void {
    vlcService.setAudioTrack(id);
    this.audioSelected = id;
  }

  private selectSubtitle(id: number): void {
    vlcService.setSpu(id);
    this.spuSelected = id;
    if (id >= 0) {
      this.seekTo(subtitleSeekTarget(vlcService.getTime()));
    }
  }

  @Builder
  overlayLayer() {
    Column() {
      if (this.locked) {
        Blank()
        PlayerLock({ onUnlock: () => {
          this.locked = false;
          this.armHide();
        } })
      } else {
        PlayerTopBar({
          title: this.title,
          speedText: this.rate !== 1 ? FormatStore.getInstance().formatRate(this.rate) : '',
          onBack: () => {
            this.leave(true, false);
          }
        })
        Blank()
        PlayerHud({
          timeText: FormatStore.getInstance().formatTime(this.currentTime),
          lengthText: this.showRemaining ? FormatStore.getInstance().formatTime(this.currentTime - this.length) :
          FormatStore.getInstance().formatTime(this.length),
          progress: this.currentTime,
          length: this.length,
          playing: this.playing,
          jumpText: `${SettingsStore.getInstance().current().videoJumpDelay}`,
          onSeekMoving: (ms: number) => {
            this.holdUntil = Date.now() + SEEK_HOLD_MS;
            this.currentTime = ms;
            this.hideTimer.cancel();
          },
          onSeekEnd: (ms: number) => this.seekTo(ms),
          onTogglePlay: () => this.togglePlay(),
          onRewind: () => this.step(-1),
          onForward: () => this.step(1),
          onLock: () => {
            this.locked = true;
            this.armHide();
          },
          onTracks: () => this.openTracks(),
          onResize: () => this.cycleResize(),
          onToggleLength: () => {
            this.showRemaining = !this.showRemaining;
          },
          onInteract: () => this.armHide(),
          onSpeed: () => {
            this.hideTimer.cancel();
            this.showSpeed = true;
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .visibility(this.showTracks || this.showSpeed ? Visibility.Hidden : Visibility.Visible)
    .onClick(() => this.toggleOverlay())
  }

  @Builder
  tracksSheet() {
    TracksSheet({
      audio: this.audioItems,
      subtitles: this.spuItems,
      audioSelected: this.audioSelected,
      subtitleSelected: this.spuSelected,
      onAudio: (id: number) => this.selectAudio(id),
      onSubtitle: (id: number) => this.selectSubtitle(id)
    })
  }

  @Builder
  speedSheet() {
    SpeedSheet({
      rate: this.rate,
      isStream: this.isStream,
      onRate: (value: number) => this.applyRate(value)
    })
  }

  build() {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        XComponent({
          id: 'video_layout',
          type: XComponentType.SURFACE,
          controller: this.controller
        })
          .id('video_layout')
          .width('100%')
          .height('100%')
          .onClick(() => this.toggleOverlay())

        if (this.overlayVisible) {
          this.overlayLayer()
        }
        if (this.infoText.length > 0) {
          PlayerInfoText({ text: this.infoText })
        }
      }
      .width('100%')
      .height('100%')
      .onAreaChange((oldArea: Area, newArea: Area) => {
        this.pageWidth = Number(newArea.width);
        this.pageHeight = Number(newArea.height);
      })
      .bindSheet(this.showTracks, this.tracksSheet(), playerSheetOptions(() => {
        this.showTracks = false;
        this.onSheetClosed();
      }, tracksSheetHeight(this.audioItems.length, this.spuItems.length, this.pageHeight)))
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.player_background'))
    .bindSheet(this.showSpeed, this.speedSheet(), playerSheetOptions(() => {
      this.showSpeed = false;
      this.onSheetClosed();
    }))
  }
}
