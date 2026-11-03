import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../../../core/network/providers.dart';

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

class ComplaintSummary {
  const ComplaintSummary({
    required this.id,
    required this.routeId,
    required this.category,
    required this.description,
    required this.photoUrls,
    required this.status,
    required this.createdAt,
    this.likeCount = 0,
    this.commentCount = 0,
    this.likedByMe = false,
  });

  factory ComplaintSummary.fromJson(Map<String, dynamic> json) =>
      ComplaintSummary(
        id: json['id'] as String? ?? '',
        routeId: json['routeId'] as String? ?? '',
        category: json['category'] as String? ?? 'other',
        description: json['description'] as String? ?? '',
        photoUrls:
            (json['photoUrls'] as List?)?.whereType<String>().toList(
              growable: false,
            ) ??
            const [],
        status: json['status'] as String? ?? 'pending',
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
        commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
        likedByMe: json['likedByMe'] as bool? ?? false,
      );

  final String id;
  final String routeId;
  final String category;
  final String description;
  final List<String> photoUrls;
  final String status;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;

  ComplaintSummary copyWith({
    int? likeCount,
    bool? likedByMe,
    int? commentCount,
  }) => ComplaintSummary(
    id: id,
    routeId: routeId,
    category: category,
    description: description,
    photoUrls: photoUrls,
    status: status,
    createdAt: createdAt,
    likeCount: likeCount ?? this.likeCount,
    commentCount: commentCount ?? this.commentCount,
    likedByMe: likedByMe ?? this.likedByMe,
  );
}

class ComplaintComment {
  const ComplaintComment({
    required this.id,
    required this.complaintId,
    required this.authorName,
    required this.authorColor,
    required this.body,
    required this.createdAt,
  });

  factory ComplaintComment.fromJson(Map<String, dynamic> json) =>
      ComplaintComment(
        id: json['id'] as String? ?? '',
        complaintId: json['complaintId'] as String? ?? '',
        authorName: json['authorName'] as String? ?? '',
        authorColor: json['authorColor'] as String? ?? '',
        body: json['body'] as String? ?? '',
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );

  final String id;
  final String complaintId;
  final String authorName;
  final String authorColor;
  final String body;
  final DateTime createdAt;
}

final complaintRepositoryProvider = Provider<ComplaintRepository>(
  (ref) => ComplaintRepository(ref.watch(apiClientProvider)),
);
