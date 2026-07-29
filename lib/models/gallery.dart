import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _galleryDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

List<String> _galleryStrings(dynamic value) {
  if (value is! List) return const [];
  return value.map((item) => '$item').toList();
}

enum GalleryImageStatus { pendiente, aprobada }

enum GalleryUploadRequestStatus {
  pendiente,
  aprobado,
  rechazado,
  procesado,
}

class GalleryFolder {
  final String id;
  final String nombre;
  final String? descripcion;
  final String? coverImageId;
  final String? coverImageUrl;
  final bool publica;
  final int orden;
  final int numFotos;
  final DateTime fechaCreacion;
  final DateTime fechaActualizacion;
  final String createdBy;
  final bool deleted;
  final bool relocating;
  final List<String> tags;
  final bool destacada;
  final int? anio;

  const GalleryFolder({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.coverImageId,
    this.coverImageUrl,
    this.publica = false,
    this.orden = 0,
    this.numFotos = 0,
    required this.fechaCreacion,
    required this.fechaActualizacion,
    this.createdBy = '',
    this.deleted = false,
    this.relocating = false,
    this.tags = const [],
    this.destacada = false,
    this.anio,
  });

  factory GalleryFolder.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return GalleryFolder(
      id: doc.id,
      nombre: '${data['nombre'] ?? data['name'] ?? ''}',
      descripcion: data['descripcion'] as String? ??
          data['description'] as String?,
      coverImageId: data['cover_image_id'] as String?,
      coverImageUrl: data['cover_image_url'] as String?,
      publica: data['publica'] == true || data['public'] == true,
      orden: (data['orden'] as num?)?.toInt() ?? 0,
      numFotos: (data['num_fotos'] as num?)?.toInt() ?? 0,
      fechaCreacion: _galleryDate(data['fecha_creacion']) ?? DateTime.now(),
      fechaActualizacion:
          _galleryDate(data['fecha_actualizacion']) ?? DateTime.now(),
      createdBy: '${data['created_by'] ?? data['createdBy'] ?? ''}',
      deleted: data['deleted'] == true,
      relocating: data['relocating'] == true,
      tags: _galleryStrings(data['tags']),
      destacada: data['destacada'] == true,
      anio: (data['anio'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'nombre': nombre,
        'descripcion': descripcion,
        'cover_image_id': coverImageId,
        'cover_image_url': coverImageUrl,
        'publica': publica,
        'orden': orden,
        'num_fotos': numFotos,
        'fecha_creacion': Timestamp.fromDate(fechaCreacion),
        'fecha_actualizacion': Timestamp.fromDate(fechaActualizacion),
        'created_by': createdBy,
        'deleted': deleted,
        'relocating': relocating,
        'tags': tags,
        'destacada': destacada,
        'anio': anio,
      };

  GalleryFolder copyWith({
    String? id,
    String? nombre,
    String? descripcion,
    String? coverImageId,
    String? coverImageUrl,
    bool? publica,
    int? orden,
    int? numFotos,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
    String? createdBy,
    bool? deleted,
    bool? relocating,
    List<String>? tags,
    bool? destacada,
    int? anio,
  }) =>
      GalleryFolder(
        id: id ?? this.id,
        nombre: nombre ?? this.nombre,
        descripcion: descripcion ?? this.descripcion,
        coverImageId: coverImageId ?? this.coverImageId,
        coverImageUrl: coverImageUrl ?? this.coverImageUrl,
        publica: publica ?? this.publica,
        orden: orden ?? this.orden,
        numFotos: numFotos ?? this.numFotos,
        fechaCreacion: fechaCreacion ?? this.fechaCreacion,
        fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
        createdBy: createdBy ?? this.createdBy,
        deleted: deleted ?? this.deleted,
        relocating: relocating ?? this.relocating,
        tags: tags ?? this.tags,
        destacada: destacada ?? this.destacada,
        anio: anio ?? this.anio,
      );
}

class GalleryImage {
  final String id;
  final String folderId;
  final String nombre;
  final String storagePath;
  final String url;
  final String? thumbPath;
  final String? thumbUrl;
  final String uploadedBy;
  final String? uploadedByNombre;
  final DateTime fechaSubida;
  final int tamanoBytes;
  final int? width;
  final int? height;
  final int orden;
  final GalleryImageStatus estado;
  final bool publica;
  final bool deleted;
  final List<String> tags;
  final String? eventId;
  final int? anio;
  final String? autor;

  const GalleryImage({
    required this.id,
    required this.folderId,
    required this.nombre,
    required this.storagePath,
    required this.url,
    this.thumbPath,
    this.thumbUrl,
    required this.uploadedBy,
    this.uploadedByNombre,
    required this.fechaSubida,
    this.tamanoBytes = 0,
    this.width,
    this.height,
    this.orden = 0,
    this.estado = GalleryImageStatus.pendiente,
    this.publica = false,
    this.deleted = false,
    this.tags = const [],
    this.eventId,
    this.anio,
    this.autor,
  });

  factory GalleryImage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rawStatus = '${data['estado'] ?? GalleryImageStatus.pendiente.name}';
    return GalleryImage(
      id: doc.id,
      folderId: '${data['folder_id'] ?? data['folderId'] ?? ''}',
      nombre: '${data['nombre'] ?? data['name'] ?? ''}',
      storagePath: '${data['storage_path'] ?? data['storagePath'] ?? ''}',
      url: '${data['url'] ?? data['download_url'] ?? ''}',
      thumbPath: data['thumb_path'] as String?,
      thumbUrl: data['thumb_url'] as String?,
      uploadedBy: '${data['uploaded_by'] ?? data['uploadedBy'] ?? ''}',
      uploadedByNombre: data['uploaded_by_nombre'] as String?,
      fechaSubida: _galleryDate(data['fecha_subida']) ?? DateTime.now(),
      tamanoBytes: (data['tamano_bytes'] as num?)?.toInt() ?? 0,
      width: (data['width'] as num?)?.toInt(),
      height: (data['height'] as num?)?.toInt(),
      orden: (data['orden'] as num?)?.toInt() ?? 0,
      estado: GalleryImageStatus.values.firstWhere(
        (item) => item.name == rawStatus,
        orElse: () => GalleryImageStatus.pendiente,
      ),
      publica: data['publica'] == true,
      deleted: data['deleted'] == true,
      tags: _galleryStrings(data['tags']),
      eventId: data['event_id'] as String?,
      anio: (data['anio'] as num?)?.toInt(),
      autor: data['autor'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'folder_id': folderId,
        'nombre': nombre,
        'storage_path': storagePath,
        'url': url,
        'thumb_path': thumbPath,
        'thumb_url': thumbUrl,
        'uploaded_by': uploadedBy,
        'uploaded_by_nombre': uploadedByNombre,
        'fecha_subida': Timestamp.fromDate(fechaSubida),
        'tamano_bytes': tamanoBytes,
        'width': width,
        'height': height,
        'orden': orden,
        'estado': estado.name,
        'publica': publica,
        'deleted': deleted,
        'tags': tags,
        'event_id': eventId,
        'anio': anio,
        'autor': autor,
      };

  GalleryImage copyWith({
    String? id,
    String? folderId,
    String? nombre,
    String? storagePath,
    String? url,
    String? thumbPath,
    String? thumbUrl,
    String? uploadedBy,
    String? uploadedByNombre,
    DateTime? fechaSubida,
    int? tamanoBytes,
    int? width,
    int? height,
    int? orden,
    GalleryImageStatus? estado,
    bool? publica,
    bool? deleted,
    List<String>? tags,
    String? eventId,
    int? anio,
    String? autor,
  }) =>
      GalleryImage(
        id: id ?? this.id,
        folderId: folderId ?? this.folderId,
        nombre: nombre ?? this.nombre,
        storagePath: storagePath ?? this.storagePath,
        url: url ?? this.url,
        thumbPath: thumbPath ?? this.thumbPath,
        thumbUrl: thumbUrl ?? this.thumbUrl,
        uploadedBy: uploadedBy ?? this.uploadedBy,
        uploadedByNombre: uploadedByNombre ?? this.uploadedByNombre,
        fechaSubida: fechaSubida ?? this.fechaSubida,
        tamanoBytes: tamanoBytes ?? this.tamanoBytes,
        width: width ?? this.width,
        height: height ?? this.height,
        orden: orden ?? this.orden,
        estado: estado ?? this.estado,
        publica: publica ?? this.publica,
        deleted: deleted ?? this.deleted,
        tags: tags ?? this.tags,
        eventId: eventId ?? this.eventId,
        anio: anio ?? this.anio,
        autor: autor ?? this.autor,
      );
}

class GalleryUploadRequest {
  final String id;
  final String titulo;
  final String? descripcion;
  final DateTime? fechaEvento;
  final String zipPath;
  final String zipUrl;
  final int zipSizeBytes;
  final int? numFotosEstimadas;
  final GalleryUploadRequestStatus estado;
  final String? motivoRechazo;
  final String createdBy;
  final String createdByNombre;
  final String createdByEmail;
  final DateTime fechaCreacion;
  final DateTime? fechaRevision;
  final String? revisadoPor;
  final List<String> folderDestinoIds;

  const GalleryUploadRequest({
    required this.id,
    required this.titulo,
    this.descripcion,
    this.fechaEvento,
    required this.zipPath,
    required this.zipUrl,
    this.zipSizeBytes = 0,
    this.numFotosEstimadas,
    this.estado = GalleryUploadRequestStatus.pendiente,
    this.motivoRechazo,
    required this.createdBy,
    this.createdByNombre = '',
    this.createdByEmail = '',
    required this.fechaCreacion,
    this.fechaRevision,
    this.revisadoPor,
    this.folderDestinoIds = const [],
  });

  factory GalleryUploadRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rawStatus = '${data['estado'] ?? GalleryUploadRequestStatus.pendiente.name}';
    return GalleryUploadRequest(
      id: doc.id,
      titulo: '${data['titulo'] ?? ''}',
      descripcion: data['descripcion'] as String?,
      fechaEvento: _galleryDate(data['fecha_evento']),
      zipPath: '${data['zip_path'] ?? ''}',
      zipUrl: '${data['zip_url'] ?? ''}',
      zipSizeBytes: (data['zip_size_bytes'] as num?)?.toInt() ?? 0,
      numFotosEstimadas: (data['num_fotos_estimadas'] as num?)?.toInt(),
      estado: GalleryUploadRequestStatus.values.firstWhere(
        (item) => item.name == rawStatus,
        orElse: () => GalleryUploadRequestStatus.pendiente,
      ),
      motivoRechazo: data['motivo_rechazo'] as String?,
      createdBy: '${data['created_by'] ?? ''}',
      createdByNombre: '${data['created_by_nombre'] ?? ''}',
      createdByEmail: '${data['created_by_email'] ?? ''}',
      fechaCreacion: _galleryDate(data['fecha_creacion']) ?? DateTime.now(),
      fechaRevision: _galleryDate(data['fecha_revision']),
      revisadoPor: data['revisado_por'] as String?,
      folderDestinoIds: _galleryStrings(data['folder_destino_ids']),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'titulo': titulo,
        'descripcion': descripcion,
        'fecha_evento':
            fechaEvento == null ? null : Timestamp.fromDate(fechaEvento!),
        'zip_path': zipPath,
        'zip_url': zipUrl,
        'zip_size_bytes': zipSizeBytes,
        'num_fotos_estimadas': numFotosEstimadas,
        'estado': estado.name,
        'motivo_rechazo': motivoRechazo,
        'created_by': createdBy,
        'created_by_nombre': createdByNombre,
        'created_by_email': createdByEmail,
        'fecha_creacion': Timestamp.fromDate(fechaCreacion),
        'fecha_revision':
            fechaRevision == null ? null : Timestamp.fromDate(fechaRevision!),
        'revisado_por': revisadoPor,
        'folder_destino_ids': folderDestinoIds,
      };

  GalleryUploadRequest copyWith({
    String? id,
    String? titulo,
    String? descripcion,
    DateTime? fechaEvento,
    String? zipPath,
    String? zipUrl,
    int? zipSizeBytes,
    int? numFotosEstimadas,
    GalleryUploadRequestStatus? estado,
    String? motivoRechazo,
    String? createdBy,
    String? createdByNombre,
    String? createdByEmail,
    DateTime? fechaCreacion,
    DateTime? fechaRevision,
    String? revisadoPor,
    List<String>? folderDestinoIds,
  }) =>
      GalleryUploadRequest(
        id: id ?? this.id,
        titulo: titulo ?? this.titulo,
        descripcion: descripcion ?? this.descripcion,
        fechaEvento: fechaEvento ?? this.fechaEvento,
        zipPath: zipPath ?? this.zipPath,
        zipUrl: zipUrl ?? this.zipUrl,
        zipSizeBytes: zipSizeBytes ?? this.zipSizeBytes,
        numFotosEstimadas: numFotosEstimadas ?? this.numFotosEstimadas,
        estado: estado ?? this.estado,
        motivoRechazo: motivoRechazo ?? this.motivoRechazo,
        createdBy: createdBy ?? this.createdBy,
        createdByNombre: createdByNombre ?? this.createdByNombre,
        createdByEmail: createdByEmail ?? this.createdByEmail,
        fechaCreacion: fechaCreacion ?? this.fechaCreacion,
        fechaRevision: fechaRevision ?? this.fechaRevision,
        revisadoPor: revisadoPor ?? this.revisadoPor,
        folderDestinoIds: folderDestinoIds ?? this.folderDestinoIds,
      );
}
