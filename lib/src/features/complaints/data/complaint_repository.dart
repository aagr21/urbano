import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../../../core/network/providers.dart';
import '../domain/complaint_models.dart';

class ComplaintRepository {
  ComplaintRepository(this._api);
  final ApiClient _api;

  Future<List<ComplaintSummary>> list({String? deviceKey}) async {
    final data = await _api.fetch(
      Endpoints.complaints,
      query: deviceKey == null ? null : {'deviceKey': deviceKey},
    );
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(ComplaintSummary.fromJson)
        .toList(growable: false);
  }

  Future<void> create({
    required String routeId,
    required String category,
    required String description,
    required List<XFile> photos,
  }) async {
    final files = <MultipartFile>[];
    for (final photo in photos) {
      files.add(await MultipartFile.fromFile(photo.path, filename: photo.name));
    }
    await _api.postMultipart(
      Endpoints.complaints,
      data: FormData.fromMap({
        'routeId': routeId,
        'category': category,
        'description': description,
        'photos': files,
      }),
    );
  }

  /// Registra (`liked: true`) o quita (`liked: false`) el apoyo del
  /// dispositivo sobre [complaintId]; devuelve el contador ya actualizado.
  Future<int> setLiked({
    required String complaintId,
    required String deviceKey,
    required bool liked,
  }) async {
    final result = liked
        ? await _api.postJson(
            Endpoints.complaintLike(complaintId),
            body: {'deviceKey': deviceKey},
          )
        : await _api.deleteJson(
            Endpoints.complaintLike(complaintId),
            query: {'deviceKey': deviceKey},
          );
    return (result['likeCount'] as num?)?.toInt() ?? 0;
  }

  Future<List<ComplaintComment>> comments(String complaintId) async {
    final data = await _api.fetch(Endpoints.complaintComments(complaintId));
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(ComplaintComment.fromJson)
        .toList(growable: false);
  }

  Future<ComplaintComment> addComment({
    required String complaintId,
    required String deviceKey,
    required String authorName,
    required String body,
  }) async {
    final data = await _api.postJson(
      Endpoints.complaintComments(complaintId),
      body: {'deviceKey': deviceKey, 'authorName': authorName, 'body': body},
    );
    return ComplaintComment.fromJson(data);
  }
}

final complaintRepositoryProvider = Provider<ComplaintRepository>(
  (ref) => ComplaintRepository(ref.watch(apiClientProvider)),
);
