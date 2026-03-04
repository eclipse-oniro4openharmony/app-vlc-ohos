import { picker } from "@kit.CoreFileKit";
import { router } from "@kit.ArkUI";
import { common } from "@kit.AbilityKit";
import { hilog } from "@kit.PerformanceAnalysisKit";

const TAG = "IndexPage";
const DOMAIN = 0x0000;

@Entry
@Component
struct Index {
  @State message: string = "VLC for OpenHarmony";

  async selectFile() {
    try {
      let documentPicker = new picker.DocumentViewPicker(
        this.getUIContext().getHostContext() as common.UIAbilityContext,
      );
      let documentSelectOptions = new picker.DocumentSelectOptions();
      documentSelectOptions.maxSelectNumber = 1;
      documentSelectOptions.fileSuffixFilters = [
        ".mp4",
        ".mkv",
        ".avi",
        ".ts",
        ".flv",
        ".mp3",
        ".flac",
      ];

      let result = await documentPicker.select(documentSelectOptions);
      if (result && result.length > 0) {
        let uri = result[0];
        hilog.info(DOMAIN, TAG, "Selected file URI: %{public}s", uri);
        router.pushUrl({
          url: "pages/PlayerPage",
          params: {
            videoUri: uri,
          },
        });
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, "Failed to select file: %{public}s", JSON.stringify(err));
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // Background
      Column()
        .width("100%")
        .height("100%")
        .backgroundColor("#1A1A1A")
      Column() {
        Image($r("app.media.app_icon"))
          .width(120)
          .height(120)
          .margin({ bottom: 40 })
        Text(this.message)
          .fontSize(28)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 60 })
        Button("Open File")
          .width(240)
          .height(56)
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .backgroundColor("#FF6600")
          // VLC Orange
          .borderRadius(28)
          .onClick(() => {
            this.selectFile();
          })
        Text("Select a local media file to play")
          .fontSize(14)
          .fontColor("#80FFFFFF")
          .margin({ top: 16 })
      }.width("100%")
    }
    .height("100%")
    .width("100%");
  }
}
