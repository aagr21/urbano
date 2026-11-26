import {
  COMPLAINT_LIMITS,
  checkComment,
  checkNewComplaint,
  cleanAuthorName,
  photoObjectName,
} from './complaint-rules';

const jpg = (size = 1000) => ({ mimetype: 'image/jpeg', size });

describe('complaint-rules', () => {
  describe('checkNewComplaint', () => {
    const base = { routeId: '17', category: 'vehicle', photos: [] };

    it('acepta una queja válida y recorta la descripción', () => {
      expect(
        checkNewComplaint({ ...base, description: '  frenó tarde  ' })
      ).toEqual({
        ok: true,
        value: { description: 'frenó tarde' },
      });
    });

    it('sin descripción queda vacía (es opcional)', () => {
      expect(checkNewComplaint(base)).toEqual({
        ok: true,
        value: { description: '' },
      });
    });

    it.each([
      ['sin ruta', { ...base, routeId: '' }],
      ['categoría desconocida', { ...base, category: 'ruido' }],
    ])('rechaza %s', (_, input) => {
      expect(checkNewComplaint(input)).toEqual({
        ok: false,
        error: 'Ruta o categoría inválida',
      });
    });

    it('rechaza una descripción por encima del tope (contando ya recortada)', () => {
      const long = 'x'.repeat(COMPLAINT_LIMITS.descriptionChars + 1);
      expect(checkNewComplaint({ ...base, description: long }).ok).toBe(false);
      const justo = ` ${'x'.repeat(COMPLAINT_LIMITS.descriptionChars)} `;
      expect(checkNewComplaint({ ...base, description: justo }).ok).toBe(true);
    });

    it('rechaza más fotos de las permitidas', () => {
      const photos = Array.from({ length: COMPLAINT_LIMITS.photos + 1 }, () =>
        jpg()
      );
      expect(checkNewComplaint({ ...base, photos })).toEqual({
        ok: false,
        error: 'Puedes adjuntar hasta 5 fotos',
      });
    });

    it('rechaza un tipo no permitido aunque las demás fotos sean válidas', () => {
      const photos = [jpg(), { mimetype: 'image/gif', size: 10 }];
      expect(checkNewComplaint({ ...base, photos })).toEqual({
        ok: false,
        error: 'Solo se permiten JPG, PNG o WebP',
      });
    });

    it('rechaza una foto de más de 5 MB; justo 5 MB se acepta', () => {
      expect(
        checkNewComplaint({
          ...base,
          photos: [jpg(COMPLAINT_LIMITS.photoBytes + 1)],
        }).ok
      ).toBe(false);
      expect(
        checkNewComplaint({
          ...base,
          photos: [jpg(COMPLAINT_LIMITS.photoBytes)],
        }).ok
      ).toBe(true);
    });
  });

  describe('checkComment', () => {
    it('recorta y acepta', () => {
      expect(checkComment('  bien  ')).toEqual({ ok: true, value: 'bien' });
    });

    it('vacío o solo espacios no vale', () => {
      expect(checkComment('   ')).toEqual({
        ok: false,
        error: 'El comentario no puede estar vacío',
      });
      expect(checkComment(undefined).ok).toBe(false);
    });

    it('respeta el tope de caracteres', () => {
      expect(checkComment('x'.repeat(COMPLAINT_LIMITS.commentChars)).ok).toBe(
        true
      );
      expect(
        checkComment('x'.repeat(COMPLAINT_LIMITS.commentChars + 1)).ok
      ).toBe(false);
    });
  });

  describe('cleanAuthorName', () => {
    it('colapsa espacios y corta al tope', () => {
      expect(cleanAuthorName('  Ana   María ')).toBe('Ana María');
      expect(cleanAuthorName('x'.repeat(60))).toHaveLength(
        COMPLAINT_LIMITS.authorNameChars
      );
    });

    it('sin nombre útil devuelve null', () => {
      expect(cleanAuthorName(undefined)).toBeNull();
      expect(cleanAuthorName(' \n\t ')).toBeNull();
    });
  });

  it('photoObjectName es único por instante y conserva el nombre', () => {
    expect(photoObjectName(1700000000000, 'bus.jpg')).toBe(
      'complaints/1700000000000-bus.jpg'
    );
  });
});
