import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boanerges1714/models/content_block.dart';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

enum NoticiaVisibility { publica, privada, segmentada }

enum NoticiaStatus { draft, scheduled, published, archived }

// ---------------------------------------------------------------------------
// CTA model
// ---------------------------------------------------------------------------

class NoticiaCta {
  final String label;
  final String route;
  final String type; // link, encuesta, evento, cuotas, documentos, custom

  const NoticiaCta({
    required this.label,
    this.route = '',
    this.type = 'link',
  });

  factory NoticiaCta.fromMap(Map<String, dynamic> m) => NoticiaCta(
        label: m['label'] ?? '',
        route: m['route'] ?? '',
        type: m['type'] ?? 'link',
      );

  Map<String, dynamic> toMap() => {
        'label': label,
        'route': route,
        'type': type,
      };
}

// ---------------------------------------------------------------------------
// Noticia (full CMS model)
// ---------------------------------------------------------------------------

class Noticia {
  final String id;
  final String title;
  final String subtitle;
  final String slug;
  final String shortDescription;
  final String content; // plain-text content (legacy + fallback)
  final List<ContentBlock> richContent; // structured rich content
  final String category;
  final List<String> tags;
  final NoticiaVisibility visibility;
  final List<String> targetTags;
  final bool isFeatured;
  final bool isPinned;
  final bool isUrgent;
  final bool showOnHomepage;
  final bool requireReadConfirmation;
  final String? coverImageUrl;
  final String? coverImagePath;
  final List<Map<String, String>> gallery;
  final List<Map<String, String>> attachments;
  final List<NoticiaCta> ctas;
  final DateTime? publishAt;
  final DateTime? expireAt;
  final NoticiaStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy;
  final String updatedBy;
  final int views;
  final int readCount;
  final int clickCount;

  Noticia({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.slug = '',
    this.shortDescription = '',
    this.content = '',
    this.richContent = const [],
    this.category = 'Institucional',
    this.tags = const [],
    this.visibility = NoticiaVisibility.publica,
    this.targetTags = const [],
    this.isFeatured = false,
    this.isPinned = false,
    this.isUrgent = false,
    this.showOnHomepage = true,
    this.requireReadConfirmation = false,
    this.coverImageUrl,
    this.coverImagePath,
    this.gallery = const [],
    this.attachments = const [],
    this.ctas = const [],
    this.publishAt,
    this.expireAt,
    this.status = NoticiaStatus.published,
    DateTime? createdAt,
    this.updatedAt,
    this.createdBy = '',
    this.updatedBy = '',
    this.views = 0,
    this.readCount = 0,
    this.clickCount = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  // ---------------------------------------------------------------------------
  // Computed helpers
  // ---------------------------------------------------------------------------

  bool get isPublished => status == NoticiaStatus.published;
  bool get isDraft => status == NoticiaStatus.draft;

  bool get isExpired =>
      expireAt != null && DateTime.now().isAfter(expireAt!);

  bool get isScheduledForFuture =>
      publishAt != null && DateTime.now().isBefore(publishAt!);

  /// Whether this noticia should currently be visible to end-users.
  bool get isCurrentlyVisible =>
      status == NoticiaStatus.published && !isExpired && !isScheduledForFuture;

  /// Check if a cofrade with the given tags can see this noticia.
  bool canCofradeAccess(List<String> cofradeTags) {
    if (visibility == NoticiaVisibility.publica) return true;
    if (visibility == NoticiaVisibility.privada) return true; // needs auth only
    if (visibility == NoticiaVisibility.segmentada) {
      if (targetTags.isEmpty) return true;
      return cofradeTags.any((t) => targetTags.contains(t));
    }
    return false;
  }

  /// Content to display — prefer rich content rendered as text, fallback to content field.
  String get displayContent {
    if (richContent.isNotEmpty) {
      return richContent.map((b) => b.text).join('\n');
    }
    return content;
  }

  // ---------------------------------------------------------------------------
  // Legacy getters (backward-compatibility with code referencing old field names)
  // ---------------------------------------------------------------------------

  String get titulo => title;
  String get contenido => content;
  DateTime get fecha => createdAt;
  bool get publicado => status == NoticiaStatus.published;
  bool get soloCofrades =>
      visibility == NoticiaVisibility.privada ||
      visibility == NoticiaVisibility.segmentada;
  List<Map<String, String>> get adjuntos => attachments;
  String? get imagenUrl => coverImageUrl;

  // ---------------------------------------------------------------------------
  // Default categories
  // ---------------------------------------------------------------------------

  static const List<String> defaultCategories = [
    'Institucional',
    'Cultos',
    'Procesiones',
    'Juventud',
    'Tesorería',
    'Caridad',
    'Eventos',
    'Patrimonio',
    'Avisos',
    'Formación',
  ];

  // ---------------------------------------------------------------------------
  // Slug generation
  // ---------------------------------------------------------------------------

  static String generateSlug(String title) {
    const replacements = {
      'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u',
      'ñ': 'n', 'ü': 'u',
      'Á': 'a', 'É': 'e', 'Í': 'i', 'Ó': 'o', 'Ú': 'u',
      'Ñ': 'n', 'Ü': 'u',
    };
    var slug = title.toLowerCase();
    for (final entry in replacements.entries) {
      slug = slug.replaceAll(entry.key, entry.value);
    }
    slug = slug.replaceAll(RegExp(r'[^a-z0-9\s-]'), '');
    slug = slug.replaceAll(RegExp(r'[\s]+'), '-');
    slug = slug.replaceAll(RegExp(r'-{2,}'), '-');
    slug = slug.replaceAll(RegExp(r'^-|-$'), '');
    if (slug.length > 80) slug = slug.substring(0, 80);
    return slug;
  }

  // ---------------------------------------------------------------------------
  // Firestore serialization (backward compatible)
  // ---------------------------------------------------------------------------

  factory Noticia.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // --- Visibility ---
    NoticiaVisibility vis;
    final visStr = data['visibility'] ?? data['visibilityType'];
    if (visStr is String) {
      vis = NoticiaVisibility.values.firstWhere(
        (v) => v.name == visStr,
        orElse: () => NoticiaVisibility.publica,
      );
    } else {
      // Legacy: solo_cofrades boolean
      final soloCofrades = data['solo_cofrades'] ?? false;
      vis = soloCofrades == true
          ? NoticiaVisibility.privada
          : NoticiaVisibility.publica;
    }

    // --- Status ---
    NoticiaStatus st;
    final stStr = data['status'];
    if (stStr is String) {
      st = NoticiaStatus.values.firstWhere(
        (s) => s.name == stStr,
        orElse: () => NoticiaStatus.published,
      );
    } else {
      // Legacy: publicado boolean
      final pub = data['publicado'] ?? true;
      st = pub == true ? NoticiaStatus.published : NoticiaStatus.draft;
    }

    // --- Rich content ---
    final rawRich = data['richContent'] as List<dynamic>? ?? [];
    final rich = rawRich
        .map((b) => ContentBlock.fromMap(Map<String, dynamic>.from(b as Map)))
        .toList();

    // --- CTAs ---
    final rawCtas = data['ctas'] as List<dynamic>? ?? [];
    final ctas = rawCtas
        .map((c) => NoticiaCta.fromMap(Map<String, dynamic>.from(c as Map)))
        .toList();

    // --- Gallery ---
    final rawGallery = data['gallery'] as List<dynamic>? ?? [];
    final gallery = rawGallery
        .map((g) => Map<String, String>.from(g as Map))
        .toList();

    // --- Attachments ---
    final rawAttach = (data['attachments'] ?? data['adjuntos']) as List<dynamic>? ?? [];
    final attachments = rawAttach
        .map((a) => Map<String, String>.from(a as Map))
        .toList();

    // --- Target tags ---
    final rawTargetTags = data['targetTags'] as List<dynamic>? ?? [];
    final targetTags = rawTargetTags.map((t) => '$t').toList();

    // --- Tags ---
    final rawTags = data['tags'] as List<dynamic>? ?? [];
    final tags = rawTags.map((t) => '$t').toList();

    // --- Dates ---
    DateTime createdAt;
    final ca = data['createdAt'] ?? data['fecha_creacion'] ?? data['fecha'];
    if (ca is Timestamp) {
      createdAt = ca.toDate();
    } else {
      createdAt = DateTime.now();
    }

    DateTime? updatedAt;
    final ua = data['updatedAt'];
    if (ua is Timestamp) updatedAt = ua.toDate();

    DateTime? publishAt;
    final pa = data['publishAt'];
    if (pa is Timestamp) publishAt = pa.toDate();

    DateTime? expireAt;
    final ea = data['expireAt'];
    if (ea is Timestamp) expireAt = ea.toDate();

    return Noticia(
      id: doc.id,
      title: data['title'] ?? data['titulo'] ?? '',
      subtitle: data['subtitle'] ?? '',
      slug: data['slug'] ?? '',
      shortDescription: data['shortDescription'] ?? '',
      content: data['content'] ?? data['contenido'] ?? '',
      richContent: rich,
      category: data['category'] ?? 'Institucional',
      tags: tags,
      visibility: vis,
      targetTags: targetTags,
      isFeatured: data['isFeatured'] ?? false,
      isPinned: data['isPinned'] ?? false,
      isUrgent: data['isUrgent'] ?? false,
      showOnHomepage: data['showOnHomepage'] ?? true,
      requireReadConfirmation: data['requireReadConfirmation'] ?? false,
      coverImageUrl: data['coverImageUrl'] ?? data['imagen_url'],
      coverImagePath: data['coverImagePath'],
      gallery: gallery,
      attachments: attachments,
      ctas: ctas,
      publishAt: publishAt,
      expireAt: expireAt,
      status: st,
      createdAt: createdAt,
      updatedAt: updatedAt,
      createdBy: data['createdBy'] ?? '',
      updatedBy: data['updatedBy'] ?? '',
      views: (data['views'] as num?)?.toInt() ?? 0,
      readCount: (data['readCount'] as num?)?.toInt() ?? 0,
      clickCount: (data['clickCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      // New fields
      'title': title,
      'subtitle': subtitle,
      'slug': slug,
      'shortDescription': shortDescription,
      'content': content,
      'richContent': richContent.map((b) => b.toMap()).toList(),
      'category': category,
      'tags': tags,
      'visibility': visibility.name,
      'targetTags': targetTags,
      'isFeatured': isFeatured,
      'isPinned': isPinned,
      'isUrgent': isUrgent,
      'showOnHomepage': showOnHomepage,
      'requireReadConfirmation': requireReadConfirmation,
      'coverImageUrl': coverImageUrl,
      'coverImagePath': coverImagePath,
      'gallery': gallery,
      'attachments': attachments,
      'ctas': ctas.map((c) => c.toMap()).toList(),
      'publishAt': publishAt != null ? Timestamp.fromDate(publishAt!) : null,
      'expireAt': expireAt != null ? Timestamp.fromDate(expireAt!) : null,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      'views': views,
      'readCount': readCount,
      'clickCount': clickCount,
      // Legacy compat (so old queries still work)
      'titulo': title,
      'contenido': content,
      'fecha': Timestamp.fromDate(createdAt),
      'imagen_url': coverImageUrl,
      'publicado': status == NoticiaStatus.published,
      'solo_cofrades': visibility != NoticiaVisibility.publica,
      'adjuntos': attachments,
      'fecha_creacion': Timestamp.fromDate(createdAt),
    };
  }

  Noticia copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? slug,
    String? shortDescription,
    String? content,
    List<ContentBlock>? richContent,
    String? category,
    List<String>? tags,
    NoticiaVisibility? visibility,
    List<String>? targetTags,
    bool? isFeatured,
    bool? isPinned,
    bool? isUrgent,
    bool? showOnHomepage,
    bool? requireReadConfirmation,
    String? coverImageUrl,
    String? coverImagePath,
    List<Map<String, String>>? gallery,
    List<Map<String, String>>? attachments,
    List<NoticiaCta>? ctas,
    DateTime? publishAt,
    DateTime? expireAt,
    NoticiaStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    int? views,
    int? readCount,
    int? clickCount,
  }) {
    return Noticia(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      slug: slug ?? this.slug,
      shortDescription: shortDescription ?? this.shortDescription,
      content: content ?? this.content,
      richContent: richContent ?? this.richContent,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      visibility: visibility ?? this.visibility,
      targetTags: targetTags ?? this.targetTags,
      isFeatured: isFeatured ?? this.isFeatured,
      isPinned: isPinned ?? this.isPinned,
      isUrgent: isUrgent ?? this.isUrgent,
      showOnHomepage: showOnHomepage ?? this.showOnHomepage,
      requireReadConfirmation:
          requireReadConfirmation ?? this.requireReadConfirmation,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      gallery: gallery ?? this.gallery,
      attachments: attachments ?? this.attachments,
      ctas: ctas ?? this.ctas,
      publishAt: publishAt ?? this.publishAt,
      expireAt: expireAt ?? this.expireAt,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      views: views ?? this.views,
      readCount: readCount ?? this.readCount,
      clickCount: clickCount ?? this.clickCount,
    );
  }
}
