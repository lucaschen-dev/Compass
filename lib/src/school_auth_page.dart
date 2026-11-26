import 'package:material_ui/material_ui.dart';

import 'app_ui.dart';
import 'local_accounts.dart';
import 'school_demo.dart';

enum _AuthStep { login, first, forgot, password, name, verify }

class SchoolAuthPage extends StatefulWidget {
  const SchoolAuthPage({
    super.key,
    required this.school,
    required this.accounts,
    this.pendingAccountActions,
  });
  final DemoSchool school;
  final SchoolAccounts accounts;
  final Widget? pendingAccountActions;
  @override
  State<SchoolAuthPage> createState() => _SchoolAuthPageState();
}

class _SchoolAuthPageState extends State<SchoolAuthPage> {
  final _email = TextEditingController(),
      _password = TextEditingController(),
      _confirm = TextEditingController(),
      _name = TextEditingController();
  final _emailFocus = FocusNode();
  final _nameFocus = FocusNode();
  _AuthStep _step = _AuthStep.login;
  int _grade = 11;
  bool _busy = false, _hidden = true, _profilePending = false;
  String? _error;
  String? _notice;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _name.dispose();
    _emailFocus.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _go(_AuthStep step) {
    FocusScope.of(context).unfocus();
    setState(() {
      _step = step;
      _error = null;
      _notice = null;
    });
  }

  Future<void> _act(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await action();
    } on EmailVerificationRequired catch (error) {
      if (mounted) {
        _profilePending = true;
        _password.clear();
        _confirm.clear();
        _go(_AuthStep.verify);
        setState(() => _notice = error.message);
      }
    } on AccountException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not reach Compass. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _enterOrCompleteProfile(LocalAccount? account) {
    if (!mounted) return;
    if (account != null) {
      Navigator.pop(context, account);
      return;
    }
    _name.text = widget.accounts.displayName?.trim() ?? '';
    _password.clear();
    _profilePending = true;
    _go(_AuthStep.name);
  }

  Future<void> _login() => _act(() async {
    _name.clear();
    _enterOrCompleteProfile(
      await widget.accounts.login(_email.text, _password.text),
    );
  });

  Future<void> _google() => _act(() async {
    _name.clear();
    _enterOrCompleteProfile(await widget.accounts.signInWithGoogle());
  });

  Future<void> _create() => _act(() async {
    final account = await widget.accounts.create(
      username: _email.text,
      password: _password.text,
      name: _name.text,
      grade: _grade,
    );
    if (mounted) Navigator.pop(context, account);
  });

  Future<void> _finishProfile() => _act(() async {
    final account = await widget.accounts.finishVerifiedProfile(
      name: _name.text,
      grade: _grade,
    );
    if (mounted) Navigator.pop(context, account);
  });

  Future<void> _confirmVerification() {
    if (_name.text.trim().isNotEmpty) return _finishProfile();
    return _act(() async {
      await widget.accounts.verifyEmail();
      if (mounted) _enterOrCompleteProfile(null);
    });
  }

  Future<void> _resetPassword() => _act(() async {
    await widget.accounts.resetPassword(_email.text);
    if (mounted) {
      setState(
        () => _notice = 'If an account exists for that address, check your inbox for a link to set your Compass password.',
      );
    }
  });

  Future<void> _resendVerification() => _act(() async {
    await widget.accounts.resendVerification();
    if (mounted) setState(() => _notice = 'Verification email sent.');
  });

  void _startPassword() {
    try {
      widget.accounts.emailFor(_email.text);
      _password.clear();
      _confirm.clear();
      _name.clear();
      _go(_AuthStep.password);
    } on AccountException catch (error) {
      setState(() => _error = error.message);
    }
  }

  Widget _field(String label, Widget child) => Column(
    key: ValueKey('school-auth-$label'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 10),
      Semantics(label: label, child: child),
    ],
  );
  Widget _schoolEmail() => _field(
    'School email',
    AnimatedBuilder(
      animation: _emailFocus,
      builder: (context, child) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _emailFocus.hasFocus
                ? Theme.of(context).colorScheme.onSurfaceVariant
                      .withValues(alpha: .35)
                : Colors.transparent,
          ),
        ),
        child: child,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _email,
              focusNode: _emailFocus,
              autocorrect: false,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'Username',
                semanticCounterText: 'School email username',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              onSubmitted: (_) {
                if (_step == _AuthStep.login) _login();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(
              '@${schoolEmailDomain(widget.school)}',
              key: const ValueKey('fixed-email-domain'),
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final title = switch (_step) {
      _AuthStep.login => 'Welcome back',
      _AuthStep.first => 'First login',
      _AuthStep.forgot => 'Forgot password',
      _AuthStep.password =>
        widget.accounts.isDemo ? 'Set a demo password' : 'Set your password',
      _AuthStep.name => 'Your real name',
      _AuthStep.verify => 'Verify your school email',
    };
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () async {
            if (_busy) return;
            if (_step == _AuthStep.login) {
              Navigator.pop(context);
            } else {
              if (_profilePending) {
                _profilePending = false;
                await widget.accounts.cancelEnrollment();
              }
              if (mounted) _go(_AuthStep.login);
            }
          },
        ),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, size) => SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: size.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(child: CompassWordmark(size: 26)),
                          const SizedBox(height: 12),
                          Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SchoolMark(school: widget.school, size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  shortSchoolName(widget.school),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 36),
                          Text(
                            title,
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const SizedBox(height: 30),
                          if (_step == _AuthStep.login ||
                              _step == _AuthStep.first ||
                              _step == _AuthStep.forgot)
                            _schoolEmail(),
                          if (_step == _AuthStep.login ||
                              _step == _AuthStep.password) ...[
                            if (_step == _AuthStep.login)
                              const SizedBox(height: 24),
                            _field(
                              'Password',
                              TextField(
                                controller: _password,
                                obscureText: _hidden,
                                autocorrect: false,
                                enableSuggestions: false,
                                decoration: InputDecoration(
                                  suffixIcon: IconButton(
                                    tooltip: _hidden
                                        ? 'Show password'
                                        : 'Hide password',
                                    onPressed: () =>
                                        setState(() => _hidden = !_hidden),
                                    icon: Icon(
                                      _hidden
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                onSubmitted: (_) {
                                  if (_step == _AuthStep.login) _login();
                                },
                              ),
                            ),
                            if (_step == _AuthStep.password) ...[
                              const SizedBox(height: 24),
                              _field(
                                'Confirm password',
                                TextField(
                                  controller: _confirm,
                                  obscureText: true,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                ),
                              ),
                            ],
                          ],
                          if (_step == _AuthStep.name) ...[
                            _field(
                              'Full name',
                              TextField(
                                controller: _name,
                                focusNode: _nameFocus,
                                autofocus: true,
                                keyboardType: TextInputType.name,
                                autofillHints: const [AutofillHints.name],
                                autocorrect: false,
                                textCapitalization: TextCapitalization.words,
                                maxLength: 60,
                                decoration: const InputDecoration(
                                  counterText: '',
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            _field(
                              'Grade',
                              DropdownButtonFormField<int>(
                                initialValue: _grade,
                                items: [
                                  for (var g = 9; g <= 12; g++)
                                    DropdownMenuItem(
                                      value: g,
                                      child: Text('Grade $g'),
                                    ),
                                ],
                                onChanged: (g) => setState(() => _grade = g!),
                              ),
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 20),
                            Text(
                              _error!,
                              key: const ValueKey('auth-error'),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                          if (_notice != null) ...[
                            const SizedBox(height: 20),
                            Text(_notice!),
                          ],
                          if (_step == _AuthStep.verify) ...[
                            const SizedBox(height: 16),
                            const Text(
                              'Open the verification link in your inbox, then come back here.',
                            ),
                          ],
                          const SizedBox(height: 36),
                          FilledButton(
                            onPressed: _busy
                                ? null
                                : switch (_step) {
                                    _AuthStep.login => _login,
                                    _AuthStep.first => _startPassword,
                                    _AuthStep.forgot => _resetPassword,
                                    _AuthStep.password => () {
                                      if (_password.text.length < 10 ||
                                          _password.text.length > 128) {
                                        setState(
                                          () =>
                                              _error = 'Use 10–128 characters.',
                                        );
                                        return;
                                      }
                                      if (_password.text != _confirm.text) {
                                        setState(
                                          () => _error =
                                              'The passwords do not match.',
                                        );
                                        return;
                                      }
                                      _profilePending = false;
                                      _go(_AuthStep.name);
                                    },
                                    _AuthStep.name =>
                                      _profilePending
                                          ? _finishProfile
                                          : _create,
                                    _AuthStep.verify => _confirmVerification,
                                  },
                            child: _busy
                                ? const SizedBox.square(
                                    dimension: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(switch (_step) {
                                    _AuthStep.login => 'Log in',
                                    _AuthStep.first =>
                                      widget.accounts.isDemo
                                          ? 'Set up a local demo account'
                                          : 'Continue',
                                    _AuthStep.forgot => 'Send reset email',
                                    _AuthStep.password => 'Continue',
                                    _AuthStep.name =>
                                      _profilePending
                                          ? 'Continue'
                                          : widget.accounts.isDemo
                                          ? 'Create demo account'
                                          : 'Create account',
                                    _AuthStep.verify => 'I verified my email',
                                  }),
                          ),
                          if (_step == _AuthStep.login &&
                              widget.accounts.supportsGoogle) ...[
                            const SizedBox(height: 16),
                            OutlinedButton(
                              onPressed: _busy ? null : _google,
                              child: const Text('Continue with Google'),
                            ),
                          ],
                          if (_step == _AuthStep.verify)
                            TextButton(
                              onPressed: _busy ? null : _resendVerification,
                              child: const Text('Resend verification email'),
                            ),
                          if (_profilePending &&
                              widget.pendingAccountActions != null)
                            widget.pendingAccountActions!,
                          const SizedBox(height: 40),
                          if (_step == _AuthStep.login) const Spacer(),
                          if (_step == _AuthStep.login)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _go(_AuthStep.forgot),
                                  child: const Text('Forgot password'),
                                ),
                                if (widget.accounts.canCreate)
                                  TextButton(
                                    onPressed: _busy
                                        ? null
                                        : () => _go(_AuthStep.first),
                                    child: const Text('First login'),
                                  ),
                              ],
                            ),
                          if (_step == _AuthStep.password &&
                              widget.accounts.isDemo)
                            Text(
                              'Use a password only for this demo.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
