import { Router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

class PlayerParams {
  mediaId: number = -1;
}

let pushing: boolean = false;

/**
 * Opens the player on one media. A second tap while the first push is under way,
 * or while the player is already on top, is ignored: two player pages would share
 * the one engine and the page underneath would be left without a player.
 */
export function openPlayer(router: Router, mediaId: number): void {
  if (pushing || router.getState()?.name === 'PlayerPage') {
    return;
  }
  pushing = true;
  const params: PlayerParams = new PlayerParams();
  params.mediaId = mediaId;
  router.pushUrl({ url: 'pages/PlayerPage', params: params }).catch((e: Error) => {
    hilog.error(0x0001, 'OpenPlayer', 'push failed: %{public}s', JSON.stringify(e));
  }).finally(() => {
    pushing = false;
  });
}
