import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boanerges1714/models/content_block.dart';

enum ContentSectionType { articulos, fichas, junta, grupos }

ContentSectionType contentSectionTypeFromValue(Object? value) {
  return ContentSectionType.values.firstWhere(
    (type) => type.name == value,
    orElse: () => ContentSectionType.articulos,
  );
}

DateTime _date(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.now();
}

DateTime? _optionalDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

List<ContentBlock> _blocks(Object? value) {
  return ((value as List<dynamic>?) ?? [])
      .whereType<Map>()
      .map((item) => ContentBlock.fromMap(Map<String, dynamic>.from(item)))
      .toList();
}

List<Map<String, String>> _stringMaps(Object? value) {
  return ((value as List<dynamic>?) ?? [])
      .whereType<Map>()
      .map((item) => Map<String, String>.from(
            item.map((key, value) => MapEntry('$key', '$value')),
          ))
      .toList();
}

List<Map<String, dynamic>> _maps(Object? value) {
  return ((value as List<dynamic>?) ?? [])
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

class ContentSection {
  final String id;
  final String slug;
  final String? parentId;
  final String title;
  final String shortDescription;
  final ContentSectionType type;
  final int order;
  final bool published;
  final String? coverImageUrl;
  final String? icon;
  final bool system;
  final bool deleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String updatedBy;

  const ContentSection({
    required this.id,
    required this.slug,
    this.parentId,
    required this.title,
    this.shortDescription = '',
    this.type = ContentSectionType.articulos,
    this.order = 0,
    this.published = true,
    this.coverImageUrl,
    this.icon,
    this.system = false,
    this.deleted = false,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy = '',
    this.updatedBy = '',
  });

  factory ContentSection.fromFirestore(DocumentSnapshot doc) {
    final data = Map<String, dynamic>.from(doc.data() as Map);
    return ContentSection(
      id: doc.id,
      slug: data['slug'] ?? '',
      parentId: data['parent_id'],
      title: data['title'] ?? data['titulo'] ?? '',
      shortDescription:
          data['short_description'] ?? data['descripcion_corta'] ?? '',
      type: contentSectionTypeFromValue(
          data['content_type'] ?? data['tipo_contenido'] ?? 'articulos'),
      order: (data['order'] as num?)?.toInt() ??
          (data['orden'] as num?)?.toInt() ??
          0,
      published: data['published'] ?? data['publicada'] ?? true,
      coverImageUrl: data['cover_image_url'] ?? data['imagen_portada'],
      icon: data['icon'],
      system: data['is_system'] ?? data['sistema'] ?? false,
      deleted: data['deleted'] ?? false,
      createdAt: _date(data['created_at']),
      updatedAt: _date(data['updated_at']),
      createdBy: data['created_by'] ?? '',
      updatedBy: data['updated_by'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'slug': slug,
        'parent_id': parentId,
        'title': title,
        'short_description': shortDescription,
        'content_type': type.name,
        'order': order,
        'published': published,
        'cover_image_url': coverImageUrl,
        'icon': icon,
        'is_system': system,
        'deleted': deleted,
        'created_at': Timestamp.fromDate(createdAt),
        'updated_at': Timestamp.fromDate(updatedAt),
        'created_by': createdBy,
        'updated_by': updatedBy,
      };
}

class ContentArticle {
  final String id;
  final String sectionId;
  final String slug;
  final String title;
  final String subtitle;
  final String plainContent;
  final List<ContentBlock> content;
  final List<Map<String, String>> photos;
  final List<Map<String, String>> documents;
  final List<Map<String, dynamic>> chronology;
  final int order;
  final String status;
  final DateTime? publishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String updatedBy;

  const ContentArticle({
    required this.id,
    required this.sectionId,
    required this.slug,
    required this.title,
    this.subtitle = '',
    this.plainContent = '',
    this.content = const [],
    this.photos = const [],
    this.documents = const [],
    this.chronology = const [],
    this.order = 0,
    this.status = 'draft',
    this.publishedAt,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy = '',
    this.updatedBy = '',
  });

  bool get published => status == 'published';

  factory ContentArticle.fromFirestore(DocumentSnapshot doc) {
    final data = Map<String, dynamic>.from(doc.data() as Map);
    return ContentArticle(
      id: doc.id,
      sectionId: data['section_id'] ?? '',
      slug: data['slug'] ?? '',
      title: data['title'] ?? data['titulo'] ?? '',
      subtitle: data['subtitle'] ?? data['subtitulo'] ?? '',
      plainContent: data['content'] is String ? data['content'] : '',
      content: _blocks(data['rich_content'] ?? data['contenido']),
      photos: _stringMaps(data['gallery'] ?? data['fotografias']),
      documents: _stringMaps(data['attachments'] ?? data['documentos']),
      chronology: _maps(data['timeline_entries'] ?? data['cronologia']),
      order: (data['order'] as num?)?.toInt() ??
          (data['orden'] as num?)?.toInt() ??
          0,
      status: data['status'] ?? data['estado'] ?? 'draft',
      publishedAt: _optionalDate(data['published_at']),
      createdAt: _date(data['created_at']),
      updatedAt: _date(data['updated_at']),
      createdBy: data['created_by'] ?? '',
      updatedBy: data['updated_by'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'section_id': sectionId,
        'slug': slug,
        'title': title,
        'subtitle': subtitle,
        'content': plainContent,
        'rich_content': content.map((block) => block.toMap()).toList(),
        'gallery': photos,
        'attachments': documents,
        'timeline_entries': chronology,
        'order': order,
        'status': status,
        'published_at':
            publishedAt == null ? null : Timestamp.fromDate(publishedAt!),
        'created_at': Timestamp.fromDate(createdAt),
        'updated_at': Timestamp.fromDate(updatedAt),
        'created_by': createdBy,
        'updated_by': updatedBy,
      };
}

class PatrimonioFicha {
  final String id;
  final String sectionId;
  final String slug;
  final String name;
  final String author;
  final String period;
  final String materials;
  final String measurements;
  final List<ContentBlock> description;
  final List<Map<String, dynamic>> restorations;
  final List<Map<String, String>> photos;
  final List<Map<String, String>> documents;
  final int order;
  final bool featured;
  final bool published;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String updatedBy;

  const PatrimonioFicha({
    required this.id,
    required this.sectionId,
    required this.slug,
    required this.name,
    this.author = '',
    this.period = '',
    this.materials = '',
    this.measurements = '',
    this.description = const [],
    this.restorations = const [],
    this.photos = const [],
    this.documents = const [],
    this.order = 0,
    this.featured = false,
    this.published = true,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy = '',
    this.updatedBy = '',
  });

  factory PatrimonioFicha.fromFirestore(DocumentSnapshot doc) {
    final data = Map<String, dynamic>.from(doc.data() as Map);
    return PatrimonioFicha(
      id: doc.id,
      sectionId: data['section_id'] ?? '',
      slug: data['slug'] ?? '',
      name: data['name'] ?? data['nombre'] ?? data['denominacion'] ?? '',
      author: data['author'] ?? data['autor'] ?? '',
      period: data['date_or_period'] ?? data['fecha_epoca'] ?? '',
      materials: data['materials'] ?? data['materiales'] ?? '',
      measurements: data['measurements'] ?? data['medidas'] ?? '',
      description: _blocks(data['rich_description'] ?? data['descripcion']),
      restorations: _maps(data['restorations'] ?? data['restauraciones']),
      photos: _stringMaps(data['photos'] ?? data['fotografias']),
      documents:
          _stringMaps(data['related_documents'] ?? data['documentacion']),
      order: (data['order'] as num?)?.toInt() ?? 0,
      featured: data['featured'] ?? data['destacada'] ?? false,
      published: data['published'] ?? data['publicada'] ?? true,
      createdAt: _date(data['created_at']),
      updatedAt: _date(data['updated_at']),
      createdBy: data['created_by'] ?? '',
      updatedBy: data['updated_by'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'section_id': sectionId,
        'slug': slug,
        'name': name,
        'author': author,
        'date_or_period': period,
        'materials': materials,
        'measurements': measurements,
        'description': '',
        'rich_description': description.map((block) => block.toMap()).toList(),
        'restorations': restorations,
        'photos': photos,
        'related_documents': documents,
        'order': order,
        'featured': featured,
        'published': published,
        'created_at': Timestamp.fromDate(createdAt),
        'updated_at': Timestamp.fromDate(updatedAt),
        'created_by': createdBy,
        'updated_by': updatedBy,
      };
}

class JuntaMiembro {
  final String id;
  final String? sectionId;
  final String position;
  final String name;
  final String? photoUrl;
  final String description;
  final int order;
  final bool active;
  final String? group;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String updatedBy;

  const JuntaMiembro({
    required this.id,
    this.sectionId,
    required this.position,
    required this.name,
    this.photoUrl,
    this.description = '',
    this.order = 0,
    this.active = true,
    this.group,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy = '',
    this.updatedBy = '',
  });

  factory JuntaMiembro.fromFirestore(DocumentSnapshot doc) {
    final data = Map<String, dynamic>.from(doc.data() as Map);
    return JuntaMiembro(
      id: doc.id,
      sectionId: data['section_id'],
      position: data['position'] ?? data['cargo'] ?? '',
      name: data['name'] ?? data['nombre'] ?? '',
      photoUrl: data['photo_url'] ?? data['fotografia'],
      description: data['description'] ?? data['descripcion'] ?? '',
      order: (data['order'] as num?)?.toInt() ?? 0,
      active: data['active'] ?? data['activo'] ?? true,
      group: data['group'] ?? data['grupo'],
      createdAt: _date(data['created_at']),
      updatedAt: _date(data['updated_at']),
      createdBy: data['created_by'] ?? '',
      updatedBy: data['updated_by'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'section_id': sectionId,
        'position': position,
        'name': name,
        'photo_url': photoUrl,
        'description': description,
        'order': order,
        'active': active,
        'group': group,
        'created_at': Timestamp.fromDate(createdAt),
        'updated_at': Timestamp.fromDate(updatedAt),
        'created_by': createdBy,
        'updated_by': updatedBy,
      };
}

class ContentGroup {
  final String id;
  final String? sectionId;
  final String name;
  final String slug;
  final String shortDescription;
  final String? responsible;
  final List<Map<String, String>> photos;
  final List<ContentBlock> content;
  final int order;
  final bool published;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String updatedBy;

  const ContentGroup({
    required this.id,
    this.sectionId,
    required this.name,
    required this.slug,
    this.shortDescription = '',
    this.responsible,
    this.photos = const [],
    this.content = const [],
    this.order = 0,
    this.published = true,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy = '',
    this.updatedBy = '',
  });

  factory ContentGroup.fromFirestore(DocumentSnapshot doc) {
    final data = Map<String, dynamic>.from(doc.data() as Map);
    return ContentGroup(
      id: doc.id,
      sectionId: data['section_id'],
      name: data['name'] ?? data['nombre'] ?? '',
      slug: data['slug'] ?? '',
      shortDescription:
          data['short_description'] ?? data['descripcion_corta'] ?? '',
      responsible: data['responsible'] ?? data['responsable'],
      photos: _stringMaps(data['photos'] ?? data['fotografias']),
      content: _blocks(data['rich_content'] ?? data['contenido']),
      order: (data['order'] as num?)?.toInt() ?? 0,
      published: data['published'] ?? data['publicada'] ?? true,
      createdAt: _date(data['created_at']),
      updatedAt: _date(data['updated_at']),
      createdBy: data['created_by'] ?? '',
      updatedBy: data['updated_by'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'section_id': sectionId,
        'name': name,
        'slug': slug,
        'short_description': shortDescription,
        'responsible': responsible,
        'photos': photos,
        'content': '',
        'rich_content': content.map((block) => block.toMap()).toList(),
        'order': order,
        'published': published,
        'created_at': Timestamp.fromDate(createdAt),
        'updated_at': Timestamp.fromDate(updatedAt),
        'created_by': createdBy,
        'updated_by': updatedBy,
      };
}

class InterestLink {
  final String id;
  final String title;
  final String url;
  final String description;
  final String? icon;
  final String? imageUrl;
  final bool active;
  final int order;
  final DateTime createdAt;
  final DateTime updatedAt;

  const InterestLink({
    required this.id,
    required this.title,
    required this.url,
    this.description = '',
    this.icon,
    this.imageUrl,
    this.active = true,
    this.order = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory InterestLink.fromFirestore(DocumentSnapshot doc) {
    final data = Map<String, dynamic>.from(doc.data() as Map);
    return InterestLink(
      id: doc.id,
      title: data['title'] ?? '',
      url: data['url'] ?? '',
      description: data['description'] ?? '',
      icon: data['icon'],
      imageUrl: data['image_url'],
      active: data['active'] ?? true,
      order: (data['order'] as num?)?.toInt() ?? 0,
      createdAt: _date(data['created_at']),
      updatedAt: _date(data['updated_at']),
    );
  }
}

class LegalPage {
  final String id;
  final String title;
  final List<ContentBlock> content;
  final bool published;
  final DateTime? updatedContentAt;
  final DateTime updatedAt;

  const LegalPage({
    required this.id,
    required this.title,
    this.content = const [],
    this.published = false,
    this.updatedContentAt,
    required this.updatedAt,
  });

  factory LegalPage.fromFirestore(DocumentSnapshot doc) {
    final data = Map<String, dynamic>.from(doc.data() as Map);
    return LegalPage(
      id: doc.id,
      title: data['title'] ?? '',
      content: _blocks(data['rich_content'] ?? data['content']),
      published: data['published'] ?? false,
      updatedContentAt: _optionalDate(data['content_updated_at']),
      updatedAt: _date(data['updated_at']),
    );
  }
}

class ManagedCelebration {
  final String id;
  final String title;
  final String type;
  final String description;
  final DateTime? date;
  final int? month;
  final int? day;
  final bool annual;
  final bool published;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ManagedCelebration({
    required this.id,
    required this.title,
    required this.type,
    this.description = '',
    this.date,
    this.month,
    this.day,
    this.annual = false,
    this.published = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ManagedCelebration.fromFirestore(DocumentSnapshot doc) {
    final data = Map<String, dynamic>.from(doc.data() as Map);
    return ManagedCelebration(
      id: doc.id,
      title: data['title'] ?? '',
      type: data['type'] ?? 'Cofradía',
      description: data['description'] ?? '',
      date: _optionalDate(data['date']),
      month: (data['month'] as num?)?.toInt(),
      day: (data['day'] as num?)?.toInt(),
      annual: data['annual'] ?? false,
      published: data['published'] ?? true,
      createdAt: _date(data['created_at']),
      updatedAt: _date(data['updated_at']),
    );
  }
}
