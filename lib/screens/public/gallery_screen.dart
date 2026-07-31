import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/models/gallery.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/services/gallery_service.dart';
import 'package:boanerges1714/utils/gallery_error.dart';
import 'package:boanerges1714/widgets/responsive_layout.dart';

class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final service = context.read<GalleryService>();
    final isLoggedIn = auth.isLoggedIn;

    return SingleChildScrollView(
      child: Column(
        children: [
          _GalleryHero(isLoggedIn: isLoggedIn),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  children: [
                    if (isLoggedIn)
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: () => context.push('/gallery/upload'),
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Enviar fotografías'),
                        ),
                      ),
                    if (isLoggedIn) const SizedBox(height: 20),
                    StreamBuilder<List<GalleryFolder>>(
                      stream: service.watchFolders(onlyPublic: !isLoggedIn),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          debugPrint('[GalleryScreen] query gallery_folders '
                              'onlyPublic=${!isLoggedIn} '
                              'solo_admin=false deleted=false orderBy=orden '
                              'error: ${snapshot.error}');
                          return _GalleryMessage(
                            icon: Icons.error_outline,
                            title: 'No se ha podido cargar la galería',
                            message: galleryErrorMessage(snapshot.error!),
                          );
                        }
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(64),
                            child: CircularProgressIndicator(),
                          );
                        }
                        final folders = snapshot.data ?? const [];
                        if (folders.isEmpty) {
                          return const _GalleryMessage(
                            icon: Icons.photo_library_outlined,
                            title: 'Todavía no hay álbumes',
                            message:
                                'Pronto compartiremos aquí los recuerdos de la Cofradía.',
                          );
                        }
                        return ResponsiveGrid(
                          smallColumns: 1,
                          mediumColumns: 2,
                          largeColumns: 3,
                          wideColumns: 4,
                          children: [
                            for (final folder in folders)
                              _FolderCard(
                                folder: folder,
                                showPrivate: isLoggedIn,
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryHero extends StatelessWidget {
  final bool isLoggedIn;
  const _GalleryHero({required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryDark, AppTheme.primaryColor],
        ),
      ),
      child: Column(
        children: [
          Text(
            'Galería',
            style: Theme.of(context)
                .textTheme
                .headlineLarge
                ?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            isLoggedIn
                ? 'Todos los recuerdos de nuestra Cofradía'
                : 'Imágenes y recuerdos de nuestra Cofradía',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppTheme.accentColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _FolderCard extends StatelessWidget {
  final GalleryFolder folder;
  final bool showPrivate;

  const _FolderCard({
    required this.folder,
    required this.showPrivate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: () => context.push('/gallery/${folder.id}'),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (folder.coverImageUrl?.isNotEmpty == true)
              CachedNetworkImage(
                imageUrl: folder.coverImageUrl!,
                fit: BoxFit.cover,
                memCacheWidth: 700,
                placeholder: (_, __) =>
                    const _ImagePlaceholder(icon: Icons.photo),
                errorWidget: (_, __, ___) =>
                    const _ImagePlaceholder(icon: Icons.broken_image),
              )
            else
              const _ImagePlaceholder(icon: Icons.photo_library),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                  stops: [0.35, 1],
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    folder.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.photo_outlined,
                          size: 17, color: Colors.white70),
                      const SizedBox(width: 5),
                      Text(
                        '${folder.numFotos} fotos',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (showPrivate && !folder.publica)
                        const Chip(
                          avatar: Icon(Icons.lock_outline,
                              size: 15, color: Colors.white),
                          label: Text('Privada'),
                          visualDensity: VisualDensity.compact,
                          labelStyle: TextStyle(color: Colors.white),
                          backgroundColor: Colors.black45,
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    DateFormat('d MMM yyyy', 'es_ES')
                        .format(folder.fechaCreacion),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final IconData icon;
  const _ImagePlaceholder({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.primaryColor.withAlpha(20),
      alignment: Alignment.center,
      child: Icon(icon, size: 42, color: AppTheme.textSecondary),
    );
  }
}

class _GalleryMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _GalleryMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, size: 60, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
