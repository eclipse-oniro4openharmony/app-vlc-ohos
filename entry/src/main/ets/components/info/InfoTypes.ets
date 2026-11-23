export class InfoLine {
  label: Resource = $r('app.string.codec');
  value: string = '';
}

/** kind: 0 video, 1 audio, 2 subtitle. */
export class TrackGroup {
  kind: number = 0;
  label: string = '';
  lines: InfoLine[] = [];
}

export function makeLine(label: Resource, value: string): InfoLine {
  const l: InfoLine = new InfoLine();
  l.label = label;
  l.value = value;
  return l;
}
