/// Modelos de dominio de la capa de denuncias (complaints).
///
/// Clases puras sin dependencias de UI ni infraestructura HTTP.
/// La capa `data/` traduce JSON a estos modelos; la capa `application/`
/// y `presentation/` los consumen directamente.
library;

/// Resumen de una queja tal como llega del feed.
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

/// Comentario asociado a una queja.
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
