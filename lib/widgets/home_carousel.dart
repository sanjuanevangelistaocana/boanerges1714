import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/models/gallery.dart';
import 'package:boanerges1714/services/gallery_service.dart';

class HomeCarousel extends StatefulWidget {
  final Widget Function(BuildContext context, Widget carousel) fallback;
  final Widget? overlay;

  const HomeCarousel({super.key, required this.fallback, this.overlay});

  @override
  State<HomeCarousel> createState() => _HomeCarouselState();
}

class _HomeCarouselState extends State<HomeCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _index = 0;
  bool _paused = false;
  List<GalleryImage> _images = const [];

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _syncTimer() {
    _timer?.cancel();
    if (_paused ||
        MediaQuery.maybeDisableAnimationsOf(context) == true ||
        _images.length < 2) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || _paused) return;
      _controller.nextPage(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _setPaused(bool value) {
    if (_paused == value) return;
    setState(() => _paused = value);
    _syncTimer();
  }

  void _precacheNext(BuildContext context) {
    if (_images.length < 2) return;
    final next = (_index + 1) % _images.length;
    final image = _images[next];
    final width = MediaQuery.sizeOf(context).width;
    final source = width < 700
        ? (image.thumbUrl?.isNotEmpty == true ? image.thumbUrl! : image.url)
        : image.url;
    precacheImage(CachedNetworkImageProvider(source), context);
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<GalleryService>();
    return StreamBuilder<List<GalleryImage>>(
      stream: service.watchCarouselImages(),
      builder: (context, snapshot) {
        final images = snapshot.data ?? const <GalleryImage>[];
        if (images.isEmpty) return widget.fallback(context, const SizedBox());
        _images = images;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _syncTimer();
            _precacheNext(context);
          }
        });
        final wide = MediaQuery.sizeOf(context).width >= 700;
        final height = wide ? 360.0 : 240.0;
        return Semantics(
          container: true,
          label: 'Carrusel de imágenes de la Cofradía',
          child: MouseRegion(
            onEnter: (_) => _setPaused(true),
            onExit: (_) => _setPaused(false),
            child: FocusableActionDetector(
              onFocusChange: _setPaused,
              child: SizedBox(
                height: height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PageView.builder(
                      controller: _controller,
                      itemCount: images.length,
                      onPageChanged: (value) {
                        setState(() => _index = value);
                        _precacheNext(context);
                      },
                      itemBuilder: (context, index) {
                        final image = images[index];
                        final source = wide
                            ? image.url
                            : (image.thumbUrl?.isNotEmpty == true
                                ? image.thumbUrl!
                                : image.url);
                        return Semantics(
                          image: true,
                          label: image.nombre,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CachedNetworkImage(
                                imageUrl: source,
                                fit: BoxFit.cover,
                                memCacheWidth:
                                    (MediaQuery.sizeOf(context).width * 1.5)
                                        .round(),
                                fadeInDuration:
                                    const Duration(milliseconds: 200),
                                placeholder: (_, __) => const ColoredBox(
                                  color: AppTheme.primaryDark,
                                  child: Center(
                                      child: CircularProgressIndicator()),
                                ),
                              ),
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black87
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    if (widget.overlay != null)
                      Positioned.fill(child: widget.overlay!),
                    if (wide && images.length > 1)
                      _CarouselArrow(
                        left: true,
                        onPressed: () => _controller.previousPage(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                        ),
                      ),
                    if (wide && images.length > 1)
                      _CarouselArrow(
                        onPressed: () => _controller.nextPage(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                        ),
                      ),
                    if (images.length > 1)
                      Positioned(
                        bottom: 16,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            images.length,
                            (dot) => Semantics(
                              label: 'Imagen ${dot + 1} de ${images.length}',
                              selected: dot == _index,
                              child: Container(
                                width: dot == _index ? 22 : 8,
                                height: 8,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CarouselArrow extends StatelessWidget {
  final bool left;
  final VoidCallback onPressed;

  const _CarouselArrow({this.left = false, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: left ? Alignment.centerLeft : Alignment.centerRight,
      child: IconButton(
        tooltip: left ? 'Imagen anterior' : 'Imagen siguiente',
        onPressed: onPressed,
        icon: Icon(
          left ? Icons.chevron_left : Icons.chevron_right,
          color: Colors.white,
          size: 36,
        ),
        style: IconButton.styleFrom(
          backgroundColor: Colors.black45,
          minimumSize: const Size(48, 48),
        ),
      ),
    );
  }
}
