import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:boanerges1714/config/theme.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _mensajeController = TextEditingController();
  bool _enviado = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _mensajeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryDark, AppTheme.primaryColor],
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Contacto',
                  style: Theme.of(context)
                      .textTheme
                      .headlineLarge
                      ?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ponte en contacto con nosotros',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: AppTheme.accentColor),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                children: [
                  // Contact info cards
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    alignment: WrapAlignment.center,
                    children: [
                      _ContactCard(
                        icon: Icons.email,
                        title: 'Email',
                        subtitle: 'sanjuanevangelistaocana@gmail.com',
                        onTap: () => _launchEmail(),
                      ),
                      _ContactCard(
                        icon: Icons.location_on,
                        title: 'Ubicación',
                        subtitle: 'Ocaña, Toledo\nCastilla-La Mancha',
                        onTap: () {},
                      ),
                      _ContactCard(
                        icon: Icons.church,
                        title: 'Parroquia',
                        subtitle: 'Ocaña, Toledo',
                        onTap: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Contact form
                  Text(
                    'Envíanos un mensaje',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '¿Quieres unirte a la Cofradía? ¿Tienes alguna pregunta? '
                    'Escríbenos y te responderemos lo antes posible.',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (_enviado)
                    Card(
                      color: Colors.green[50],
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Mensaje enviado correctamente. '
                                'Te responderemos lo antes posible.',
                                style: TextStyle(color: Colors.green),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nombreController,
                            decoration:
                                const InputDecoration(labelText: 'Nombre'),
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Introduce tu nombre' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                                labelText: 'Email de contacto'),
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) =>
                                v == null || !v.contains('@') ? 'Email no válido' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _mensajeController,
                            decoration:
                                const InputDecoration(labelText: 'Mensaje'),
                            maxLines: 5,
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Escribe un mensaje' : null,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _enviarMensaje,
                              icon: const Icon(Icons.send),
                              label: const Text('Enviar Mensaje'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 32),
                  // How to join
                  Card(
                    color: AppTheme.primaryColor.withAlpha(25),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(Icons.people,
                              size: 48, color: AppTheme.primaryColor),
                          const SizedBox(height: 12),
                          Text('¿Quieres ser cofrade?',
                              style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 8),
                          Text(
                            'Si deseas formar parte de nuestra Cofradía, '
                            'contacta con nosotros a través de este formulario '
                            'o envíanos un email. Te informaremos de los requisitos '
                            'y el proceso de ingreso.',
                            style: Theme.of(context).textTheme.bodyLarge,
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
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  void _enviarMensaje() {
    if (_formKey.currentState!.validate()) {
      setState(() => _enviado = true);
    }
  }

  Future<void> _launchEmail() async {
    final uri = Uri.parse('mailto:sanjuanevangelistaocana@gmail.com');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

class _ContactCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ContactCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(icon, size: 36, color: AppTheme.primaryColor),
                const SizedBox(height: 8),
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
