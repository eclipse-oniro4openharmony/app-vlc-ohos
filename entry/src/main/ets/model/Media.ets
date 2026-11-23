@ObservedV2
export class Media {
  @Trace id: number = 0;
  @Trace uri: string = '';
  @Trace title: string = '';
  @Trace isStream: boolean = false;
  @Trace inVideos: boolean = false;
  @Trace inStreams: boolean = false;
  @Trace length: number = 0;
  @Trace width: number = 0;
  @Trace height: number = 0;
  @Trace size: number = 0;
  @Trace thumbnail: string = '';
  @Trace lastPosition: number = 0;
  @Trace lastOpened: number = 0;
  @Trace lastPlayed: number = 0;
}
