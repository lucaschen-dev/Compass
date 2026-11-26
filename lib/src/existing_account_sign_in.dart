import 'package:material_ui/material_ui.dart';

import 'app_ui.dart';
import 'local_accounts.dart';

Future<bool> openExistingAccountSignIn(
  BuildContext context, {
  required Future<void> Function(String email, String password) onPassword,
  Future<void> Function()? onGoogle,
  Future<void> Function(String email)? onPasswordReset,
  Future<void> Function(String email, String password)? onCreate,
  Future<void> Function()? onVerify,
  Future<void> Function()? onResendVerification,
  Widget? pendingAccountActions,
}) async =>
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ExistingAccountSignIn(
          onPassword: onPassword,
          onGoogle: onGoogle,
          onPasswordReset: onPasswordReset,
          onCreate: onCreate,
          onVerify: onVerify,
          onResendVerification: onResendVerification,
          pendingAccountActions: pendingAccountActions,
        ),
      ),
    ) ??
    false;

class ExistingAccountSignIn extends StatefulWidget {
  const ExistingAccountSignIn({
    super.key,
    required this.onPassword,
    this.onGoogle,
    this.onPasswordReset,
    this.onCreate,
    this.onVerify,
    this.onResendVerification,
    this.pendingAccountActions,
  });

  final Future<void> Function(String email, String password) onPassword;
  final Future<void> Function()? onGoogle;
  final Future<void> Function(String email)? onPasswordReset;
  final Future<void> Function(String email, String password)? onCreate;
  final Future<void> Function()? onVerify;
  final Future<void> Function()? onResendVerification;
  final Widget? pendingAccountActions;

  @override
  State<ExistingAccountSignIn> createState() => _ExistingAccountSignInState();
}

enum _SignInMethod { password, google, reset, verify, resend }

class _ExistingAccountSignInState extends State<ExistingAccountSignIn> {
  static final _emailPattern = RegExp(r'^[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+$');
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hidePassword = true;
  bool _creating = false;
  String? _verificationMessage;
  _SignInMethod? _method;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn(
    _SignInMethod method,
    Future<void> Function() action, {
    bool complete = true,
  }) async {
    if (_method != null) return;
    FocusScope.of(context).unfocus();
    setState(() => _method = method);
    try {
      await action();
      if (mounted && complete) Navigator.of(context).pop(true);
    } on EmailVerificationRequired catch (error) {
      if (mounted && widget.onVerify != null) {
        _password.clear();
        setState(() => _verificationMessage = error.message);
      } else if (mounted) {
        showAppError(context, error.message);
      }
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
    final authenticate = _creating ? widget.onCreate! : widget.onPassword;
    await _signIn(
      _SignInMethod.password,
      () => authenticate(_email.text.trim(), _password.text),
    );
  }

  String? _emailError(String? value) =>
      _emailPattern.hasMatch((value ?? '').trim())
      ? null
      : 'Enter your full email address.';

  Future<void> _resetPassword() async {
    final error = _emailError(_email.text);
    if (error != null) {
      showAppError(context, error);
      return;
    }
    await _signIn(_SignInMethod.reset, () async {
      await widget.onPasswordReset!(_email.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'If an account exists for that address, check your inbox for a link to set your Compass password.',
            ),
          ),
        );
      }
    }, complete: false);
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
    appBar: AppBar(
      title: Text(_creating ? 'Create Compass account' : 'Sign in'),
    ),
    body: SafeArea(
      top: false,
      child: Form(
        key: _formKey,
        child: _verificationMessage != null
            ? _verification()
            : ContentColumn(
                maxWidth: 480,
                children: [
                  TextFormField(
                    controller: _email,
                    enabled: _method == null,
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                    ),
                    validator: _emailError,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _password,
                    enabled: _method == null,
                    textInputAction: TextInputAction.done,
                    autofillHints: _creating
                        ? const [AutofillHints.newPassword]
                        : const [AutofillHints.password],
                    obscureText: _hidePassword,
                    onFieldSubmitted: (_) => _withPassword(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _hidePassword = !_hidePassword),
                        tooltip: _hidePassword
                            ? 'Show password'
                            : 'Hide password',
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
                    child: _buttonLabel(
                      _SignInMethod.password,
                      _creating ? 'Create account' : 'Sign in',
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (widget.onGoogle case final onGoogle? when !_creating)
                    OutlinedButton(
                      onPressed: _method == null
                          ? () => _signIn(_SignInMethod.google, onGoogle)
                          : null,
                      child: _buttonLabel(
                        _SignInMethod.google,
                        'Continue with Google',
                      ),
                    ),
                  if (!_creating && widget.onPasswordReset != null)
                    TextButton(
                      onPressed: _method == null ? _resetPassword : null,
                      child: _buttonLabel(
                        _SignInMethod.reset,
                        'Set or reset Compass password',
                      ),
                    ),
                  if (widget.onCreate != null)
                    TextButton(
                      onPressed: _method == null
                          ? () => setState(() {
                              _creating = !_creating;
                              _password.clear();
                            })
                          : null,
                      child: Text(
                        _creating
                            ? 'I already have an account'
                            : 'Create Compass account',
                      ),
                    ),
                ],
              ),
      ),
    ),
  );

  Widget _verification() => ContentColumn(
    maxWidth: 480,
    children: [
      Text(
        _verificationMessage!,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 12),
      const Text(
        'Open the verification link in your inbox, then come back here.',
      ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: _method == null
            ? () => _signIn(_SignInMethod.verify, widget.onVerify!)
            : null,
        child: _buttonLabel(_SignInMethod.verify, 'I verified my email'),
      ),
      if (widget.onResendVerification case final resend?)
        TextButton(
          onPressed: _method == null
              ? () => _signIn(_SignInMethod.resend, () async {
                  await resend();
                  if (mounted) {
                    setState(
                      () => _verificationMessage = 'Verification email sent.',
                    );
                  }
                }, complete: false)
              : null,
          child: _buttonLabel(
            _SignInMethod.resend,
            'Resend verification email',
          ),
        ),
      ?widget.pendingAccountActions,
    ],
  );
}
