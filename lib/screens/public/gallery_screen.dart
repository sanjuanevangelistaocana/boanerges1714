import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/models/gallery.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/services/gallery_service.dart';

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
                          return const _GalleryMessage(
                            icon: Icons.error_outline,
                            title: 'No se ha podido cargar la galería',
                            message:
                                'Inténtalo de nuevo dentro de unos instantes.',
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
                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 900
                                ? 4
                                : constraints.maxWidth >= 600
                                    ? 3
                                    : 2;
                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: folders.length,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 0.82,
                              ),
                              itemBuilder: (_, index) => _FolderCard(
                                folder: folders[index],
                                showPrivate: isLoggedIn,
                              ),
                            );
                          },
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/gallery/${folder.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: folder.coverImageUrl?.isNotEmpty == true
                  ? CachedNetworkImage(
                      imageUrl: folder.coverImageUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      memCacheWidth: 700,
                      placeholder: (_, __) =>
                          const _ImagePlaceholder(icon: Icons.photo),
                      errorWidget: (_, __, ___) =>
                          const _ImagePlaceholder(icon: Icons.broken_image),
                    )
                  : const _ImagePlaceholder(icon: Icons.photo_library),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    folder.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      const Icon(Icons.photo_outlined,
                          size: 16, color: AppTheme.textSecondary),
                      const SizedBox(width: 5),
                      Text('${folder.numFotos} fotos',
                          style: Theme.of(context).textTheme.bodySmall),
                      const Spacer(),
                      if (showPrivate && !folder.publica)
                        const Tooltip(
                          message: 'Privada',
                          child: Icon(Icons.lock_outline,
                              size: 17, color: AppTheme.textSecondary),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('d MMM yyyy', 'es_ES')
                        .format(folder.fechaCreacion),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
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
