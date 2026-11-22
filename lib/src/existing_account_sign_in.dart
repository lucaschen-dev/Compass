import 'package:material_ui/material_ui.dart';

import 'app_ui.dart';
import 'local_accounts.dart';

Future<bool> openExistingAccountSignIn(
  BuildContext context, {
  required Future<void> Function(String email, String password) onPassword,
  required Future<void> Function() onGoogle,
}) async =>
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            ExistingAccountSignIn(onPassword: onPassword, onGoogle: onGoogle),
      ),
    ) ??
    false;

class ExistingAccountSignIn extends StatefulWidget {
  const ExistingAccountSignIn({
    super.key,
    required this.onPassword,
    required this.onGoogle,
  });

  final Future<void> Function(String email, String password) onPassword;
  final Future<void> Function() onGoogle;

  @override
  State<ExistingAccountSignIn> createState() => _ExistingAccountSignInState();
}

enum _SignInMethod { password, google }

class _ExistingAccountSignInState extends State<ExistingAccountSignIn> {
  static final _emailPattern = RegExp(r'^[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+$');
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hidePassword = true;
  _SignInMethod? _method;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn(
    _SignInMethod method,
    Future<void> Function() authenticate,
  ) async {
    if (_method != null) return;
    FocusScope.of(context).unfocus();
    setState(() => _method = method);
    try {
      await authenticate();
      if (mounted) Navigator.of(context).pop(true);
    } on AccountException catch (error) {
      if (mounted) showAppError(context, error.message);
    } catch (_) {
      if (mounted) {
        showAppError(context, 'Could not sign in. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _method = null);
    }
  }

  Future<void> _withPassword() async {
    if (_formKey.currentState?.validate() != true) return;
    await _signIn(
      _SignInMethod.password,
      () => widget.onPassword(_email.text.trim(), _password.text),
    );
  }

  Widget _buttonLabel(_SignInMethod method, String text) => _method == method
      ? const SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            semanticsLabel: 'Signing in',
          ),
        )
      : Text(text);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Sign in')),
    body: SafeArea(
      top: false,
      child: Form(
        key: _formKey,
        child: ContentColumn(
          maxWidth: 480,
          children: [
            TextFormField(
              controller: _email,
              enabled: _method == null,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Email address'),
              validator: (value) => _emailPattern.hasMatch((value ?? '').trim())
                  ? null
                  : 'Enter your full email address.',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              enabled: _method == null,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              obscureText: _hidePassword,
              onFieldSubmitted: (_) => _withPassword(),
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _hidePassword = !_hidePassword),
                  tooltip: _hidePassword ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _hidePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) =>
                  (value ?? '').isEmpty ? 'Enter your password.' : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _method == null ? _withPassword : null,
              child: _buttonLabel(_SignInMethod.password, 'Sign in'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _method == null
                  ? () => _signIn(_SignInMethod.google, widget.onGoogle)
                  : null,
              child: _buttonLabel(_SignInMethod.google, 'Continue with Google'),
            ),
          ],
        ),
      ),
    ),
  );
}
