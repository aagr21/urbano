import { parse } from 'csv-parse';
import * as unzipper from 'unzipper';

export type GtfsRow = Record<string, string>;

/**
 * Lector streaming de archivos CSV dentro de un zip GTFS.
 * Tolerante a CRLF, BOM y columnas de más/de menos (relax_column_count).
 */
export class GtfsZipReader {
  private directory: unzipper.CentralDirectory | null = null;

  private constructor(private readonly zipPath: string) {}

  static async open(zipPath: string): Promise<GtfsZipReader> {
    const reader = new GtfsZipReader(zipPath);
    reader.directory = await unzipper.Open.file(zipPath);
    return reader;
  }

  /** Itera las filas de un .txt del zip en streaming. */
  async *rows(fileName: string): AsyncGenerator<GtfsRow> {
    if (!this.directory) {
      throw new Error('Zip no abierto');
    }
    const entry =
      this.directory.files.find((f) => f.path === fileName) ??
      this.directory.files.find((f) => f.path.replace(/^\.\//, '') === fileName);
    if (!entry) {
      throw new Error(`Archivo ${fileName} no encontrado en ${this.zipPath}`);
    }
    const parser = entry.stream().pipe(
      parse({
        columns: true,
        bom: true,
        skip_empty_lines: true,
        relax_column_count: true,
        relax_quotes: true,
        trim: true,
      }),
    );
    for await (const record of parser) {
      yield record as GtfsRow;
    }
  }
}

/** Helpers de conversión de campos GTFS. */
export const gtfs = {
  str(row: GtfsRow, key: string): string {
    return (row[key] ?? '').trim();
  },
  nullableStr(row: GtfsRow, key: string): string | null {
    const value = (row[key] ?? '').trim();
    return value === '' ? null : value;
  },
  num(row: GtfsRow, key: string): number {
    const value = (row[key] ?? '').trim();
    return value === '' ? 0 : Number(value);
  },
  nullableNum(row: GtfsRow, key: string): number | null {
    const value = (row[key] ?? '').trim();
    return value === '' ? null : Number(value);
  },
  bool01(row: GtfsRow, key: string): boolean {
    return (row[key] ?? '').trim() === '1';
  },
  int01(row: GtfsRow, key: string): number {
    const value = (row[key] ?? '').trim();
    return value === '' ? 0 : Number.parseInt(value, 10);
  },
};
