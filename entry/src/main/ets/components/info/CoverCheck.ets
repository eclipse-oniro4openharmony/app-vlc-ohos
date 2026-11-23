import { fileIo as fs } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

/** Least standard deviation of the luminance for a frame to count as a picture rather than a flat fill. */
const MIN_DEVIATION: number = 12;
/** Share of pixels that must differ clearly from the mean, so one stray pixel does not make a picture. */
const MIN_DETAIL_SHARE: number = 0.05;
const DETAIL_DELTA: number = 24;
const SAMPLE_WIDTH: number = 32;
const SAMPLE_HEIGHT: number = 18;

/** Luminance of each sampled pixel, read as RGBA 8888 whatever the decoder chose by default. */
async function lumaOf(pm: image.PixelMap): Promise<number[]> {
  const info: image.ImageInfo = await pm.getImageInfo();
  const bytesPerPixel: number = info.size.width > 0 && info.size.height > 0 ?
    Math.round(pm.getPixelBytesNumber() / (info.size.width * info.size.height)) : 0;
  if (bytesPerPixel !== 4) {
    hilog.warn(0x0001, 'VlcInfo', 'cover check: %{public}d bytes per pixel, not a frame to judge', bytesPerPixel);
    return [];
  }
  const buf: ArrayBuffer = new ArrayBuffer(pm.getPixelBytesNumber());
  await pm.readPixelsToBuffer(buf);
  const px: Uint8Array = new Uint8Array(buf);
  const out: number[] = [];
  for (let i = 0; i + 3 < px.length; i += 4) {
    // R, G and B weigh alike in the order-independent sum below, so RGBA and BGRA give the same flatness.
    out.push((px[i] + px[i + 1] + px[i + 2]) / 3);
  }
  return out;
}

/**
 * Whether the stored thumbnail is a real frame: it opens, decodes, and is not one flat colour
 * (a black or grey frame says nothing; VLC shows its cone then).
 */
export async function isUsableCover(pathOrUri: string): Promise<boolean> {
  if (pathOrUri.length === 0) {
    return false;
  }
  let file: fs.File | undefined = undefined;
  let source: image.ImageSource | undefined = undefined;
  let pm: image.PixelMap | undefined = undefined;
  try {
    file = fs.openSync(pathOrUri, fs.OpenMode.READ_ONLY);
    source = image.createImageSource(file.fd);
    pm = await source.createPixelMap({
      desiredSize: { width: SAMPLE_WIDTH, height: SAMPLE_HEIGHT },
      desiredPixelFormat: image.PixelMapFormat.RGBA_8888
    });
    const luma: number[] = await lumaOf(pm);
    if (luma.length === 0) {
      return false;
    }
    let sum: number = 0;
    for (const v of luma) {
      sum += v;
    }
    const mean: number = sum / luma.length;
    let variance: number = 0;
    let detailed: number = 0;
    for (const v of luma) {
      variance += (v - mean) * (v - mean);
      if (Math.abs(v - mean) > DETAIL_DELTA) {
        detailed++;
      }
    }
    const deviation: number = Math.sqrt(variance / luma.length);
    const share: number = detailed / luma.length;
    const usable: boolean = deviation >= MIN_DEVIATION && share >= MIN_DETAIL_SHARE;
    hilog.info(0x0001, 'VlcInfo', 'cover check mean %{public}d deviation %{public}d share %{public}d%% usable %{public}s',
      Math.round(mean), Math.round(deviation), Math.round(share * 100), String(usable));
    return usable;
  } catch (e) {
    hilog.warn(0x0001, 'VlcInfo', 'cover check failed: %{public}s', JSON.stringify(e));
    return false;
  } finally {
    if (pm !== undefined) {
      pm.release().catch((e: Error) => {
        hilog.warn(0x0001, 'VlcInfo', 'pixelmap release failed: %{public}s', JSON.stringify(e));
      });
    }
    if (source !== undefined) {
      source.release().catch((e: Error) => {
        hilog.warn(0x0001, 'VlcInfo', 'image source release failed: %{public}s', JSON.stringify(e));
      });
    }
    if (file !== undefined) {
      try {
        fs.closeSync(file);
      } catch (e) {
        hilog.warn(0x0001, 'VlcInfo', 'cover close failed: %{public}s', JSON.stringify(e));
      }
    }
  }
}
