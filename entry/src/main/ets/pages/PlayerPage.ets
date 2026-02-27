import vlcnative from "libvlcnative.so";

class VlcXComponentController extends XComponentController {
  private player: vlcnative.VlcMediaPlayer | undefined = undefined;

  constructor() {
    super();
  }

  setPlayer(player: vlcnative.VlcMediaPlayer) {
    this.player = player;
  }

  onSurfaceCreated(surfaceId: string): void {
    if (this.player) {
      vlcnative.mediaPlayerSetNativeWindow(this.player, surfaceId);
    }
  }

  onSurfaceChanged(surfaceId: string, rect: SurfaceRect): void {
    // Optional: Inform VLC of display size changes through a native API
  }

  onSurfaceDestroyed(surfaceId: string): void {
    if (this.player) {
      vlcnative.mediaPlayerSetNativeWindow(this.player, "");
    }
  }
}

@Entry
@Component
struct PlayerPage {
  private xComponentId: string = "vlcXComponent";
  private vlcInstance: vlcnative.VlcInstance | undefined = undefined;
  private vlcMedia: vlcnative.VlcMedia | undefined = undefined;
  private player: vlcnative.VlcMediaPlayer | undefined = undefined;
  private xComponentController: VlcXComponentController = new VlcXComponentController();

  aboutToAppear(): void {
    const args: string[] = [
      "--verbose=2",
      "--plugin-path=/data/storage/el1/bundle/libs/arm64",
      "--vout=OHOSVout",
    ];
    this.vlcInstance = vlcnative.vlcNew(args);
    this.player = vlcnative.mediaPlayerNew(this.vlcInstance);
    this.xComponentController.setPlayer(this.player);

    // Provide a test video to play
    this.vlcMedia = vlcnative.mediaNewPath(
      this.vlcInstance,
      "/data/storage/el2/base/haps/entry/files/Big_Buck_Bunny.mp4",
    );
    vlcnative.mediaPlayerSetMedia(this.player, this.vlcMedia);
    vlcnative.mediaPlayerPlay(this.player);
  }

  aboutToDisappear(): void {
    if (this.player) {
      vlcnative.mediaPlayerStop(this.player);
      // Wait for release logic
      if (this.vlcMedia) {
        vlcnative.mediaRelease(this.vlcMedia);
        this.vlcMedia = undefined;
      }
      if (this.vlcInstance) {
        vlcnative.vlcRelease(this.vlcInstance);
      }
      this.player = undefined;
      this.vlcInstance = undefined;
    }
  }

  build() {
    Column() {
      XComponent({
        id: this.xComponentId,
        type: XComponentType.SURFACE,
        controller: this.xComponentController,
      })
        .width("100%")
        .aspectRatio(16 / 9)
    }
    .width("100%")
    .height("100%")
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Color.Black);
  }
}
