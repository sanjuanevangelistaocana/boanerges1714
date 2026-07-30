import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:boanerges1714/models/content_models.dart';

class ContentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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

  Stream<List<ContentSection>> watchSections({bool admin = false}) {
    Query<Map<String, dynamic>> query = _sections;
    if (!admin) {
      query = query
          .where('published', isEqualTo: true)
          .where('deleted', isEqualTo: false);
    }
    query = query.orderBy('order');
    return query.snapshots().map(
        (snapshot) => snapshot.docs.map(ContentSection.fromFirestore).toList());
  }

  Stream<List<ContentSection>> watchChildSections(
    String? parentId, {
    bool admin = false,
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
        parentId: cofradia.id,
        title: 'Archivo Histórico',
        description: 'Documentos y cronología histórica.',
        type: ContentSectionType.articulos,
        order: 5,
      ),
      (
        slug: 'patrimonio-artistico',
        parentId: patrimonio.id,
        title: 'Patrimonio Artístico',
        description: 'Fichas del patrimonio artístico.',
        type: ContentSectionType.fichas,
        order: 0,
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
      await existing.docs.first.reference.update({
        'parent_id': parentId,
        'content_type': type.name,
        'is_system': true,
        'deleted': false,
        'updated_at': Timestamp.fromDate(now),
      });
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
        updatedAt: now,
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
    await ref.set(section.toFirestore());
    return section;
  }

  Future<String> createSection(ContentSection section) async {
    final ref = _sections.doc();
    await ref.set(section.toFirestore());
    return ref.id;
  }

  Future<void> updateSection(String id, Map<String, dynamic> data) async {
    await _sections.doc(id).update({
      ...data,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteSection(ContentSection section) async {
    if (section.system) {
      throw StateError('Las secciones del sistema no se pueden eliminar.');
    }
    await _sections.doc(section.id).update({
      'deleted': true,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<ContentArticle>> watchArticles(
    String sectionId, {
    bool admin = false,
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

  Future<void> deleteArticle(String id) => _articles.doc(id).delete();

  Stream<List<PatrimonioFicha>> watchPatrimonio(
    String sectionId, {
    bool admin = false,
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

  Future<void> deletePatrimonio(String id) => _patrimonio.doc(id).delete();

  Stream<List<JuntaMiembro>> watchJunta(
    String sectionId, {
    bool admin = false,
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

  Future<void> deleteJunta(String id) => _junta.doc(id).delete();

  Stream<List<ContentGroup>> watchGroups(
    String sectionId, {
    bool admin = false,
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

  Future<void> deleteGroup(String id) => _groups.doc(id).delete();

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
      });
      return ref.id;
    }
    await collection.doc(id).update({
      ...data,
      'updated_at': FieldValue.serverTimestamp(),
    });
    return id;
  }

  Future<void> logError(String operation, Object error) async {
    debugPrint('[ContentService] $operation: $error');
  }
}
