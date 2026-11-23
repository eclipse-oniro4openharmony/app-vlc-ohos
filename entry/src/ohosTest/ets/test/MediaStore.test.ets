import { describe, it, expect, beforeEach } from '@ohos/hypium';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { MediaStore } from '../../../main/ets/model/MediaStore';
import { SettingsStore } from '../../../main/ets/model/SettingsStore';
import { Media } from '../../../main/ets/model/Media';

const URI_A: string = 'file://docs/storage/Users/currentUser/Download/banana.mp4';
const URI_B: string = 'file://docs/storage/Users/currentUser/Download/Apple%20pie.mkv';
const URL_S: string = 'http://example.com/media/sample_clip.mp4';

function titles(list: Media[]): string[] {
  return list.map((m: Media) => m.title);
}

export default function mediaStoreTest() {
  describe('MediaStoreTest', () => {
    const store: MediaStore = MediaStore.getInstance();
    beforeEach(async () => {
      const ctx = abilityDelegatorRegistry.getAbilityDelegator().getAppContext().getApplicationContext();
      SettingsStore.getInstance().init(ctx);
      await SettingsStore.getInstance().setPlaybackHistory(true);
      await SettingsStore.getInstance().setVideoResumePlayback(true);
      store.init(ctx);
      await store.clearAll();
    })
    it('titleFromUri', 0, () => {
      expect(store.titleFromUri('file://docs/storage/Users/currentUser/Download/sample_clip.mp4')).assertEqual('sample_clip');
      expect(store.titleFromUri(URL_S)).assertEqual('sample_clip');
      expect(store.titleFromUri(URI_B)).assertEqual('Apple pie');
      expect(store.titleFromUri('http://host')).assertEqual('http://host');
    })
    it('addAndDedupe', 0, async () => {
      const a: Media = await store.addFile(URI_A);
      expect(a.id > 0).assertTrue();
      expect(a.title).assertEqual('banana');
      expect(a.inVideos).assertTrue();
      const again: Media = await store.addFile(URI_A);
      expect(again.id).assertEqual(a.id);
      expect((await store.videos()).length).assertEqual(1);
      expect((await store.findByUri(URI_A))?.id).assertEqual(a.id);
      expect(await store.findByUri('nothing')).assertEqual(null);
      expect(await store.get(99999)).assertEqual(null);
    })
    it('videosOrder', 0, async () => {
      await store.addFile(URI_A);
      await store.addFile(URI_B);
      expect(titles(await store.videos()).join(',')).assertEqual('Apple pie,banana');
    })
    it('streamsOrderAndRemove', 0, async () => {
      const s1: Media = await store.addStream('http://a/one.mp4');
      await new Promise<void>((resolve: () => void) => setTimeout(resolve, 5));
      await store.addStream('http://a/two.mp4');
      expect(titles(await store.streams()).join(',')).assertEqual('two,one');
      await store.removeStream(s1.id);
      expect((await store.streams()).length).assertEqual(1);
      expect(await store.get(s1.id)).assertEqual(null);
    })
    it('historyOrderAndSetting', 0, async () => {
      const a: Media = await store.addFile(URI_A);
      const b: Media = await store.addFile(URI_B);
      await store.recordPlayback(a.id);
      await new Promise<void>((resolve: () => void) => setTimeout(resolve, 5));
      await store.recordPlayback(b.id);
      expect(titles(await store.history()).join(',')).assertEqual('Apple pie,banana');
      await SettingsStore.getInstance().setPlaybackHistory(false);
      expect((await store.history()).length).assertEqual(0);
      await SettingsStore.getInstance().setPlaybackHistory(true);
      expect((await store.history()).length).assertEqual(2);
    })
    it('clearHistory', 0, async () => {
      const a: Media = await store.addFile(URI_A);
      const s: Media = await store.addStream(URL_S);
      await store.removeStream(s.id);
      const s2: Media = await store.addStream(URL_S);
      await store.recordPlayback(a.id);
      await store.recordPlayback(s2.id);
      await store.removeStream(s2.id);
      expect(await store.get(s2.id) !== null).assertTrue();
      await store.clearHistory();
      expect((await store.history()).length).assertEqual(0);
      expect(await store.get(s2.id)).assertEqual(null);
      expect(await store.get(a.id) !== null).assertTrue();
    })
    it('positions', 0, async () => {
      const a: Media = await store.addFile(URI_A);
      await store.describe(a.id, '', 60000, 1280, 720, 1000);
      await store.savePosition(a.id, 20000);
      expect(await store.resumePosition(a.id)).assertEqual(20000);
      await store.savePosition(a.id, 59000);
      expect(await store.resumePosition(a.id)).assertEqual(0);
      await store.savePosition(a.id, 20000);
      await SettingsStore.getInstance().setVideoResumePlayback(false);
      await store.savePosition(a.id, 30000);
      expect(await store.resumePosition(a.id)).assertEqual(0);
      await SettingsStore.getInstance().setVideoResumePlayback(true);
      expect(await store.resumePosition(a.id)).assertEqual(20000);
      expect(await store.resumePosition(12345)).assertEqual(0);
    })
    it('describeIgnoresMrlTitle', 0, async () => {
      const a: Media = await store.addFile(URI_A);
      await store.describe(a.id, 'fd://46', 5000, 640, 480, 10);
      const got: Media | null = await store.get(a.id);
      expect(got?.title).assertEqual('banana');
      expect(got?.length).assertEqual(5000);
    })
    it('describeKeepsTitle', 0, async () => {
      const a: Media = await store.addFile(URI_A);
      await store.describe(a.id, 'banana.mp4', 5000, 640, 480, 10);
      let got: Media | null = await store.get(a.id);
      expect(got?.title).assertEqual('banana');
      expect(got?.length).assertEqual(5000);
      await store.describe(a.id, 'Real title', 5000, 640, 480, 10);
      got = await store.get(a.id);
      expect(got?.title).assertEqual('Real title');
    })
  })
}
