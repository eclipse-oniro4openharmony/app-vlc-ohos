import { vlcService } from "../services/VlcService";
import vlcnative from "libvlcnative.so";

class VlcXComponentController extends XComponentController {
  onSurfaceCreated(surfaceId: string): void {
    vlcService.setNativeWindow(surfaceId);
  }

  onSurfaceChanged(surfaceId: string, rect: SurfaceRect): void {
    // Optional: Inform VLC of display size changes through a native API
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

  aboutToAppear(): void {
    // Provide a test video to play
    const testPath = "/data/storage/el2/base/haps/entry/files/I_am_legend.mp4";
    vlcService.loadMedia(testPath);
    vlcService.play();
  }

  aboutToDisappear(): void {
    vlcService.destroy();
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
