import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/session.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_scaffold.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final auth = AuthService(context.read<ApiClient>());
    final session = context.read<SessionController>();
    final navigator = Navigator.of(context);
    try {
      final tokens = await auth.register(
        email: _emailController.text.trim(),
        name: _nameController.text.trim(),
        password: _passwordController.text,
      );
      await session.completeLogin(tokens.accessToken, tokens.refreshToken);
      navigator.pop(); // back to AuthGate, now authenticated
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create your account',
      error: _error,
      form: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _FieldLabel('Name'),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'Ada Lovelace',
                prefixIcon: Icon(Icons.person_outline, size: 18),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            const _FieldLabel('Email address'),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                hintText: 'name@company.com',
                prefixIcon: Icon(Icons.mail_outline, size: 18),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Email is required' : null,
            ),
            const SizedBox(height: 16),
            const _FieldLabel('Password'),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(
                hintText: 'At least 8 characters',
                prefixIcon: Icon(Icons.lock_outline, size: 18),
              ),
              obscureText: true,
              onFieldSubmitted: (_) => _submit(),
              validator: (v) =>
                  (v == null || v.length < 8) ? 'Password must be at least 8 characters' : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Register'),
            ),
          ],
        ),
      ),
      footer: GestureDetector(
        onTap: _submitting ? null : () => Navigator.of(context).pop(),
        child: const Text.rich(
          TextSpan(
            text: 'Already have an account? ',
            style: TextStyle(color: AppColors.textSecondary),
            children: [
              TextSpan(text: 'Log in', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      );
}
