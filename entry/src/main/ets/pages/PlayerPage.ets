import { vlcService, VlcEvent, VlcEventData } from "../services/VlcService";
import vlcnative from "libvlcnative.so";
import { router, window } from "@kit.ArkUI";
import { fileIo as fs } from "@kit.CoreFileKit";
import { BusinessError } from "@kit.BasicServicesKit";

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
  @State videoTitle: string = "VLC Player";
  @State isLandscape: boolean = false;
  private aspectModes: string[] = ["Best Fit", "16:9", "4:3", "Fill", "Original"];

  private hideTimer: number = -1;

  toggleRotation() {
    this.isLandscape = !this.isLandscape;
    window.getLastWindow(getContext(this), (err: BusinessError, data) => {
      const errCode: number = err.code;
      if (errCode) {
        console.error("Failed to get last window. Cause: " + JSON.stringify(err));
        return;
      }
      let orientation = this.isLandscape
        ? window.Orientation.LANDSCAPE
        : window.Orientation.PORTRAIT;
      data.setPreferredOrientation(orientation, (err) => {
        if (err.code) {
          console.error("Failed to set orientation. Cause: " + JSON.stringify(err));
        }
      });
    });
  }

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
        vlcService.setCrop("");
        this.videoAspectRatio = 0; // 0 removes the aspect ratio constraint for full stretch
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
    // Retrieve URI from router params
    const params = router.getParams() as Record<string, string>;
    const videoUri = params?.videoUri;

    // Provide a test video to play as fallback
    const testPath = "/data/storage/el2/base/haps/entry/files/Big_Buck_Bunny.mp4";
    const pathToPlay = videoUri || testPath;

    // Extract title from path
    try {
      const parts = pathToPlay.split("/");
      let fileName = parts[parts.length - 1];
      try {
        fileName = decodeURIComponent(fileName);
      } catch (e) {
        // Fallback if decoding fails
      }
      
      // Optional: remove extension
      const lastDotIndex = fileName.lastIndexOf(".");
      if (lastDotIndex > 0) {
        this.videoTitle = fileName.substring(0, lastDotIndex);
      } else {
        this.videoTitle = fileName;
      }
    } catch (e) {
      this.videoTitle = "VLC Player";
    }

    if (pathToPlay.startsWith("file://") || pathToPlay.startsWith("datashare://")) {
      try {
        const file = fs.openSync(pathToPlay, fs.OpenMode.READ_ONLY);
        vlcService.loadMediaFd(file.fd);
      } catch (e) {
        const error = e as Error;
        console.error(`Failed to open file: ${pathToPlay}`, error.message);
        // Fallback to path if openSync fails (might happen for some URIs)
        vlcService.loadMedia(pathToPlay);
      }
    } else {
      vlcService.loadMedia(pathToPlay);
    }

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

  onBackPress(): boolean | void {
    vlcService.destroy();
    if (this.hideTimer !== -1) {
      clearTimeout(this.hideTimer);
      this.hideTimer = -1;
    }
    // Restore orientation if back is pressed
    window.getLastWindow(getContext(this), (err, data) => {
      if (!err.code) {
        data.setPreferredOrientation(window.Orientation.AUTO_ROTATION_UNSPECIFIED);
      }
    });
  }

  aboutToDisappear(): void {
    // Calling destroy again is safe (it checks if this.player exists)
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
        .height(this.videoAspectRatio === 0 ? "100%" : "auto")
        .aspectRatio(this.videoAspectRatio === 0 ? 0 : this.videoAspectRatio)
        .backgroundColor(Color.Black)
        .align(Alignment.Center)
        .onClick(() => {
          this.toggleControls();
        })

      // Controls Overlay
      if (this.isControlsVisible) {
        Column() {
          // Top Bar Layout
          Row() {
            // Optional: Back icon (could add later)
            // Empty space so the text can be centered easily via flex properties or absolute pos if needed
            Text(this.videoTitle)
              .fontSize(18)
              .fontColor(Color.White)
              .fontWeight(FontWeight.Medium)
              .textAlign(TextAlign.Center)
              .layoutWeight(1)
          }
          .width("100%")
          .height(56)
          .margin({ top: 16 })
          // No background as requested, floating at top

          Blank() // Fills space between top title and bottom controls

          // Bottom Controls Block
          Column() {
            // Progress Bar and Time Layout
            Column() {
              // Time Indicators above slider
              Row() {
                Text(this.formatTime(this.currentTime))
                  .fontColor(Color.White)
                  .fontSize(14)
                Blank()

                // Represent remaining time e.g. -1:12
                Text(`-${this.formatTime(this.totalTime - this.currentTime)}`)
                  .fontColor(Color.White)
                  .fontSize(14)
              }
              .width("100%")
              .padding({ left: 16, right: 16, bottom: 4 })

              // Slider spanning full width below time
              Slider({
                value: this.playbackPosition,
                min: 0,
                max: 100,
                step: 0.1,
                style: SliderStyle.OutSet,
              })
                .blockColor("#FF6600")
                .trackColor("#40FFFFFF")
                .selectedColor("#FF6600")
                .trackThickness(4)
                .width("100%")
                // Edge-to-edge
                .padding({ left: 8, right: 8 })
                // Optional padding
                .onChange((value: number, mode: SliderChangeMode) => {
                  if (mode === SliderChangeMode.End || mode === SliderChangeMode.Moving) {
                    this.playbackPosition = value;
                    vlcService.setPosition(value / 100);
                    this.startHideTimer();
                  }
                })
            }
            .width("100%")
            .margin({ top: 8 })

            // Bottom Buttons Row
            Row() {
              // Subtitles Icon
              Image($r("app.media.ic_subtitles"))
                .width(32)
                .height(32)
                .padding(4)
                .fillColor(Color.White)
                .onClick(() => {
                  this.startHideTimer();
                })

              // Rotation Icon
              Image($r("app.media.ic_player_rotate"))
                .width(32)
                .height(32)
                .padding(4)
                .fillColor(Color.White)
                .margin({ left: 16 })
                .onClick(() => {
                  this.toggleRotation();
                  this.startHideTimer();
                })
              Blank()

              // Center Play/Pause
              Button() {
                Image(
                  this.isPlaying ? $r("app.media.ic_pause_player") : $r("app.media.ic_play_player"),
                )
                  .width(48)
                  .height(48)
                  .fillColor(Color.White)
              }
              .type(ButtonType.Circle)
              .width(64)
              .height(64)
              .margin({ left: 32, right: 32 })
              .backgroundColor(Color.Transparent)
              .onClick(() => {
                if (this.isPlaying) {
                  vlcService.pause();
                } else {
                  vlcService.play();
                }
                this.startHideTimer();
              })
              Blank()

              // Aspect Ratio Icon
              Image($r("app.media.ic_player_ratio"))
                .width(32)
                .height(32)
                .padding(4)
                .fillColor(Color.White)
                .onClick(() => {
                  this.setNextAspectRatio();
                  this.startHideTimer();
                })

              // More Options (Ellipsis)
              Text("...")
                .fontColor(Color.White)
                .fontSize(24)
                .padding(8)
                .margin({ left: 16 })
                .onClick(() => {
                  this.startHideTimer();
                })
            }
            .width("100%")
            .padding({ left: 16, right: 16, top: 8, bottom: 24 })
            .alignItems(VerticalAlign.Center)
          }
          .width("100%")
          // Gradient Background at bottom for text visibility
          .linearGradient({
            direction: GradientDirection.Top,
            colors: [
              ["#99000000", 0.0],
              ["#66000000", 0.5],
              ["#00000000", 1.0],
            ],
          })
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
