import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:boanerges1714/config/theme.dart';

class SocialMediaScreen extends StatelessWidget {
  const SocialMediaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryDark, AppTheme.primaryColor],
              ),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  children: [
                    const Icon(Icons.share, size: 48, color: Colors.white),
                    const SizedBox(height: 12),
                    Text(
                      'Redes Sociales',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Síguenos en nuestras redes para estar al día',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white70,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  children: [
                    _SocialCard(
                      icon: const _InstagramMark(),
                      name: 'Instagram',
                      handle: '@sanjuanevangelistaocana',
                      description:
                          'Fotos, stories y novedades de nuestra cofradía. '
                          'Comparte tus mejores momentos con el hashtag #CofradíaSanJuanEvangelista',
                      color: const Color(0xFFE1306C),
                      url: 'https://www.instagram.com/sanjuanevangelistaocana/',
                    ),
                    const SizedBox(height: 16),
                    _SocialCard(
                      icon: const Icon(
                        Icons.facebook,
                        size: 32,
                        color: Color(0xFF1877F2),
                      ),
                      name: 'Facebook',
                      handle: 'Cofradía San Juan Evangelista de Ocaña',
                      description:
                          'Publicaciones, eventos y comunicados oficiales. '
                          'Dale "Me gusta" a nuestra página para recibir actualizaciones.',
                      color: const Color(0xFF1877F2),
                      url: 'https://www.facebook.com/sanjuanevangelistaocana/',
                    ),
                    const SizedBox(height: 32),
                    Card(
                      elevation: 0,
                      color: AppTheme.primaryColor.withAlpha(10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                            color: AppTheme.primaryColor.withAlpha(30)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Icon(Icons.tag,
                                size: 32, color: AppTheme.primaryColor),
                            const SizedBox(height: 12),
                            Text(
                              '¿Tienes fotos de la cofradía?',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Compártelas en Instagram o Facebook mencionando '
                              '@sanjuanevangelistaocana y las publicaremos en nuestra galería.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
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

class _SocialCard extends StatelessWidget {
  final Widget icon;
  final String name;
  final String handle;
  final String description;
  final Color color;
  final String url;

  const _SocialCard({
    required this.icon,
    required this.name,
    required this.handle,
    required this.description,
    required this.color,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () =>
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label: '$name: $handle',
                button: true,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SizedBox(width: 32, height: 32, child: icon),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: color,
                        )),
                    Text(handle,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        )),
                    const SizedBox(height: 8),
                    Text(description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        )),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.open_in_new,
                              size: 14, color: Colors.white),
                          const SizedBox(width: 6),
                          Text('Visitar $name',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstagramMark extends StatelessWidget {
  const _InstagramMark();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Instagram',
      child: CustomPaint(
        painter: _InstagramPainter(color: const Color(0xFFE1306C)),
      ),
    );
  }
}

class _InstagramPainter extends CustomPainter {
  final Color color;

  const _InstagramPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(8),
    );
    canvas.drawRRect(rect, stroke);
    canvas.drawCircle(
      size.center(Offset.zero),
      size.shortestSide * .25,
      stroke,
    );
    canvas.drawCircle(
      Offset(size.width * .72, size.height * .28),
      2,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _InstagramPainter oldDelegate) =>
      oldDelegate.color != color;
}
