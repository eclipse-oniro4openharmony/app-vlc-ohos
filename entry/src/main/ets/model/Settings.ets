@ObservedV2
export class Settings {
  @Trace videoResumePlayback: boolean = true;
  @Trace playbackHistory: boolean = true;
  @Trace videoJumpDelay: number = 10;
  @Trace appTheme: number = -1;
}
