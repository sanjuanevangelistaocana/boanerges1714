import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:boanerges1714/models/content_models.dart';
import 'package:boanerges1714/services/storage_service.dart';

class ContentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final StorageService _storage = StorageService();
  final Map<String, Stream<List<ContentSection>>> _sectionStreams = {};
  final Map<String, Stream<List<ContentArticle>>> _articleStreams = {};
  final Map<String, Stream<List<PatrimonioFicha>>> _patrimonioStreams = {};
  final Map<String, Stream<List<JuntaMiembro>>> _juntaStreams = {};
  final Map<String, Stream<List<ContentGroup>>> _groupStreams = {};

  CollectionReference<Map<String, dynamic>> get _sections =>
      _db.collection('content_sections');
  CollectionReference<Map<String, dynamic>> get _articles =>
      _db.collection('content_articles');
  CollectionReference<Map<String, dynamic>> get _patrimonio =>
      _db.collection('patrimonio_fichas');
  CollectionReference<Map<String, dynamic>> get _junta =>
      _db.collection('junta_miembros');
  CollectionReference<Map<String, dynamic>> get _groups =>
      _db.collection('grupos');

  late final Stream<List<ContentSection>> publishedSectionsStream =
      _createSectionsStream(admin: false).asBroadcastStream();

  Stream<List<ContentSection>> watchSections({bool admin = false}) {
    if (!admin) return publishedSectionsStream;
    return _sectionStreams.putIfAbsent(
      'all',
      () => _createSectionsStream(admin: true).asBroadcastStream(),
    );
  }

  Stream<List<ContentSection>> watchChildSections(
    String? parentId, {
    bool admin = false,
  }) {
    final key = '${admin ? 'admin' : 'public'}:${parentId ?? 'null'}';
    return _sectionStreams.putIfAbsent(
      key,
      () => _createChildSectionsStream(parentId, admin: admin)
          .asBroadcastStream(),
    );
  }

  Stream<List<ContentSection>> _createSectionsStream({required bool admin}) {
    Query<Map<String, dynamic>> query = _sections;
    if (!admin) {
      query = query
          .where('published', isEqualTo: true)
          .where('deleted', isEqualTo: false);
    }
    return query.orderBy('order').snapshots().map(
        (snapshot) => snapshot.docs.map(ContentSection.fromFirestore).toList());
  }

  Stream<List<ContentSection>> _createChildSectionsStream(
    String? parentId, {
    required bool admin,
  }) {
    Query<Map<String, dynamic>> query =
        _sections.where('parent_id', isEqualTo: parentId);
    if (!admin) {
      query = query
          .where('published', isEqualTo: true)
          .where('deleted', isEqualTo: false);
    }
    return query.orderBy('order').snapshots().map(
        (snapshot) => snapshot.docs.map(ContentSection.fromFirestore).toList());
  }

  Future<ContentSection?> getSectionBySlug(String slug) async {
    final snapshot =
        await _sections.where('slug', isEqualTo: slug).limit(1).get();
    if (snapshot.docs.isEmpty) return null;
    return ContentSection.fromFirestore(snapshot.docs.first);
  }

  Future<ContentSection?> getSectionBySlugPublic(String slug) async {
    final snapshot = await _sections
        .where('slug', isEqualTo: slug)
        .where('published', isEqualTo: true)
        .where('deleted', isEqualTo: false)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return ContentSection.fromFirestore(snapshot.docs.first);
  }

  Future<void> ensureSystemSections() async {
    final roots = <String, ContentSection>{};
    for (final definition in [
      (
        slug: 'cofradia',
        title: 'Cofradía',
        description: 'Historia, organización y vida de la Cofradía.',
        type: ContentSectionType.articulos,
        order: 0,
      ),
      (
        slug: 'patrimonio',
        title: 'Patrimonio',
        description: 'Patrimonio artístico y documental.',
        type: ContentSectionType.fichas,
        order: 1,
      ),
    ]) {
      roots[definition.slug] = await _ensureSystemSection(
        slug: definition.slug,
        title: definition.title,
        description: definition.description,
        type: definition.type,
        order: definition.order,
      );
    }

    final cofradia = roots['cofradia']!;
    final patrimonio = roots['patrimonio']!;
    final children = [
      (
        slug: 'historia',
        parentId: cofradia.id,
        title: 'Historia',
        description: 'Historia de la Cofradía.',
        type: ContentSectionType.articulos,
        order: 0,
      ),
      (
        slug: 'reglas',
        parentId: cofradia.id,
        title: 'Reglas',
        description: 'Reglas y documentos normativos.',
        type: ContentSectionType.articulos,
        order: 1,
      ),
      (
        slug: 'la-parroquia',
        parentId: cofradia.id,
        title: 'La Parroquia',
        description: 'Relación con la parroquia.',
        type: ContentSectionType.articulos,
        order: 2,
      ),
      (
        slug: 'junta-de-gobierno',
        parentId: cofradia.id,
        title: 'Junta de Gobierno',
        description: 'Miembros y cargos de la Junta.',
        type: ContentSectionType.junta,
        order: 3,
      ),
      (
        slug: 'grupos',
        parentId: cofradia.id,
        title: 'Grupos',
        description: 'Grupos de trabajo y participación.',
        type: ContentSectionType.grupos,
        order: 4,
      ),
      (
        slug: 'archivo-historico',
        parentId: patrimonio.id,
        title: 'Archivo Histórico',
        description: 'Documentos y cronología histórica.',
        type: ContentSectionType.articulos,
        order: 0,
      ),
      (
        slug: 'patrimonio-artistico',
        parentId: patrimonio.id,
        title: 'Patrimonio Artístico',
        description: 'Fichas del patrimonio artístico.',
        type: ContentSectionType.fichas,
        order: 1,
      ),
    ];
    for (final definition in children) {
      await _ensureSystemSection(
        slug: definition.slug,
        parentId: definition.parentId,
        title: definition.title,
        description: definition.description,
        type: definition.type,
        order: definition.order,
      );
    }
  }

  Future<ContentSection> _ensureSystemSection({
    required String slug,
    String? parentId,
    required String title,
    required String description,
    required ContentSectionType type,
    required int order,
  }) async {
    final existing =
        await _sections.where('slug', isEqualTo: slug).limit(1).get();
    final now = DateTime.now();
    if (existing.docs.isNotEmpty) {
      final section = ContentSection.fromFirestore(existing.docs.first);
      final changes = <String, dynamic>{};
      if (section.parentId != parentId) changes['parent_id'] = parentId;
      if (section.type != type) changes['content_type'] = type.name;
      if (!section.system) changes['is_system'] = true;
      if (section.deleted) changes['deleted'] = false;
      if (changes.isNotEmpty) {
        changes['updated_at'] = Timestamp.fromDate(now);
        changes['updated_by'] = FirebaseAuth.instance.currentUser?.uid ?? '';
        await existing.docs.first.reference.update(changes);
      }
      return ContentSection(
        id: section.id,
        slug: slug,
        parentId: parentId,
        title: section.title.isEmpty ? title : section.title,
        shortDescription: section.shortDescription.isEmpty
            ? description
            : section.shortDescription,
        type: type,
        order: section.order,
        published: section.published,
        coverImageUrl: section.coverImageUrl,
        icon: section.icon,
        system: true,
        deleted: false,
        createdAt: section.createdAt,
        updatedAt: changes.isEmpty ? section.updatedAt : now,
        createdBy: section.createdBy,
        updatedBy: section.updatedBy,
      );
    }
    final ref = _sections.doc();
    final section = ContentSection(
      id: ref.id,
      slug: slug,
      parentId: parentId,
      title: title,
      shortDescription: description,
      type: type,
      order: order,
      system: true,
      createdAt: now,
      updatedAt: now,
    );
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    await ref.set({
      ...section.toFirestore(),
      'created_by': uid,
      'updated_by': uid,
    });
    return section;
  }

  Future<String> createSection(ContentSection section) async {
    final ref = _sections.doc();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    await ref.set({
      ...section.toFirestore(),
      'created_by': uid,
      'updated_by': uid,
    });
    return ref.id;
  }

  Future<void> updateSection(String id, Map<String, dynamic> data) async {
    await _sections.doc(id).update({
      ...data,
      'updated_at': FieldValue.serverTimestamp(),
      'updated_by': FirebaseAuth.instance.currentUser?.uid ?? '',
    });
  }

  Future<void> deleteSection(ContentSection section) async {
    if (section.system) {
      throw StateError('Las secciones del sistema no se pueden eliminar.');
    }
    await _sections.doc(section.id).update({
      'deleted': true,
      'updated_at': FieldValue.serverTimestamp(),
      'updated_by': FirebaseAuth.instance.currentUser?.uid ?? '',
    });
  }

  Stream<List<ContentArticle>> watchArticles(
    String sectionId, {
    bool admin = false,
  }) {
    final key = '${admin ? 'admin' : 'public'}:$sectionId';
    return _articleStreams.putIfAbsent(
      key,
      () => _createArticleStream(sectionId, admin: admin).asBroadcastStream(),
    );
  }

  Stream<List<ContentArticle>> _createArticleStream(
    String sectionId, {
    required bool admin,
  }) {
    Query<Map<String, dynamic>> query =
        _articles.where('section_id', isEqualTo: sectionId);
    if (!admin) query = query.where('status', isEqualTo: 'published');
    return query.orderBy('order').snapshots().map(
        (snapshot) => snapshot.docs.map(ContentArticle.fromFirestore).toList());
  }

  Future<String> saveArticle(String? id, Map<String, dynamic> data) async {
    return _save(_articles, id, data);
  }

  Future<ContentArticle?> getArticleBySlugPublic(
    String sectionId,
    String slug,
  ) async {
    final snapshot = await _articles
        .where('section_id', isEqualTo: sectionId)
        .where('slug', isEqualTo: slug)
        .where('status', isEqualTo: 'published')
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return ContentArticle.fromFirestore(snapshot.docs.first);
  }

  Future<void> deleteArticle(String id) async {
    await _deleteDocumentAndFiles(
        _articles, id, ['gallery', 'attachments', 'rich_content']);
  }

  Stream<List<PatrimonioFicha>> watchPatrimonio(
    String sectionId, {
    bool admin = false,
  }) {
    final key = '${admin ? 'admin' : 'public'}:$sectionId';
    return _patrimonioStreams.putIfAbsent(
      key,
      () =>
          _createPatrimonioStream(sectionId, admin: admin).asBroadcastStream(),
    );
  }

  Stream<List<PatrimonioFicha>> _createPatrimonioStream(
    String sectionId, {
    required bool admin,
  }) {
    Query<Map<String, dynamic>> query =
        _patrimonio.where('section_id', isEqualTo: sectionId);
    if (!admin) query = query.where('published', isEqualTo: true);
    return query.orderBy('order').snapshots().map((snapshot) =>
        snapshot.docs.map(PatrimonioFicha.fromFirestore).toList());
  }

  Future<String> savePatrimonio(String? id, Map<String, dynamic> data) async {
    return _save(_patrimonio, id, data);
  }

  Future<PatrimonioFicha?> getPatrimonioBySlugPublic(
    String sectionId,
    String slug,
  ) async {
    final snapshot = await _patrimonio
        .where('section_id', isEqualTo: sectionId)
        .where('slug', isEqualTo: slug)
        .where('published', isEqualTo: true)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return PatrimonioFicha.fromFirestore(snapshot.docs.first);
  }

  Future<void> deletePatrimonio(String id) async {
    await _deleteDocumentAndFiles(_patrimonio, id, [
      'photos',
      'related_documents',
      'rich_description',
    ]);
  }

  Stream<List<JuntaMiembro>> watchJunta(
    String sectionId, {
    bool admin = false,
  }) {
    final key = '${admin ? 'admin' : 'public'}:$sectionId';
    return _juntaStreams.putIfAbsent(
      key,
      () => _createJuntaStream(sectionId, admin: admin).asBroadcastStream(),
    );
  }

  Stream<List<JuntaMiembro>> _createJuntaStream(
    String sectionId, {
    required bool admin,
  }) {
    Query<Map<String, dynamic>> query =
        _junta.where('section_id', isEqualTo: sectionId);
    if (!admin) query = query.where('active', isEqualTo: true);
    return query.orderBy('order').snapshots().map(
        (snapshot) => snapshot.docs.map(JuntaMiembro.fromFirestore).toList());
  }

  Future<String> saveJunta(String? id, Map<String, dynamic> data) async {
    return _save(_junta, id, data);
  }

  Future<void> deleteJunta(String id) async {
    await _deleteDocumentAndFiles(_junta, id, ['photo_url']);
  }

  Stream<List<ContentGroup>> watchGroups(
    String sectionId, {
    bool admin = false,
  }) {
    final key = '${admin ? 'admin' : 'public'}:$sectionId';
    return _groupStreams.putIfAbsent(
      key,
      () => _createGroupStream(sectionId, admin: admin).asBroadcastStream(),
    );
  }

  Stream<List<ContentGroup>> _createGroupStream(
    String sectionId, {
    required bool admin,
  }) {
    Query<Map<String, dynamic>> query =
        _groups.where('section_id', isEqualTo: sectionId);
    if (!admin) query = query.where('published', isEqualTo: true);
    return query.orderBy('order').snapshots().map(
        (snapshot) => snapshot.docs.map(ContentGroup.fromFirestore).toList());
  }

  Future<String> saveGroup(String? id, Map<String, dynamic> data) async {
    return _save(_groups, id, data);
  }

  Future<ContentGroup?> getGroupBySlugPublic(
    String sectionId,
    String slug,
  ) async {
    final snapshot = await _groups
        .where('section_id', isEqualTo: sectionId)
        .where('slug', isEqualTo: slug)
        .where('published', isEqualTo: true)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return ContentGroup.fromFirestore(snapshot.docs.first);
  }

  Future<void> deleteGroup(String id) async {
    await _deleteDocumentAndFiles(_groups, id, ['photos', 'rich_content']);
  }

  Future<void> importInitialHistory() async {
    final section = await getSectionBySlug('historia');
    if (section == null) {
      throw StateError('No existe la sección Historia.');
    }
    final existing = await _articles
        .where('section_id', isEqualTo: section.id)
        .where('slug', isEqualTo: 'historia-principal')
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return;
    final now = DateTime.now();
    await _articles.add({
      'section_id': section.id,
      'slug': 'historia-principal',
      'title': 'Nuestra Historia',
      'subtitle': 'Más de 300 años de fe y tradición',
      'content': '',
      'rich_content': [
        {
          'type': 'heading',
          'text': 'Fundación',
          'level': 2,
        },
        {
          'type': 'paragraph',
          'text':
              'La Cofradía de San Juan Evangelista de Ocaña fue fundada en el año 1714, en un momento de gran fervor religioso en la villa toledana. Desde sus orígenes, la hermandad ha estado vinculada a la devoción y culto del apóstol amado de Cristo.',
        },
        {
          'type': 'heading',
          'text': 'Consolidación',
          'level': 2,
        },
        {
          'type': 'paragraph',
          'text':
              'Durante el siglo XVIII, la Cofradía se consolidó como una de las hermandades más importantes de Ocaña, participando activamente en la vida religiosa y social de la villa.',
        },
        {
          'type': 'heading',
          'text': 'Pervivencia',
          'level': 2,
        },
        {
          'type': 'paragraph',
          'text':
              'A pesar de los difíciles momentos históricos, la Cofradía ha mantenido viva la llama de la devoción a San Juan Evangelista, adaptándose a los tiempos sin perder su esencia.',
        },
        {
          'type': 'heading',
          'text': 'Siglo XXI',
          'level': 2,
        },
        {
          'type': 'paragraph',
          'text':
              'Hoy en día, la Cofradía sigue siendo un pilar fundamental de la Semana Santa de Ocaña y de la vida parroquial, con una comunidad de cofrades comprometidos con la tradición y la fe.',
        },
        {
          'type': 'heading',
          'text': 'San Juan Evangelista',
          'level': 2,
        },
        {
          'type': 'paragraph',
          'text':
              'San Juan Evangelista, también conocido como "el discípulo amado", fue uno de los doce apóstoles de Jesús. Junto con su hermano Santiago, fueron llamados por Jesús "Boanerges", que significa "Hijos del Trueno". Es el autor del cuarto Evangelio, tres epístolas y el Apocalipsis. Su fiesta se celebra el 27 de diciembre.',
        },
        {
          'type': 'quote',
          'text': '"Boanerges" - Hijos del Trueno\nMarcos 3:17',
        },
      ],
      'gallery': <Map<String, String>>[],
      'attachments': <Map<String, String>>[],
      'timeline_entries': [
        {
          'date_or_year': '1714',
          'title': 'Fundación',
          'text':
              'Fundación de la Cofradía en un momento de gran fervor religioso.',
          'order': 0
        },
        {
          'date_or_year': 'Siglo XVIII',
          'title': 'Consolidación',
          'text':
              'Consolidación de la hermandad en la vida religiosa y social de Ocaña.',
          'order': 1
        },
        {
          'date_or_year': 'Siglo XIX-XX',
          'title': 'Pervivencia',
          'text':
              'La devoción a San Juan Evangelista se mantiene viva a través del tiempo.',
          'order': 2
        },
        {
          'date_or_year': 'Actualidad',
          'title': 'Siglo XXI',
          'text':
              'La Cofradía continúa vinculada a la Semana Santa y a la vida parroquial.',
          'order': 3
        },
      ],
      'order': 0,
      'status': 'published',
      'published_at': Timestamp.fromDate(now),
      'created_at': Timestamp.fromDate(now),
      'updated_at': Timestamp.fromDate(now),
      'created_by': FirebaseAuth.instance.currentUser?.uid ?? '',
      'updated_by': FirebaseAuth.instance.currentUser?.uid ?? '',
    });
  }

  Future<void> _deleteDocumentAndFiles(
    CollectionReference<Map<String, dynamic>> collection,
    String id,
    List<String> fields,
  ) async {
    final snapshot = await collection.doc(id).get();
    final data = snapshot.data() ?? {};
    await collection.doc(id).delete();
    final urls = <String>[];
    for (final field in fields) {
      final value = data[field];
      if (value is String && value.isNotEmpty) urls.add(value);
      if (value is List) {
        for (final item in value) {
          if (item is Map && item['url'] is String) {
            urls.add(item['url'] as String);
          }
          if (item is Map && item['imageUrl'] is String) {
            urls.add(item['imageUrl'] as String);
          }
          if (item is Map && item['image_url'] is String) {
            urls.add(item['image_url'] as String);
          }
        }
      }
    }
    final blocks = [
      ...(data['rich_content'] as List? ?? const []),
      ...(data['rich_description'] as List? ?? const []),
    ];
    for (final item in blocks) {
      if (item is Map && item['imageUrl'] is String) {
        urls.add(item['imageUrl'] as String);
      }
    }
    await Future.wait(urls.toSet().map(_storage.deleteFileReporting));
  }

  Future<String> _save(
    CollectionReference<Map<String, dynamic>> collection,
    String? id,
    Map<String, dynamic> data,
  ) async {
    final now = DateTime.now();
    if (id == null) {
      final ref = collection.doc();
      await ref.set({
        ...data,
        'created_at': Timestamp.fromDate(now),
        'updated_at': Timestamp.fromDate(now),
        'created_by': FirebaseAuth.instance.currentUser?.uid ?? '',
        'updated_by': FirebaseAuth.instance.currentUser?.uid ?? '',
      });
      return ref.id;
    }
    await collection.doc(id).update({
      ...data,
      'updated_at': FieldValue.serverTimestamp(),
      'updated_by': FirebaseAuth.instance.currentUser?.uid ?? '',
    });
    return id;
  }

  Future<void> logError(String operation, Object error) async {
    debugPrint('[ContentService] $operation: $error');
  }
}
