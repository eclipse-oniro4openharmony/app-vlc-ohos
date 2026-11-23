import { relationalStore } from '@kit.ArkData';
import type { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Media } from './Media';
import { SettingsStore } from './SettingsStore';

const CREATE_SQL: string = 'CREATE TABLE IF NOT EXISTS media (' +
  'id INTEGER PRIMARY KEY AUTOINCREMENT, uri TEXT NOT NULL UNIQUE, title TEXT NOT NULL DEFAULT \'\', ' +
  'isStream INTEGER NOT NULL DEFAULT 0, inVideos INTEGER NOT NULL DEFAULT 0, inStreams INTEGER NOT NULL DEFAULT 0, ' +
  'length INTEGER NOT NULL DEFAULT 0, width INTEGER NOT NULL DEFAULT 0, height INTEGER NOT NULL DEFAULT 0, ' +
  'size INTEGER NOT NULL DEFAULT 0, thumbnail TEXT NOT NULL DEFAULT \'\', lastPosition INTEGER NOT NULL DEFAULT 0, ' +
  'lastOpened INTEGER NOT NULL DEFAULT 0, lastPlayed INTEGER NOT NULL DEFAULT 0)';

export class MediaStore {
  private static instance: MediaStore | undefined = undefined;
  private store: relationalStore.RdbStore | undefined = undefined;
  private opening: Promise<relationalStore.RdbStore> | undefined = undefined;
  private context: common.Context | undefined = undefined;

  static getInstance(): MediaStore {
    if (MediaStore.instance === undefined) {
      MediaStore.instance = new MediaStore();
    }
    return MediaStore.instance;
  }

  init(context: common.Context): void {
    if (this.context === context && this.opening !== undefined) {
      return;
    }
    this.context = context;
    this.store = undefined;
    this.opening = this.open(context);
  }

  private async open(context: common.Context): Promise<relationalStore.RdbStore> {
    const config: relationalStore.StoreConfig = { name: 'vlc.db', securityLevel: relationalStore.SecurityLevel.S1 };
    const s: relationalStore.RdbStore = await relationalStore.getRdbStore(context, config);
    await s.executeSql(CREATE_SQL);
    this.store = s;
    return s;
  }

  private async db(): Promise<relationalStore.RdbStore> {
    if (this.store !== undefined) {
      return this.store;
    }
    if (this.opening === undefined) {
      throw new Error('MediaStore.init was not called');
    }
    return this.opening;
  }

  private async query(where: string, args: relationalStore.ValueType[], order: string): Promise<Media[]> {
    const s: relationalStore.RdbStore = await this.db();
    const sql: string = `SELECT * FROM media ${where.length > 0 ? 'WHERE ' + where : ''} ${order}`;
    const rs: relationalStore.ResultSet = await s.querySql(sql, args);
    const out: Media[] = [];
    try {
      while (rs.goToNextRow()) {
        const m: Media = new Media();
        m.id = rs.getLong(rs.getColumnIndex('id'));
        m.uri = rs.getString(rs.getColumnIndex('uri'));
        m.title = rs.getString(rs.getColumnIndex('title'));
        m.isStream = rs.getLong(rs.getColumnIndex('isStream')) !== 0;
        m.inVideos = rs.getLong(rs.getColumnIndex('inVideos')) !== 0;
        m.inStreams = rs.getLong(rs.getColumnIndex('inStreams')) !== 0;
        m.length = rs.getLong(rs.getColumnIndex('length'));
        m.width = rs.getLong(rs.getColumnIndex('width'));
        m.height = rs.getLong(rs.getColumnIndex('height'));
        m.size = rs.getLong(rs.getColumnIndex('size'));
        m.thumbnail = rs.getString(rs.getColumnIndex('thumbnail'));
        m.lastPosition = rs.getLong(rs.getColumnIndex('lastPosition'));
        m.lastOpened = rs.getLong(rs.getColumnIndex('lastOpened'));
        m.lastPlayed = rs.getLong(rs.getColumnIndex('lastPlayed'));
        out.push(m);
      }
    } finally {
      rs.close();
    }
    return out;
  }

  private async exec(sql: string, args: relationalStore.ValueType[]): Promise<void> {
    const s: relationalStore.RdbStore = await this.db();
    await s.executeSql(sql, args);
  }

  private removeThumbnail(path: string): void {
    if (path.length === 0) {
      return;
    }
    try {
      if (fileIo.accessSync(path)) {
        fileIo.unlinkSync(path);
      }
    } catch (e) {
      hilog.warn(0x0001, 'VlcMedia', 'thumbnail delete failed: %{public}s', JSON.stringify(e));
    }
  }

  /** Deletes the rows matching the condition, and their thumbnail files. */
  private async purge(where: string, args: relationalStore.ValueType[]): Promise<void> {
    const rows: Media[] = await this.query(where, args, '');
    for (const m of rows) {
      this.removeThumbnail(m.thumbnail);
    }
    await this.exec(`DELETE FROM media WHERE ${where}`, args);
  }

  async videos(): Promise<Media[]> {
    return this.query('inVideos = 1', [], 'ORDER BY title COLLATE NOCASE ASC, id ASC');
  }

  async addFile(uri: string): Promise<Media> {
    const known: Media | null = await this.findByUri(uri);
    if (known !== null) {
      await this.exec('UPDATE media SET inVideos = 1 WHERE id = ?', [known.id]);
      known.inVideos = true;
      return known;
    }
    await this.exec('INSERT INTO media (uri, title, isStream, inVideos) VALUES (?, ?, 0, 1)',
      [uri, this.titleFromUri(uri)]);
    const created: Media | null = await this.findByUri(uri);
    if (created === null) {
      throw new Error('insert failed');
    }
    return created;
  }

  async addStream(uri: string): Promise<Media> {
    const now: number = Date.now();
    const known: Media | null = await this.findByUri(uri);
    if (known !== null) {
      await this.exec('UPDATE media SET inStreams = 1, lastOpened = ? WHERE id = ?', [now, known.id]);
      known.inStreams = true;
      known.lastOpened = now;
      return known;
    }
    await this.exec('INSERT INTO media (uri, title, isStream, inStreams, lastOpened) VALUES (?, ?, 1, 1, ?)',
      [uri, this.titleFromUri(uri), now]);
    const created: Media | null = await this.findByUri(uri);
    if (created === null) {
      throw new Error('insert failed');
    }
    return created;
  }

  async get(id: number): Promise<Media | null> {
    const rows: Media[] = await this.query('id = ?', [id], '');
    return rows.length > 0 ? rows[0] : null;
  }

  async findByUri(uri: string): Promise<Media | null> {
    const rows: Media[] = await this.query('uri = ?', [uri], '');
    return rows.length > 0 ? rows[0] : null;
  }

  async describe(id: number, title: string, length: number, width: number, height: number,
    size: number): Promise<void> {
    const m: Media | null = await this.get(id);
    if (m === null) {
      return;
    }
    let newTitle: string = m.title;
    const looksLikeMrl: boolean = title.indexOf('://') >= 0 || /^\d+$/.test(title);
    if (title.length > 0 && !looksLikeMrl && title !== this.fileName(m.uri)) {
      newTitle = title;
    }
    await this.exec('UPDATE media SET title = ?, length = ?, width = ?, height = ?, size = ? WHERE id = ?',
      [newTitle, length, width, height, size, id]);
  }

  async setThumbnail(id: number, path: string): Promise<void> {
    await this.exec('UPDATE media SET thumbnail = ? WHERE id = ?', [path, id]);
  }

  async removeFromVideos(id: number): Promise<void> {
    await this.exec('UPDATE media SET inVideos = 0 WHERE id = ?', [id]);
    await this.purge('id = ? AND inVideos = 0 AND inStreams = 0 AND lastPlayed = 0', [id]);
  }

  async streams(): Promise<Media[]> {
    return this.query('inStreams = 1', [], 'ORDER BY lastOpened DESC, id DESC');
  }

  async removeStream(id: number): Promise<void> {
    await this.exec('UPDATE media SET inStreams = 0 WHERE id = ?', [id]);
    await this.purge('id = ? AND inVideos = 0 AND inStreams = 0 AND lastPlayed = 0', [id]);
  }

  async recordPlayback(id: number): Promise<void> {
    const now: number = Date.now();
    if (SettingsStore.getInstance().current().playbackHistory) {
      await this.exec('UPDATE media SET lastOpened = ?, lastPlayed = ? WHERE id = ?', [now, now, id]);
    } else {
      await this.exec('UPDATE media SET lastOpened = ? WHERE id = ?', [now, id]);
    }
  }

  async history(): Promise<Media[]> {
    if (!SettingsStore.getInstance().current().playbackHistory) {
      return [];
    }
    return this.query('lastPlayed > 0', [], 'ORDER BY lastPlayed DESC, id DESC');
  }

  async clearHistory(): Promise<void> {
    await this.exec('UPDATE media SET lastPlayed = 0, lastPosition = 0', []);
    await this.purge('inVideos = 0 AND inStreams = 0', []);
  }

  async savePosition(id: number, positionMs: number): Promise<void> {
    if (!SettingsStore.getInstance().current().videoResumePlayback) {
      return;
    }
    const m: Media | null = await this.get(id);
    if (m === null) {
      return;
    }
    let pos: number = Math.floor(positionMs);
    if (pos <= 0 || (m.length > 0 && pos >= m.length - 2000)) {
      pos = 0;
    }
    await this.exec('UPDATE media SET lastPosition = ? WHERE id = ?', [pos, id]);
  }

  async resumePosition(id: number): Promise<number> {
    if (!SettingsStore.getInstance().current().videoResumePlayback) {
      return 0;
    }
    const m: Media | null = await this.get(id);
    return m === null ? 0 : m.lastPosition;
  }

  /** Removes every row; used by tests to start from an empty table. */
  async clearAll(): Promise<void> {
    await this.exec('DELETE FROM media', []);
  }

  private decode(text: string): string {
    try {
      return decodeURIComponent(text);
    } catch (e) {
      return text;
    }
  }

  /** The decoded last path segment with its extension; empty when the uri has no path. */
  private fileName(uri: string): string {
    let rest: string = uri;
    const scheme: number = rest.indexOf('://');
    if (scheme >= 0) {
      rest = rest.substring(scheme + 3);
      const slash: number = rest.indexOf('/');
      if (slash < 0) {
        return '';
      }
      rest = rest.substring(slash);
    }
    const cut: number = rest.search(/[?#]/);
    if (cut >= 0) {
      rest = rest.substring(0, cut);
    }
    const last: number = rest.lastIndexOf('/');
    return this.decode(last >= 0 ? rest.substring(last + 1) : rest);
  }

  titleFromUri(uri: string): string {
    const name: string = this.fileName(uri);
    if (name.length === 0) {
      return uri;
    }
    const dot: number = name.lastIndexOf('.');
    const base: string = dot > 0 ? name.substring(0, dot) : name;
    return base.length > 0 ? base : uri;
  }
}
