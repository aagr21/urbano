import { parse } from "csv-parse/sync";
import { existsSync } from "fs";
import { copyFile, writeFile } from "fs/promises";
import * as unzipper from "unzipper";
import { deflateRawSync } from "zlib";

/**
 * Escritor/lector mínimo de zip para reescribir el feed GTFS.
 *
 * `unzipper` solo expone lectura, y el feed es pequeño (los 9 .txt caben en
 * unos pocos MB en memoria), así que el contenedor zip se implementa aquí en
 * vez de añadir una dependencia nueva. Los CSV se comprimen con DEFLATE
 * (método 8), que es lo que esperan OTP y el importador.
 */

export type CsvRow = Record<string, string>;

const CRC_POLYNOMIAL = 0xed_b8_83_20;
let crcTable: Uint32Array | null = null;

function crcTableLazy(): Uint32Array {
    if (crcTable) return crcTable;
    const table = new Uint32Array(256);
    for (let i = 0; i < 256; i++) {
        let c = i;
        for (let k = 0; k < 8; k++) {
            c = c & 1 ? (c >>> 1) ^ CRC_POLYNOMIAL : c >>> 1;
        }
        table[i] = c >>> 0;
    }
    crcTable = table;
    return table;
}

function crc32(buf: Buffer): number {
    const table = crcTableLazy();
    let crc = 0xff_ff_ff_ff;
    for (const byte of buf) {
        crc = table[(crc ^ byte) & 0xff]! ^ (crc >>> 8);
    }
    return (crc ^ 0xff_ff_ff_ff) >>> 0;
}

/** Fecha DOS fija (1980-01-01) para que el zip sea determinista byte a byte. */
const DOS_TIME = 0;
const DOS_DATE = 0x0021;

export interface ZipEntry {
    name: string;
    data: Buffer;
}

/** Escribe las entradas como un zip válido en una sola pasada. */
export async function writeZipEntries(path: string, entries: ZipEntry[]): Promise<void> {
    const chunks: Buffer[] = [];
    const central: Buffer[] = [];
    let offset = 0;

    for (const entry of entries) {
        const name = Buffer.from(entry.name, "utf8");
        const compressed = deflateRawSync(entry.data, { level: 9 });
        const crc = crc32(entry.data);

        const local = Buffer.alloc(30);
        local.writeUInt32LE(0x04_03_4b_50, 0);
        local.writeUInt16LE(20, 4); // versión necesaria
        local.writeUInt16LE(0, 6); // flags
        local.writeUInt16LE(8, 8); // método: deflate
        local.writeUInt16LE(DOS_TIME, 10);
        local.writeUInt16LE(DOS_DATE, 12);
        local.writeUInt32LE(crc, 14);
        local.writeUInt32LE(compressed.length, 18);
        local.writeUInt32LE(entry.data.length, 22);
        local.writeUInt16LE(name.length, 26);
        local.writeUInt16LE(0, 28); // longitud de "extra"

        chunks.push(local, name, compressed);

        const record = Buffer.alloc(46);
        record.writeUInt32LE(0x02_01_4b_50, 0);
        record.writeUInt16LE(20, 4); // versión creadora
        record.writeUInt16LE(20, 6); // versión necesaria
        record.writeUInt16LE(0, 8); // flags
        record.writeUInt16LE(8, 10); // método
        record.writeUInt16LE(DOS_TIME, 12);
        record.writeUInt16LE(DOS_DATE, 14);
        record.writeUInt32LE(crc, 16);
        record.writeUInt32LE(compressed.length, 20);
        record.writeUInt32LE(entry.data.length, 24);
        record.writeUInt16LE(name.length, 28);
        record.writeUInt16LE(0, 30); // extra
        record.writeUInt16LE(0, 32); // comentario
        record.writeUInt16LE(0, 34); // disco
        record.writeUInt16LE(0, 36); // atributos internos
        record.writeUInt32LE(0, 38); // atributos externos
        record.writeUInt32LE(offset, 42); // desplazamiento de la cabecera local
        central.push(record, name);

        offset += local.length + name.length + compressed.length;
    }

    const centralSize = central.reduce((acc, b) => acc + b.length, 0);
    const eocd = Buffer.alloc(22);
    eocd.writeUInt32LE(0x06_05_4b_50, 0);
    eocd.writeUInt16LE(0, 4); // disco actual
    eocd.writeUInt16LE(0, 6); // disco del directorio central
    eocd.writeUInt16LE(entries.length, 8); // entradas en este disco
    eocd.writeUInt16LE(entries.length, 10); // entradas totales
    eocd.writeUInt32LE(centralSize, 12); // tamaño del directorio central
    eocd.writeUInt32LE(offset, 16); // desplazamiento del directorio central
    eocd.writeUInt16LE(0, 20); // longitud del comentario

    await writeFile(path, Buffer.concat([...chunks, ...central, eocd]));
}

/** Lee todas las entradas de un zip en memoria (nombre → contenido). */
export async function readZipEntries(path: string): Promise<Map<string, Buffer>> {
    const directory = await unzipper.Open.file(path);
    const out = new Map<string, Buffer>();
    for (const file of directory.files) {
        if (file.type !== "File") continue;
        const buffer = await file.buffer();
        out.set(file.path.replace(/^\.\//, ""), buffer);
    }
    return out;
}

/** Parseo síncrono de CSV (el feed completo son pocos MB: cabe en memoria). */
export function parseCsv(data: Buffer): { header: string[]; rows: CsvRow[] } {
    const rows = parse(data, {
        columns: true,
        bom: true,
        skip_empty_lines: true,
        relax_column_count: true,
        relax_quotes: true,
        trim: true,
    }) as CsvRow[];
    const header = rows.length > 0 ? Object.keys(rows[0]) : [];
    return { header, rows };
}

const NEEDS_QUOTE = /[",\n\r]/;

function escapeField(value: string): string {
    if (value === "") return "";
    return NEEDS_QUOTE.test(value) ? `"${value.replace(/"/g, '""')}"` : value;
}

/** Serializa filas CSV con las cabeceras originales (saltos de línea LF). */
export function toCsv(header: string[], rows: CsvRow[]): Buffer {
    const lines: string[] = [header.join(",")];
    for (const row of rows) {
        lines.push(header.map(key => escapeField(row[key] ?? "")).join(","));
    }
    return Buffer.from(`${lines.join("\n")}\n`, "utf8");
}

/** Copia de seguridad del zip original (este repo no está versionado con git). */
export async function backupFile(from: string, to: string): Promise<boolean> {
    if (existsSync(to)) return false; // nunca sobrescribir el respaldo
    await copyFile(from, to);
    return true;
}
