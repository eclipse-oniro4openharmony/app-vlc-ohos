import { vlcService, VlcEvent, VlcEventData } from "../services/VlcService";
import vlcnative from "libvlcnative.so";

class VlcXComponentController extends XComponentController {
  onSurfaceCreated(surfaceId: string): void {
    vlcService.setNativeWindow(surfaceId);
  }

  onSurfaceChanged(surfaceId: string, rect: SurfaceRect): void {
    vlcService.setDisplaySize(rect.surfaceWidth, rect.surfaceHeight);
  }

  onSurfaceDestroyed(surfaceId: string): void {
    vlcService.setNativeWindow("");
  }
}

@Entry
@Component
struct PlayerPage {
  private xComponentId: string = "vlcXComponent";
  private xComponentController: VlcXComponentController = new VlcXComponentController();

  @State isPlaying: boolean = false;
  @State currentTime: number = 0;
  @State totalTime: number = 0;
  @State playbackPosition: number = 0;
  @State volume: number = 100;
  @State isControlsVisible: boolean = true;
  @State videoAspectRatio: number = 16 / 9;
  @State currentAspectRatioMode: number = 0;
  private aspectModes: string[] = ["Best Fit", "16:9", "4:3", "Fill", "Original"];

  private hideTimer: number = -1;

  setNextAspectRatio() {
    this.currentAspectRatioMode = (this.currentAspectRatioMode + 1) % this.aspectModes.length;
    const mode = this.aspectModes[this.currentAspectRatioMode];

    // Logic for mapping UI modes to VLC aspect/crop
    switch (mode) {
      case "Best Fit":
        vlcService.setAspectRatio("");
        vlcService.setCrop("");
        this.videoAspectRatio = 16 / 9; // Default or calculate from vlc content if possible
        break;
      case "16:9":
        vlcService.setAspectRatio("16:9");
        vlcService.setCrop("");
        this.videoAspectRatio = 16 / 9;
        break;
      case "4:3":
        vlcService.setAspectRatio("4:3");
        vlcService.setCrop("");
        this.videoAspectRatio = 4 / 3;
        break;
      case "Fill":
        vlcService.setAspectRatio("");
        vlcService.setCrop("16:9");
        this.videoAspectRatio = 16 / 9; // Example for fill
        break;
      case "Original":
        vlcService.setAspectRatio("");
        vlcService.setCrop("");
        const size = vlcService.getVideoSize();
        if (size.width > 0 && size.height > 0) {
          this.videoAspectRatio = size.width / size.height;
        }
        break;
    }
  }

  aboutToAppear(): void {
    // Provide a test video to play
    const testPath = "/data/storage/el2/base/haps/entry/files/Big_Buck_Bunny.mp4";
    vlcService.loadMedia(testPath);
    vlcService.play();
    this.isPlaying = true;

    // Attach events
    vlcService.onEvent(VlcEvent.TimeChanged, (event: VlcEventData) => {
      this.currentTime = event.time ?? 0;
    });

    vlcService.onEvent(VlcEvent.PositionChanged, (event: VlcEventData) => {
      this.playbackPosition = (event.position ?? 0) * 100;
    });

    vlcService.onEvent(VlcEvent.LengthChanged, () => {
      this.totalTime = vlcService.getLength();
    });

    vlcService.onEvent(VlcEvent.Playing, () => {
      this.isPlaying = true;
      const size = vlcService.getVideoSize();
      if (size.width > 0 && size.height > 0) {
        this.videoAspectRatio = size.width / size.height;
      }
    });

    vlcService.onEvent(VlcEvent.Paused, () => {
      this.isPlaying = false;
    });

    vlcService.onEvent(VlcEvent.Stopped, () => {
      this.isPlaying = false;
      this.currentTime = 0;
      this.playbackPosition = 0;
    });

    this.startHideTimer();
  }

  aboutToDisappear(): void {
    vlcService.destroy();
    if (this.hideTimer !== -1) {
      clearTimeout(this.hideTimer);
    }
  }

  formatTime(ms: number): string {
    const totalSeconds = Math.floor(ms / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return `${minutes.toString().padStart(2, "0")}:${seconds.toString().padStart(2, "0")}`;
  }

  startHideTimer() {
    if (this.hideTimer !== -1) {
      clearTimeout(this.hideTimer);
    }
    this.hideTimer = setTimeout(() => {
      this.isControlsVisible = false;
    }, 5000);
  }

  toggleControls() {
    this.isControlsVisible = !this.isControlsVisible;
    if (this.isControlsVisible) {
      this.startHideTimer();
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // Video Surface
      XComponent({
        id: this.xComponentId,
        type: XComponentType.SURFACE,
        controller: this.xComponentController,
      })
        .width("100%")
        .aspectRatio(this.videoAspectRatio)
        .backgroundColor(Color.Black)
        .align(Alignment.Center)
        .onClick(() => {
          this.toggleControls();
        })

      // Controls Overlay
      if (this.isControlsVisible) {
        Column() {
          // Top Bar (Optional: Title/Back)
          Row() {
            Image($r("app.media.startIcon"))
              // Placeholder for back icon
              .width(24)
              .height(24)
              .margin({ left: 16 })
              .onClick(() => {
                // Navigate back logic if needed
              })
            Text("VLC Player")
              .fontSize(18)
              .fontColor(Color.White)
              .margin({ left: 16 })
          }
          .width("100%")
          .height(56)
          .backgroundColor("#80000000")
          Blank()

          // Bottom Controls Block
          Column() {
            // Seekbar
            Row() {
              Text(this.formatTime(this.currentTime))
                .fontColor(Color.White)
                .fontSize(12)
                .margin({ right: 8 })
              Slider({
                value: this.playbackPosition,
                min: 0,
                max: 100,
                step: 0.1,
                style: SliderStyle.OutSet,
              })
                .blockColor("#FF6600")
                // VLC Orange
                .trackColor("#40FFFFFF")
                .selectedColor("#FF6600")
                .layoutWeight(1)
                .onChange((value: number, mode: SliderChangeMode) => {
                  if (mode === SliderChangeMode.End || mode === SliderChangeMode.Moving) {
                    this.playbackPosition = value;
                    vlcService.setPosition(value / 100);
                    this.startHideTimer();
                  }
                })
              Text(this.formatTime(this.totalTime))
                .fontColor(Color.White)
                .fontSize(12)
                .margin({ left: 8 })
            }
            .width("100%")
            .padding({ left: 16, right: 16 })

            // Playback Buttons
            Row() {
              // Backward 10s
              Button() {
                Text("<<")
                  .fontColor(Color.White)
                  .fontSize(20)
              }
              .type(ButtonType.Circle)
              .backgroundColor(Color.Transparent)
              .onClick(() => {
                vlcService.seekTo(Math.max(0, this.currentTime - 10000));
                this.startHideTimer();
              })

              // Play/Pause
              Button() {
                Text(this.isPlaying ? "||" : ">")
                  .fontColor(Color.White)
                  .fontSize(32)
                  .fontWeight(FontWeight.Bold)
              }
              .type(ButtonType.Circle)
              .width(64)
              .height(64)
              .margin({ left: 32, right: 32 })
              .backgroundColor("#CCFF6600")
              .onClick(() => {
                if (this.isPlaying) {
                  vlcService.pause();
                } else {
                  vlcService.play();
                }
                this.startHideTimer();
              })

              // Forward 10s
              Button() {
                Text(">>")
                  .fontColor(Color.White)
                  .fontSize(20)
              }
              .type(ButtonType.Circle)
              .backgroundColor(Color.Transparent)
              .onClick(() => {
                vlcService.seekTo(this.currentTime + 10000);
                this.startHideTimer();
              })
            }
            .width("100%")
            .justifyContent(FlexAlign.Center)
            .margin({ bottom: 16 })

            // Secondary Controls (Volume/Aspect)
            Row() {
              // Volume Icon (Simple text for now)
              Text("Vol")
                .fontColor(Color.White)
                .fontSize(14)
                .margin({ right: 8 })
              Slider({
                value: this.volume,
                min: 0,
                max: 100,
                style: SliderStyle.InSet,
              })
                .width(100)
                .blockColor(Color.White)
                .trackColor("#40FFFFFF")
                .selectedColor(Color.White)
                .onChange((value: number) => {
                  this.volume = value;
                  // TODO: Implement VolumeSet in NAPI if needed,
                  // but VLC usually handles internal volume.
                  this.startHideTimer();
                })
              Blank()
              Button(`Aspect: ${this.aspectModes[this.currentAspectRatioMode]}`)
                .fontSize(12)
                .backgroundColor("#40FFFFFF")
                .onClick(() => {
                  this.setNextAspectRatio();
                  this.startHideTimer();
                })
            }
            .width("100%")
            .padding({ left: 16, right: 16, bottom: 16 })
          }
          .width("100%")
          .backgroundColor("#80000000")
          .transition({ type: TransitionType.Insert, opacity: 1, translate: { y: 100 } })
          .transition({ type: TransitionType.Delete, opacity: 0, translate: { y: 100 } })
        }
        .width("100%")
        .height("100%");
      }
    }
    .width("100%")
    .height("100%")
    .backgroundColor(Color.Black);
  }
}
