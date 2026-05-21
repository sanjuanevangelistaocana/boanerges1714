import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:boanerges1714/models/noticia.dart';
import 'package:boanerges1714/models/cofrade.dart';

class NoticiasService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collection = 'noticias';

  // -------------------------------------------------------------------------
  // Core streams
  // -------------------------------------------------------------------------

  /// All noticias (admin view, no filters).
  Stream<List<Noticia>> getAllNoticias() {
    return _db
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
      final list = <Noticia>[];
      for (final doc in snap.docs) {
        try {
          list.add(Noticia.fromFirestore(doc));
        } catch (e) {
          debugPrint('[NoticiasService] parse error ${doc.id}: $e');
        }
      }
      return list;
    });
  }

  /// Published & currently visible noticias (public zone).
  Stream<List<Noticia>> getNoticiasPublicas() {
    return getAllNoticias().map((all) => all
        .where((n) =>
            n.isCurrentlyVisible &&
            n.visibility == NoticiaVisibility.publica)
        .toList());
  }

  /// Noticias visible to a specific cofrade (private zone).
  /// Includes public + private + segmented if tags match.
  Stream<List<Noticia>> getNoticiasParaCofrade(Cofrade cofrade) {
    final allTags = [...cofrade.tagsManual, ...cofrade.tagsAuto];
    return getAllNoticias().map((all) => all
        .where((n) => n.isCurrentlyVisible && n.canCofradeAccess(allTags))
        .toList());
  }

  /// Active noticias — published, not expired.
  Stream<List<Noticia>> getNoticiasActivas() {
    return getAllNoticias().map(
        (all) => all.where((n) => n.isCurrentlyVisible).toList());
  }

  /// Featured noticias for homepage hero.
  Stream<List<Noticia>> getNoticiasDestacadas() {
    return getNoticiasActivas().map(
        (all) => all.where((n) => n.isFeatured && n.showOnHomepage).toList());
  }

  /// Pinned noticias (always at top).
  Stream<List<Noticia>> getNoticiasFijadas() {
    return getNoticiasActivas()
        .map((all) => all.where((n) => n.isPinned).toList());
  }

  /// Urgent banners visible to a cofrade.
  Stream<List<Noticia>> getUrgentBanners(Cofrade cofrade) {
    final allTags = [...cofrade.tagsManual, ...cofrade.tagsAuto];
    return getAllNoticias().map((all) => all
        .where((n) =>
            n.isCurrentlyVisible &&
            n.isUrgent &&
            n.canCofradeAccess(allTags))
        .toList());
  }

  /// Latest noticias with limit.
  Stream<List<Noticia>> getUltimasNoticias(
      {int limit = 5, bool incluirPrivadas = false}) {
    return getNoticiasActivas().map((all) {
      var filtered = all;
      if (!incluirPrivadas) {
        filtered = all
            .where((n) => n.visibility == NoticiaVisibility.publica)
            .toList();
      }
      return filtered.take(limit).toList();
    });
  }

  /// Noticias by category.
  Stream<List<Noticia>> getNoticiasByCategory(String category) {
    return getNoticiasActivas()
        .map((all) => all.where((n) => n.category == category).toList());
  }

  /// Search noticias by query (title + shortDescription + content).
  Stream<List<Noticia>> searchNoticias(String query) {
    final q = query.toLowerCase();
    return getNoticiasActivas().map((all) => all
        .where((n) =>
            n.title.toLowerCase().contains(q) ||
            n.shortDescription.toLowerCase().contains(q) ||
            n.content.toLowerCase().contains(q) ||
            n.category.toLowerCase().contains(q))
        .toList());
  }

  /// Noticias by year (for hemeroteca).
  Stream<List<Noticia>> getNoticiasByYear(int year) {
    return getAllNoticias().map((all) => all
        .where((n) =>
            n.createdAt.year == year &&
            n.status == NoticiaStatus.published)
        .toList());
  }

  /// Available years for hemeroteca.
  Stream<List<int>> getAvailableYears() {
    return getAllNoticias().map((all) {
      final years = all
          .where((n) => n.status == NoticiaStatus.published)
          .map((n) => n.createdAt.year)
          .toSet()
          .toList();
      years.sort((a, b) => b.compareTo(a));
      return years;
    });
  }

  /// Related noticias (same category or shared tags).
  Stream<List<Noticia>> getRelatedNoticias(Noticia noticia, {int limit = 4}) {
    return getNoticiasActivas().map((all) {
      final related = all.where((n) {
        if (n.id == noticia.id) return false;
        if (n.category == noticia.category) return true;
        if (n.tags.any((t) => noticia.tags.contains(t))) return true;
        return false;
      }).toList();
      return related.take(limit).toList();
    });
  }

  // -------------------------------------------------------------------------
  // Single getters
  // -------------------------------------------------------------------------

  Future<Noticia?> getNoticia(String id) async {
    final doc = await _db.collection(_collection).doc(id).get();
    if (!doc.exists) return null;
    return Noticia.fromFirestore(doc);
  }

  Future<Noticia?> getNoticiaBySlug(String slug) async {
    final snap = await _db
        .collection(_collection)
        .where('slug', isEqualTo: slug)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return Noticia.fromFirestore(snap.docs.first);
  }

  // -------------------------------------------------------------------------
  // CRUD
  // -------------------------------------------------------------------------

  Future<String> createNoticia(Noticia noticia) async {
    final data = noticia.toFirestore();
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    final doc = await _db.collection(_collection).add(data);

    // Secondary writes: audit + novedades — non-blocking
    // If these fail (e.g. permission issues on subcollections), the main
    // document is still saved correctly. Errors are logged, not propagated.
    try {
      await _addAuditEntry(doc.id, 'created', noticia.createdBy, {});
    } catch (e) {
      debugPrint('[NoticiasService] Audit write failed (non-critical): $e');
    }

    if (noticia.status == NoticiaStatus.published) {
      try {
        await _createNovedad(doc.id, noticia);
      } catch (e) {
        debugPrint('[NoticiasService] Novedad write failed (non-critical): $e');
      }
    }

    return doc.id;
  }

  Future<void> updateNoticia(String id, Noticia noticia, String updatedBy,
      {Noticia? previousVersion}) async {
    final data = noticia.toFirestore();
    data['updatedAt'] = FieldValue.serverTimestamp();
    data['updatedBy'] = updatedBy;
    await _db.collection(_collection).doc(id).update(data);

    // Secondary write: audit — non-blocking
    final changes = <String, dynamic>{};
    if (previousVersion != null) {
      if (previousVersion.title != noticia.title) {
        changes['title'] = {'from': previousVersion.title, 'to': noticia.title};
      }
      if (previousVersion.status != noticia.status) {
        changes['status'] = {
          'from': previousVersion.status.name,
          'to': noticia.status.name
        };
      }
      if (previousVersion.visibility != noticia.visibility) {
        changes['visibility'] = {
          'from': previousVersion.visibility.name,
          'to': noticia.visibility.name
        };
      }
    }
    try {
      await _addAuditEntry(id, 'updated', updatedBy, changes);
    } catch (e) {
      debugPrint('[NoticiasService] Audit write failed (non-critical): $e');
    }
  }

  Future<void> deleteNoticia(String id) async {
    await _db.collection(_collection).doc(id).delete();
  }

  Future<void> archiveNoticia(String id, String archivedBy) async {
    await _db.collection(_collection).doc(id).update({
      'status': NoticiaStatus.archived.name,
      'publicado': false,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': archivedBy,
    });
    try {
      await _addAuditEntry(id, 'archived', archivedBy, {});
    } catch (e) {
      debugPrint('[NoticiasService] Audit write failed (non-critical): $e');
    }
  }

  Future<void> publishNoticia(String id, String publishedBy) async {
    await _db.collection(_collection).doc(id).update({
      'status': NoticiaStatus.published.name,
      'publicado': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': publishedBy,
    });
    try {
      await _addAuditEntry(id, 'published', publishedBy, {});
    } catch (e) {
      debugPrint('[NoticiasService] Audit write failed (non-critical): $e');
    }
  }

  // -------------------------------------------------------------------------
  // Read confirmations
  // -------------------------------------------------------------------------

  Future<void> confirmRead(String noticiaId, String cofradeId) async {
    await _db
        .collection(_collection)
        .doc(noticiaId)
        .collection('reads')
        .doc(cofradeId)
        .set({
      'cofradeId': cofradeId,
      'readAt': FieldValue.serverTimestamp(),
    });

    // Increment counter
    await _db.collection(_collection).doc(noticiaId).update({
      'readCount': FieldValue.increment(1),
    });
  }

  Future<bool> hasConfirmedRead(String noticiaId, String cofradeId) async {
    final doc = await _db
        .collection(_collection)
        .doc(noticiaId)
        .collection('reads')
        .doc(cofradeId)
        .get();
    return doc.exists;
  }

  Stream<List<Map<String, dynamic>>> getReadConfirmations(String noticiaId) {
    return _db
        .collection(_collection)
        .doc(noticiaId)
        .collection('reads')
        .orderBy('readAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {'cofradeId': d.id, ...d.data()})
            .toList());
  }

  /// Noticias pending read confirmation for a cofrade.
  Stream<List<Noticia>> getPendingReadConfirmations(Cofrade cofrade) {
    final allTags = [...cofrade.tagsManual, ...cofrade.tagsAuto];
    return getAllNoticias().asyncMap((all) async {
      final pending = <Noticia>[];
      for (final n in all) {
        if (!n.isCurrentlyVisible) continue;
        if (!n.requireReadConfirmation) continue;
        if (!n.canCofradeAccess(allTags)) continue;
        final confirmed = await hasConfirmedRead(n.id, cofrade.id);
        if (!confirmed) pending.add(n);
      }
      return pending;
    });
  }

  // -------------------------------------------------------------------------
  // Analytics
  // -------------------------------------------------------------------------

  Future<void> incrementViews(String noticiaId) async {
    await _db.collection(_collection).doc(noticiaId).update({
      'views': FieldValue.increment(1),
    });
  }

  Future<void> registerCtaClick(String noticiaId, String ctaLabel) async {
    await _db.collection(_collection).doc(noticiaId).update({
      'clickCount': FieldValue.increment(1),
    });
    await _db
        .collection(_collection)
        .doc(noticiaId)
        .collection('analytics')
        .add({
      'type': 'cta_click',
      'ctaLabel': ctaLabel,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Analytics summary for a noticia.
  Future<Map<String, dynamic>> getAnalytics(String noticiaId) async {
    final doc = await _db.collection(_collection).doc(noticiaId).get();
    if (!doc.exists) return {};
    final data = doc.data()!;

    final readSnap = await _db
        .collection(_collection)
        .doc(noticiaId)
        .collection('reads')
        .get();

    final clickSnap = await _db
        .collection(_collection)
        .doc(noticiaId)
        .collection('analytics')
        .where('type', isEqualTo: 'cta_click')
        .get();

    return {
      'views': data['views'] ?? 0,
      'readCount': readSnap.docs.length,
      'clickCount': clickSnap.docs.length,
      'ctaClicks': clickSnap.docs
          .map((d) => d.data())
          .toList(),
    };
  }

  /// Global analytics dashboard data.
  Stream<Map<String, dynamic>> getGlobalAnalytics() {
    return getAllNoticias().map((all) {
      final published =
          all.where((n) => n.status == NoticiaStatus.published).toList();
      final totalViews = published.fold<int>(0, (sum, n) => sum + n.views);
      final totalReads = published.fold<int>(0, (sum, n) => sum + n.readCount);
      final totalClicks =
          published.fold<int>(0, (sum, n) => sum + n.clickCount);

      // Most viewed
      final sorted = [...published]
        ..sort((a, b) => b.views.compareTo(a.views));
      final mostViewed = sorted.take(5).toList();

      // By category
      final byCategory = <String, int>{};
      for (final n in published) {
        byCategory[n.category] = (byCategory[n.category] ?? 0) + 1;
      }

      return {
        'totalPublished': published.length,
        'totalDraft': all.where((n) => n.isDraft).length,
        'totalViews': totalViews,
        'totalReads': totalReads,
        'totalClicks': totalClicks,
        'mostViewed': mostViewed,
        'byCategory': byCategory,
      };
    });
  }

  // -------------------------------------------------------------------------
  // Audit
  // -------------------------------------------------------------------------

  Future<void> _addAuditEntry(String noticiaId, String action,
      String userId, Map<String, dynamic> changes) async {
    await _db
        .collection(_collection)
        .doc(noticiaId)
        .collection('audit')
        .add({
      'action': action,
      'userId': userId,
      'changes': changes,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> getAuditLog(String noticiaId) {
    return _db
        .collection(_collection)
        .doc(noticiaId)
        .collection('audit')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  // -------------------------------------------------------------------------
  // Slug validation
  // -------------------------------------------------------------------------

  Future<bool> isSlugAvailable(String slug, {String? excludeId}) async {
    final snap = await _db
        .collection(_collection)
        .where('slug', isEqualTo: slug)
        .limit(2)
        .get();
    if (snap.docs.isEmpty) return true;
    if (excludeId != null && snap.docs.length == 1) {
      return snap.docs.first.id == excludeId;
    }
    return false;
  }

  // -------------------------------------------------------------------------
  // Novedades integration
  // -------------------------------------------------------------------------

  Future<void> _createNovedad(String noticiaId, Noticia noticia) async {
    await _db.collection('novedades').add({
      'tipo': 'noticia',
      'titulo': noticia.title,
      'descripcion': noticia.shortDescription.isNotEmpty
          ? noticia.shortDescription
          : noticia.content,
      'referencia_id': 'noticia_$noticiaId',
      'ruta': noticia.slug.isNotEmpty
          ? '/noticias/${noticia.slug}'
          : '/noticias?id=$noticiaId',
      'visible_para': noticia.visibility == NoticiaVisibility.publica
          ? 'todos'
          : 'cofrades',
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  // -------------------------------------------------------------------------
  // Visibility helper (mirrors encuesta pattern)
  // -------------------------------------------------------------------------

  static bool isNoticiaVisibleForMember(Noticia noticia, Cofrade cofrade) {
    if (!noticia.isCurrentlyVisible) return false;
    final allTags = [...cofrade.tagsManual, ...cofrade.tagsAuto];
    return noticia.canCofradeAccess(allTags);
  }

  // -------------------------------------------------------------------------
  // Dismissed urgent banners (per session / local)
  // -------------------------------------------------------------------------

  final Set<String> _dismissedBanners = {};

  void dismissBanner(String noticiaId) => _dismissedBanners.add(noticiaId);

  bool isBannerDismissed(String noticiaId) =>
      _dismissedBanners.contains(noticiaId);
}
