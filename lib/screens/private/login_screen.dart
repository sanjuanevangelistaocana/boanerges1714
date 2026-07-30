import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/services/auth_service.dart';
import 'package:boanerges1714/widgets/app_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _obscurePassword = true;
  bool _loginWithDni = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final redirectError = authService.consumeAuthError();
    final displayedError = _error ?? redirectError;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppLogo(size: 64),
                const SizedBox(height: 16),
                Text(
                  'Cofradía de\nSan Juan Evangelista',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Acceso para cofrades',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Iniciar Sesión',
                              style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 16),
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                  value: false,
                                  label: Text('Email'),
                                  icon: Icon(Icons.email_outlined)),
                              ButtonSegment(
                                  value: true,
                                  label: Text('DNI'),
                                  icon: Icon(Icons.badge_outlined)),
                            ],
                            selected: {_loginWithDni},
                            onSelectionChanged: (v) => setState(() {
                              _loginWithDni = v.first;
                              _error = null;
                              _emailController.clear();
                            }),
                          ),
                          const SizedBox(height: 16),
                          if (displayedError != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: AppTheme.errorColor.withAlpha(25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(displayedError,
                                  style: const TextStyle(
                                      color: AppTheme.errorColor)),
                            ),
                          if (!_loginWithDni)
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) => v == null || !v.contains('@')
                                  ? 'Introduce un email válido'
                                  : null,
                            ),
                          if (_loginWithDni)
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'DNI / NIE',
                                prefixIcon: Icon(Icons.badge_outlined),
                                hintText: '12345678A',
                              ),
                              textCapitalization: TextCapitalization.characters,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty)
                                  return 'Introduce tu DNI';
                                final cleaned = v
                                    .toUpperCase()
                                    .replaceAll(RegExp(r'[\s\-_.]'), '')
                                    .trim();
                                if (!RegExp(r'^[0-9]{8}[A-Z]$')
                                        .hasMatch(cleaned) &&
                                    !RegExp(r'^[XYZ][0-9]{7}[A-Z]$')
                                        .hasMatch(cleaned)) {
                                  return 'Formato DNI/NIE no válido';
                                }
                                return null;
                              },
                            ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              prefixIcon: const Icon(Icons.lock_outlined),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                                onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            obscureText: _obscurePassword,
                            validator: (v) => v == null || v.length < 6
                                ? 'Mínimo 6 caracteres'
                                : null,
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _showResetPasswordDialog,
                              child: const Text('¿Olvidaste tu contraseña?'),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: authService.isLoading ? null : _signIn,
                              child: authService.isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Entrar'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: authService.isLoading
                                  ? null
                                  : _signInWithGoogle,
                              icon: const _GoogleMark(),
                              label: const Text('Continuar con Google'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('¿Eres cofrade y no tienes cuenta? '),
                    TextButton(
                      onPressed: () => context.go('/register'),
                      child: const Text('Regístrate'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('¿No eres cofrade? '),
                    TextButton(
                      onPressed: () => context.go('/solicitud-alta'),
                      child: const Text('Solicita el alta'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Volver al inicio'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);

    final String? error;
    if (_loginWithDni) {
      error = await context.read<AuthService>().signInWithDni(
            _emailController.text,
            _passwordController.text,
          );
    } else {
      error = await context.read<AuthService>().signIn(
            _emailController.text,
            _passwordController.text,
          );
    }

    if (error != null && mounted) {
      setState(() => _error = error);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _error = null);
    final error = await context.read<AuthService>().signInWithGoogle();
    if (error != null && mounted) {
      setState(() => _error = error);
    }
  }

  void _showResetPasswordDialog() {
    final resetEmailController = TextEditingController(
      text: _emailController.text.trim(),
    );
    final parentContext = context;
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withAlpha(15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_reset,
                      size: 36, color: AppTheme.primaryColor),
                ),
                const SizedBox(height: 16),
                Text(
                  'Recuperar contrase\u00f1a',
                  style:
                      Theme.of(dialogContext).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Introduce el email asociado a tu cuenta de cofrade. '
                  'Te enviaremos un enlace para restablecer tu contrase\u00f1a.',
                  style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: resetEmailController,
                  decoration: InputDecoration(
                    labelText: 'Email de tu cuenta',
                    hintText: 'cofrade@email.com',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppTheme.primaryColor, width: 2),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final email = resetEmailController.text.trim();
                      if (email.isEmpty || !email.contains('@')) {
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          const SnackBar(
                            content: Text('Introduce un email v\u00e1lido.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      Navigator.pop(dialogContext);
                      final error = await parentContext
                          .read<AuthService>()
                          .resetPassword(email);
                      if (parentContext.mounted) {
                        if (error != null) {
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            SnackBar(
                              content: Text(error),
                              backgroundColor: Colors.red,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Email enviado. Revisa tu bandeja de entrada '
                                '(y la carpeta de spam) para restablecer tu contrase\u00f1a.',
                              ),
                              duration: const Duration(seconds: 6),
                              backgroundColor: AppTheme.accentColor,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.send),
                    label: const Text('Enviar enlace'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return Image.network(
      'https://developers.google.com/identity/images/g-logo.png',
      width: 20,
      height: 20,
      errorBuilder: (_, __, ___) => const Text(
        'G',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Color(0xFF4285F4),
          letterSpacing: 0,
        ),
      ),
    );
  }
}
