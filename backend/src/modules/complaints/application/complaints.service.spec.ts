import { BadRequestException, NotFoundException } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { COMPLAINT_PHOTO_STORAGE } from '../../../core/common/tokens';
import { ComplaintComment } from '../entities/complaint-comment.entity';
import { ComplaintLike } from '../entities/complaint-like.entity';
import { Complaint } from '../entities/complaint.entity';
import { PhotoStoragePort } from '../domain/photo-storage.port';
import { avatarColorFor, nicknameFor } from './passenger-identity';
import { ComplaintsService } from './complaints.service';

type Mocked<T> = { [K in keyof T]?: jest.Mock };

/** Almacenamiento de fotos en memoria: registra lo subido. */
class FakeStorage implements PhotoStoragePort {
  uploads: { name: string; contentType: string }[] = [];
  constructor(public configured = true) {}
  async upload(
    name: string,
    _data: Buffer,
    contentType: string
  ): Promise<string> {
    this.uploads.push({ name, contentType });
    return `https://blob.test/${name}`;
  }
}

const file = (name: string, mimetype = 'image/jpeg', size = 100) =>
  ({
    originalname: name,
    mimetype,
    size,
    buffer: Buffer.from('x'),
  }) as Express.Multer.File;

describe('ComplaintsService', () => {
  let complaints: Mocked<Repository<Complaint>>;
  let likes: Mocked<Repository<ComplaintLike>>;
  let comments: Mocked<Repository<ComplaintComment>>;
  let storage: FakeStorage;
  let service: ComplaintsService;

  beforeEach(() => {
    complaints = {
      find: jest.fn(),
      save: jest.fn(async (row) => ({ id: 'c1', ...row })),
      exist: jest.fn(async () => true),
    };
    likes = {
      exist: jest.fn(async () => false),
      insert: jest.fn(),
      delete: jest.fn(),
      count: jest.fn(async () => 3),
      query: jest.fn(),
    };
    comments = {
      find: jest.fn(),
      save: jest.fn(async (row) => ({
        id: 'k1',
        createdAt: new Date(0),
        ...row,
      })),
      query: jest.fn(),
    };
    storage = new FakeStorage();
    service = new ComplaintsService(
      complaints as unknown as Repository<Complaint>,
      likes as unknown as Repository<ComplaintLike>,
      comments as unknown as Repository<ComplaintComment>,
      storage
    );
    service.now = () => 42;
  });

  describe('create', () => {
    it('guarda la queja pendiente con la descripción recortada y las fotos subidas', async () => {
      const result = await service.create('17', 'vehicle', '  frenó tarde ', [
        file('a.jpg'),
        file('b.png', 'image/png'),
      ]);

      expect(result).toEqual({ id: 'c1', status: 'pending' });
      expect(storage.uploads).toEqual([
        { name: 'complaints/42-a.jpg', contentType: 'image/jpeg' },
        { name: 'complaints/42-b.png', contentType: 'image/png' },
      ]);
      expect(complaints.save).toHaveBeenCalledWith({
        routeId: '17',
        category: 'vehicle',
        description: 'frenó tarde',
        photoUrls: [
          'https://blob.test/complaints/42-a.jpg',
          'https://blob.test/complaints/42-b.png',
        ],
        status: 'pending',
      });
    });

    it('una foto inválida rechaza la queja SIN subir ninguna (antes quedaban huérfanas)', async () => {
      await expect(
        service.create('17', 'vehicle', '', [
          file('a.jpg'),
          file('b.gif', 'image/gif'),
        ])
      ).rejects.toThrow(
        new BadRequestException('Solo se permiten JPG, PNG o WebP')
      );
      expect(storage.uploads).toEqual([]);
      expect(complaints.save).not.toHaveBeenCalled();
    });

    it('sin almacenamiento configurado rechaza las fotos, pero acepta quejas sin fotos', async () => {
      storage.configured = false;
      await expect(
        service.create('17', 'vehicle', '', [file('a.jpg')])
      ).rejects.toThrow('La subida de fotos no está configurada');
      await expect(
        service.create('17', 'vehicle', undefined, [])
      ).resolves.toEqual({
        id: 'c1',
        status: 'pending',
      });
    });

    it('categoría inválida es un 400', async () => {
      await expect(
        service.create('17', 'ruido', '', [])
      ).rejects.toBeInstanceOf(BadRequestException);
    });
  });

  describe('list', () => {
    it('sin quejas no consulta contadores', async () => {
      complaints.find!.mockResolvedValue([]);
      await expect(service.list('dev')).resolves.toEqual([]);
      expect(likes.query).not.toHaveBeenCalled();
    });

    it('cruza apoyos, comentarios y lo que apoyó este dispositivo', async () => {
      complaints.find!.mockResolvedValue([
        {
          id: 'a',
          routeId: '1',
          category: 'vehicle',
          description: '',
          photoUrls: [],
          status: 'approved',
          createdAt: new Date(1),
        },
        {
          id: 'b',
          routeId: '2',
          category: 'safety',
          description: '',
          photoUrls: [],
          status: 'pending',
          createdAt: new Date(0),
        },
      ]);
      Object.assign(likes, { metadata: { tableName: 'complaint_like' } });
      Object.assign(comments, { metadata: { tableName: 'complaint_comment' } });
      likes
        .query!.mockResolvedValueOnce([{ complaint_id: 'a', total: '4' }]) // conteo de apoyos
        .mockResolvedValueOnce([{ complaint_id: 'b' }]); // apoyados por mí
      comments.query!.mockResolvedValue([{ complaint_id: 'b', total: '2' }]);

      const list = await service.list('dev');

      expect(
        list.map((c) => [c.id, c.likeCount, c.commentCount, c.likedByMe])
      ).toEqual([
        ['a', 4, 0, false],
        ['b', 0, 2, true],
      ]);
    });

    it('sin dispositivo nadie aparece como apoyado y no se consulta por él', async () => {
      complaints.find!.mockResolvedValue([
        {
          id: 'a',
          routeId: '1',
          category: 'vehicle',
          description: '',
          photoUrls: [],
          status: 'approved',
          createdAt: new Date(1),
        },
      ]);
      Object.assign(likes, { metadata: { tableName: 'complaint_like' } });
      Object.assign(comments, { metadata: { tableName: 'complaint_comment' } });
      likes.query!.mockResolvedValue([]);
      comments.query!.mockResolvedValue([]);

      const [only] = await service.list(undefined);

      expect(only.likedByMe).toBe(false);
      expect(likes.query).toHaveBeenCalledTimes(1);
    });
  });

  describe('toggleLike', () => {
    it('apoyar dos veces no duplica el apoyo', async () => {
      likes.exist!.mockResolvedValueOnce(false).mockResolvedValueOnce(true);
      await service.toggleLike('a', 'dev', true);
      await service.toggleLike('a', 'dev', true);
      expect(likes.insert).toHaveBeenCalledTimes(1);
    });

    it('quitar el apoyo borra el del dispositivo y devuelve el conteo', async () => {
      await expect(service.toggleLike('a', 'dev', false)).resolves.toEqual({
        likeCount: 3,
        likedByMe: false,
      });
      expect(likes.delete).toHaveBeenCalledWith({
        complaintId: 'a',
        deviceKey: 'dev',
      });
    });

    it('queja inexistente es 404; sin dispositivo es 400', async () => {
      complaints.exist!.mockResolvedValueOnce(false);
      await expect(service.toggleLike('x', 'dev', true)).rejects.toBeInstanceOf(
        NotFoundException
      );
      await expect(service.toggleLike('a', '', true)).rejects.toBeInstanceOf(
        BadRequestException
      );
    });
  });

  describe('addComment', () => {
    it('sin apodo usa el derivado del dispositivo, con su color', async () => {
      const saved = await service.addComment('a', 'dev-1', '  hola ', '   ');
      expect(saved).toMatchObject({
        body: 'hola',
        authorName: nicknameFor('dev-1'),
        authorColor: avatarColorFor('dev-1'),
      });
    });

    it('con apodo lo limpia', async () => {
      const saved = await service.addComment(
        'a',
        'dev-1',
        'hola',
        '  Ana   María '
      );
      expect(saved.authorName).toBe('Ana María');
    });

    it('comentario vacío es 400 y no se guarda', async () => {
      await expect(service.addComment('a', 'dev', '  ')).rejects.toThrow(
        'El comentario no puede estar vacío'
      );
      expect(comments.save).not.toHaveBeenCalled();
    });
  });

  it('Nest lo construye con sus repositorios y el puerto de fotos', async () => {
    const moduleRef = await Test.createTestingModule({
      providers: [
        ComplaintsService,
        { provide: getRepositoryToken(Complaint), useValue: complaints },
        { provide: getRepositoryToken(ComplaintLike), useValue: likes },
        { provide: getRepositoryToken(ComplaintComment), useValue: comments },
        { provide: COMPLAINT_PHOTO_STORAGE, useValue: storage },
      ],
    }).compile();
    expect(moduleRef.get(ComplaintsService)).toBeInstanceOf(ComplaintsService);
  });
});
