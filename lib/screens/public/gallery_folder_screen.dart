import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/models/gallery.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/services/gallery_service.dart';

class GalleryFolderScreen extends StatefulWidget {
  final String folderId;

  const GalleryFolderScreen({required this.folderId, super.key});

  @override
  State<GalleryFolderScreen> createState() => _GalleryFolderScreenState();
}

class _GalleryFolderScreenState extends State<GalleryFolderScreen> {
  final _scrollController = ScrollController();
  final _images = <GalleryImage>[];
  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _initialRequested = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 500 &&
        !_loading &&
        !_loadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadInitial({required bool onlyPublic}) async {
    if (_initialRequested) return;
    _initialRequested = true;
    try {
      final page = await context.read<GalleryService>().fetchImagesPageWithCursor(
            folderId: widget.folderId,
            onlyPublic: onlyPublic,
          );
      if (!mounted) return;
      setState(() {
        _images
          ..clear()
          ..addAll(page.images);
        _lastDocument = page.lastDocument;
        _hasMore = page.hasMore;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final auth = context.read<AuthService>();
      final page =
          await context.read<GalleryService>().fetchImagesPageWithCursor(
                folderId: widget.folderId,
                startAfter: _lastDocument,
                onlyPublic: !auth.isLoggedIn,
              );
      if (!mounted) return;
      setState(() {
        _images.addAll(page.images);
        _lastDocument = page.lastDocument;
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final service = context.read<GalleryService>();
    final isLoggedIn = auth.isLoggedIn;

    return StreamBuilder<GalleryFolder?>(
      stream: service.watchFolder(widget.folderId),
      builder: (context, folderSnapshot) {
        if (folderSnapshot.hasError && !isLoggedIn) {
          return _FolderState(
            icon: Icons.lock_outline,
            title: 'Contenido solo para cofrades',
            message: 'Inicia sesión para acceder a este álbum privado.',
            action: FilledButton(
              onPressed: () => context.go('/login'),
              child: const Text('Iniciar sesión'),
            ),
          );
        }
        if (folderSnapshot.hasError) {
          return _FolderState(
            icon: Icons.error_outline,
            title: 'No se ha podido cargar el álbum',
            message: 'Comprueba tu conexión e inténtalo de nuevo.',
          );
        }
        if (folderSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final folder = folderSnapshot.data;
        if (folder == null || folder.deleted) {
          return _FolderState(
            icon: Icons.photo_library_outlined,
            title: 'Álbum no disponible',
            message: 'Este álbum ya no está disponible.',
          );
        }
        if (!folder.publica && !isLoggedIn) {
          return _FolderState(
            icon: Icons.lock_outline,
            title: 'Contenido solo para cofrades',
            message: 'Inicia sesión para acceder a este álbum privado.',
            action: FilledButton(
              onPressed: () => context.go('/login'),
              child: const Text('Iniciar sesión'),
            ),
          );
        }
        if (_loading && _images.isEmpty && !_initialRequested) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _loadInitial(onlyPublic: !isLoggedIn);
          });
        }
        return _FolderContent(
          folder: folder,
          images: _images,
          scrollController: _scrollController,
          loading: _loading,
          loadingMore: _loadingMore,
          hasMore: _hasMore,
          error: _error,
          onRetry: () {
            setState(() {
              _images.clear();
              _lastDocument = null;
              _hasMore = true;
              _loading = true;
              _initialRequested = false;
            });
            _loadInitial(onlyPublic: !isLoggedIn);
          },
          onImageTap: (index) => showDialog(
            context: context,
            builder: (_) => _GalleryLightbox(
              images: _images,
              initialIndex: index,
              canDownload: isLoggedIn,
            ),
          ),
        );
      },
    );
  }
}

class _FolderContent extends StatelessWidget {
  final GalleryFolder folder;
  final List<GalleryImage> images;
  final ScrollController scrollController;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final Object? error;
  final VoidCallback onRetry;
  final ValueChanged<int> onImageTap;

  const _FolderContent({
    required this.folder,
    required this.images,
    required this.scrollController,
    required this.loading,
    required this.loadingMore,
    required this.hasMore,
    required this.error,
    required this.onRetry,
    required this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(folder.nombre,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium),
                          if (folder.descripcion?.isNotEmpty == true) ...[
                            const SizedBox(height: 6),
                            Text(folder.descripcion!,
                                style: Theme.of(context).textTheme.bodyLarge),
                          ],
                          const SizedBox(height: 7),
                          Text(
                            '${folder.numFotos} fotos · ${DateFormat('d MMM yyyy', 'es_ES').format(folder.fechaCreacion)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (!folder.publica)
                      const Chip(
                        avatar: Icon(Icons.lock_outline, size: 16),
                        label: Text('Privada'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (loading && images.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (error != null && images.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _FolderState(
              icon: Icons.error_outline,
              title: 'No se han podido cargar las fotografías',
              message: 'Comprueba tu conexión e inténtalo de nuevo.',
              action: OutlinedButton(
                onPressed: onRetry,
                child: const Text('Reintentar'),
              ),
            ),
          )
        else if (images.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _FolderState(
              icon: Icons.photo_outlined,
              title: 'Este álbum no tiene fotografías',
              message: 'Todavía no hay imágenes disponibles.',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.crossAxisExtent;
                final columns = width >= 1000
                    ? 5
                    : width >= 700
                        ? 4
                        : width >= 450
                            ? 3
                            : 2;
                return SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == images.length) {
                        return loadingMore
                            ? const Center(child: CircularProgressIndicator())
                            : const SizedBox.shrink();
                      }
                      return _GalleryImageTile(
                        image: images[index],
                        onTap: () => onImageTap(index),
                      );
                    },
                    childCount: images.length + (loadingMore ? 1 : 0),
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                );
              },
            ),
          ),
        if (hasMore && !loadingMore && images.isNotEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(bottom: 32),
              child: Center(child: Text('Desplázate para ver más')),
            ),
          ),
      ],
    );
  }
}

class _GalleryImageTile extends StatelessWidget {
  final GalleryImage image;
  final VoidCallback onTap;

  const _GalleryImageTile({required this.image, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final source = image.thumbUrl?.isNotEmpty == true
        ? image.thumbUrl!
        : image.url;
    return InkWell(
      onTap: onTap,
      child: CachedNetworkImage(
        imageUrl: source,
        fit: BoxFit.cover,
        memCacheWidth: 500,
        placeholder: (_, __) => Container(
          color: AppTheme.primaryColor.withAlpha(18),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined),
      ),
    );
  }
}

class _GalleryLightbox extends StatefulWidget {
  final List<GalleryImage> images;
  final int initialIndex;
  final bool canDownload;

  const _GalleryLightbox({
    required this.images,
    required this.initialIndex,
    required this.canDownload,
  });

  @override
  State<_GalleryLightbox> createState() => _GalleryLightboxState();
}

class _GalleryLightboxState extends State<_GalleryLightbox> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _change(int delta) {
    final next =
        (_index + delta).clamp(0, widget.images.length - 1).toInt();
    if (next == _index) return;
    _controller.animateToPage(next,
        duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _change(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _change(1),
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: Focus(
        autofocus: true,
        child: Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder: (context, constraints) => SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _controller,
                    itemCount: widget.images.length,
                    onPageChanged: (value) => setState(() => _index = value),
                    itemBuilder: (_, index) => InteractiveViewer(
                      child: CachedNetworkImage(
                        imageUrl: widget.images[index].url,
                        fit: BoxFit.contain,
                        memCacheWidth: 1800,
                        placeholder: (_, __) => const Center(
                            child: CircularProgressIndicator()),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 28),
                    ),
                  ),
                  if (_index > 0)
                    _LightboxArrow(
                      left: true,
                      onPressed: () => _change(-1),
                    ),
                  if (_index < widget.images.length - 1)
                    _LightboxArrow(
                      onPressed: () => _change(1),
                    ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 12,
                    child: _PhotoInfo(
                      image: widget.images[_index],
                      canDownload: widget.canDownload,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LightboxArrow extends StatelessWidget {
  final bool left;
  final VoidCallback onPressed;

  const _LightboxArrow({this.left = false, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left ? 8 : null,
      right: left ? null : 8,
      top: 0,
      bottom: 70,
      child: Center(
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(left ? Icons.chevron_left : Icons.chevron_right,
              color: Colors.white, size: 38),
        ),
      ),
    );
  }
}

class _PhotoInfo extends StatelessWidget {
  final GalleryImage image;
  final bool canDownload;

  const _PhotoInfo({required this.image, required this.canDownload});

  @override
  Widget build(BuildContext context) {
    final details = [
      image.nombre,
      DateFormat('d MMM yyyy', 'es_ES').format(image.fechaSubida),
      if (image.autor?.isNotEmpty == true)
        'Autor: ${image.autor}',
      if (image.autor?.isNotEmpty != true &&
          image.uploadedByNombre?.isNotEmpty == true)
        image.uploadedByNombre!,
      if (image.width != null && image.height != null)
        '${image.width} × ${image.height}px',
      '${(image.tamanoBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
    ].join(' · ');
    return Material(
      color: Colors.black.withAlpha(190),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(details,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white)),
            ),
            if (canDownload)
              IconButton(
                tooltip: 'Descargar',
                onPressed: () => launchUrl(Uri.parse(image.url),
                    mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.download, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}

class _FolderState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const _FolderState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge),
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
