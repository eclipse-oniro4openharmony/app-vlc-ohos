import { describe, it, expect } from '@ohos/hypium';
import { FormatStore } from '../../../main/ets/model/FormatStore';

export default function formatStoreTest() {
  describe('FormatStoreTest', () => {
    const f: FormatStore = FormatStore.getInstance();
    it('formatTime', 0, () => {
      expect(f.formatTime(0)).assertEqual('0:00');
      expect(f.formatTime(60000)).assertEqual('1:00');
      expect(f.formatTime(725000)).assertEqual('12:05');
      expect(f.formatTime(3723000)).assertEqual('1:02:03');
      expect(f.formatTime(-50000)).assertEqual('-0:50');
      expect(f.formatTime(1999)).assertEqual('0:01');
    })
    it('formatRate', 0, () => {
      expect(f.formatRate(1)).assertEqual('1.00x');
      expect(f.formatRate(1.5)).assertEqual('1.50x');
      expect(f.formatRate(0.8)).assertEqual('0.80x');
      expect(f.formatRate(2)).assertEqual('2.00x');
    })
    it('clampRate', 0, () => {
      expect(f.clampRate(0.1)).assertEqual(0.25);
      expect(f.clampRate(9)).assertEqual(4);
      expect(f.clampRate(1.234)).assertEqual(1.23);
    })
    it('resolutionClass', 0, () => {
      expect(f.resolutionClass(0, 720)).assertEqual('');
      expect(f.resolutionClass(1280, 720)).assertEqual('720p');
      expect(f.resolutionClass(1920, 1080)).assertEqual('1080p');
      expect(f.resolutionClass(2560, 1440)).assertEqual('1440p');
      expect(f.resolutionClass(3840, 2160)).assertEqual('4K');
      expect(f.resolutionClass(7680, 4320)).assertEqual('8K');
      expect(f.resolutionClass(640, 480)).assertEqual('SD');
    })
    it('formatSize', 0, () => {
      expect(f.formatSize(512)).assertEqual('512 B');
      expect(f.formatSize(1536)).assertEqual('1.5 KB');
      expect(f.formatSize(1258291)).assertEqual('1.2 MB');
    })
  })
}
