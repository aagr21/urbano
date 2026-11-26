import 'package:flutter_test/flutter_test.dart';
import 'package:urbano/src/features/complaints/application/complaint_photos.dart';
import 'package:urbano/src/features/complaints/presentation/widgets/complaint_form_parts.dart';
import 'package:urbano/src/features/routes/data/route_models.dart';

RouteSummary _route({String longName = ''}) => RouteSummary(
  id: '17',
  shortName: '17',
  longName: longName,
  color: '7F8C8D',
  textColor: 'FFFFFF',
  description: '',
  type: 3,
  directionsCount: 2,
  stopCount: 10,
  tripCount: 2,
);

/// Reglas del formulario de denuncia, sin widgets ni plugins.
void main() {
  group('fotos', () {
    test('cabe otra foto solo por debajo del tope', () {
      expect(canAddComplaintPhoto(maxComplaintPhotos - 1), isTrue);
      expect(canAddComplaintPhoto(maxComplaintPhotos), isFalse);
    });

    test('sumar fotos respeta el tope y conserva el orden', () {
      final merged = appendComplaintPhotos([1, 2, 3], [4, 5, 6, 7]);
      expect(merged, [1, 2, 3, 4, 5]);
    });

    test('sumar nada no cambia la lista', () {
      expect(appendComplaintPhotos([1], <int>[]), [1]);
    });
  });

  group('nombre de la línea', () {
    test('usa el recorrido cuando lo hay', () {
      expect(complaintRouteTitle(_route(longName: 'Plan 3000')), 'Plan 3000');
    });

    test('sin recorrido, «Micro N»', () {
      expect(complaintRouteTitle(_route()), 'Micro 17');
    });
  });
}
