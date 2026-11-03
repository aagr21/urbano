import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { put } from '@vercel/blob';
import 'multer';
import { Repository } from 'typeorm';
import { ComplaintComment } from '../entities/complaint-comment.entity';
import { ComplaintLike } from '../entities/complaint-like.entity';
import { Complaint } from '../entities/complaint.entity';
import { avatarColorFor, nicknameFor } from './passenger-identity';

const categories = new Set([
  'vehicle',
  'driver_treatment',
  'route_deviation',
  'schedule',
  'safety',
  'other',
]);

const MAX_COMMENT_LENGTH = 500;

@Injectable()
export class ComplaintsService {
  constructor(
    @InjectRepository(Complaint)
    private readonly complaints: Repository<Complaint>,
    @InjectRepository(ComplaintLike)
    private readonly likes: Repository<ComplaintLike>,
    @InjectRepository(ComplaintComment)
    private readonly comments: Repository<ComplaintComment>
  ) {}

  async list(deviceKey?: string) {
    const complaints = await this.complaints.find({
      where: [{ status: 'pending' }, { status: 'approved' }],
      order: { createdAt: 'DESC' },
      take: 100,
    });
    if (complaints.length === 0) return [];

    const ids = complaints.map((complaint) => complaint.id);
    const [likeCounts, commentCounts, mine] = await Promise.all([
      this.countBy(this.likes, 'complaint_id', ids),
      this.countBy(this.comments, 'complaint_id', ids),
      deviceKey
        ? this.likedIds(ids, deviceKey)
        : Promise.resolve(new Set<string>()),
    ]);

    return complaints.map((complaint) => ({
      id: complaint.id,
      routeId: complaint.routeId,
      category: complaint.category,
      description: complaint.description,
      photoUrls: complaint.photoUrls,
      status: complaint.status,
      createdAt: complaint.createdAt,
      likeCount: likeCounts.get(complaint.id) ?? 0,
      commentCount: commentCounts.get(complaint.id) ?? 0,
      likedByMe: mine.has(complaint.id),
    }));
  }

  async create(
    routeId: string,
    category: string,
    description = '',
    files: Express.Multer.File[]
  ): Promise<{ id: string; status: string }> {
    if (!routeId || !categories.has(category)) {
      throw new BadRequestException('Ruta o categoría inválida');
    }
    const text = description.trim();
    if (text.length > 2000) {
      throw new BadRequestException(
        'La descripción puede tener como máximo 2000 caracteres'
      );
    }
    if (files.length > 5) {
      throw new BadRequestException('Puedes adjuntar hasta 5 fotos');
    }

    const photoUrls: string[] = [];
    for (const file of files) {
      if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.mimetype)) {
        throw new BadRequestException('Solo se permiten JPG, PNG o WebP');
      }
      if (file.size > 5 * 1024 * 1024) {
        throw new BadRequestException('Cada foto puede pesar como máximo 5 MB');
      }
      if (!process.env.BLOB_READ_WRITE_TOKEN) {
        throw new BadRequestException('La subida de fotos no está configurada');
      }
      const blob = await put(
        `complaints/${Date.now()}-${file.originalname}`,
        file.buffer,
        {
          access: 'public',
          contentType: file.mimetype,
          token: process.env.BLOB_READ_WRITE_TOKEN,
        }
      );
      photoUrls.push(blob.url);
    }

    const complaint = await this.complaints.save({
      routeId,
      category,
      description: text,
      photoUrls,
      status: 'pending',
    });
    return { id: complaint.id, status: complaint.status };
  }

  // ------------------------------------------------------------------ likes

  async toggleLike(complaintId: string, deviceKey: string, liked: boolean) {
    await this.ensureComplaint(complaintId);
    if (!deviceKey) {
      throw new BadRequestException('Falta el identificador de dispositivo');
    }
    if (liked) {
      // `insert` con PK compuesta es idempotente si ya existe: ignoramos el
      // duplicado para que un doble toque no infle el contador.
      const exists = await this.likes.exist({
        where: { complaintId, deviceKey },
      });
      if (!exists) {
        await this.likes.insert({ complaintId, deviceKey });
      }
    } else {
      await this.likes.delete({ complaintId, deviceKey });
    }
    const likeCount = await this.likes.count({ where: { complaintId } });
    return { likeCount, likedByMe: liked };
  }

  // --------------------------------------------------------------- comments

  async listComments(complaintId: string) {
    await this.ensureComplaint(complaintId);
    const comments = await this.comments.find({
      where: { complaintId },
      order: { createdAt: 'ASC' },
      take: 200,
    });
    return comments.map((comment) => this.mapComment(comment));
  }

  async addComment(
    complaintId: string,
    deviceKey: string,
    body: string,
    authorName?: string
  ) {
    await this.ensureComplaint(complaintId);
    if (!deviceKey) {
      throw new BadRequestException('Falta el identificador de dispositivo');
    }
    const text = body.trim();
    if (text.length === 0) {
      throw new BadRequestException('El comentario no puede estar vacío');
    }
    if (text.length > MAX_COMMENT_LENGTH) {
      throw new BadRequestException(
        `El comentario puede tener como máximo ${MAX_COMMENT_LENGTH} caracteres`
      );
    }
    const saved = await this.comments.save({
      complaintId,
      deviceKey,
      authorName: this.sanitizeName(authorName, deviceKey),
      authorColor: avatarColorFor(deviceKey),
      body: text,
    });
    return this.mapComment(saved);
  }

  // ----------------------------------------------------------------- helpers

  private sanitizeName(authorName: string | undefined, deviceKey: string) {
    const clean = (authorName ?? '').replace(/\s+/g, ' ').trim().slice(0, 40);
    return clean.length > 0 ? clean : nicknameFor(deviceKey);
  }

  private mapComment(comment: ComplaintComment) {
    return {
      id: comment.id,
      complaintId: comment.complaintId,
      authorName: comment.authorName,
      authorColor: comment.authorColor,
      body: comment.body,
      createdAt: comment.createdAt,
    };
  }

  private async ensureComplaint(complaintId: string): Promise<void> {
    const found = await this.complaints.exist({ where: { id: complaintId } });
    if (!found) {
      throw new NotFoundException('La queja no existe');
    }
  }

  private async countBy(
    repo: Repository<{ complaintId?: string }>,
    column: 'complaint_id',
    ids: string[]
  ): Promise<Map<string, number>> {
    const rows: Array<{ complaint_id: string; total: string }> =
      await repo.query(
        `SELECT ${column} AS complaint_id, COUNT(*)::int AS total
         FROM ${repo.metadata.tableName}
         WHERE ${column} = ANY($1)
         GROUP BY ${column}`,
        [ids]
      );
    return new Map(rows.map((row) => [row.complaint_id, Number(row.total)]));
  }

  private async likedIds(
    ids: string[],
    deviceKey: string
  ): Promise<Set<string>> {
    const rows: Array<{ complaint_id: string }> = await this.likes.query(
      `SELECT complaint_id FROM complaint_like
       WHERE device_key = $2 AND complaint_id = ANY($1)`,
      [ids, deviceKey]
    );
    return new Set(rows.map((row) => row.complaint_id));
  }
}
