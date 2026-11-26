import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import 'app_ui.dart';
import 'firebase/account_deletion.dart';

class AccountDeletionButton extends StatelessWidget {
  const AccountDeletionButton({super.key, required this.onRequested});

  final Future<void> Function(String receipt) onRequested;

  Future<void> _confirm(BuildContext context) async {
    final deletion = FirebaseAccountDeletion();
    try {
      final needsVerification = await deletion.needsVerification();
      if (!context.mounted) return;
      final receipt = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _DeletionDialog(
          deletion: deletion,
          needsVerification: needsVerification,
        ),
      );
      if (receipt != null) await onRequested(receipt);
    } catch (_) {
      if (context.mounted) {
        showAppError(
          context,
          'Could not finish. Reopen account settings to check your deletion request.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 10),
    leading: Icon(
      Icons.delete_outline,
      color: Theme.of(context).colorScheme.error,
    ),
    title: const Text('Delete account'),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => _confirm(context),
  );
}

class _DeletionDialog extends StatefulWidget {
  const _DeletionDialog({
    required this.deletion,
    required this.needsVerification,
  });
  final FirebaseAccountDeletion deletion;
  final bool needsVerification;

  @override
  State<_DeletionDialog> createState() => _DeletionDialogState();
}

class _DeletionDialogState extends State<_DeletionDialog> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  bool get _google =>
      widget.needsVerification && widget.deletion.canVerifyWithGoogle;
  bool get _usePassword =>
      widget.needsVerification && widget.deletion.canVerifyWithPassword;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _request({required bool usePassword}) async {
    if (usePassword && _password.text.isEmpty) {
      setState(() => _error = 'Enter your Compass password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.needsVerification) {
        await widget.deletion.verify(
          password: usePassword ? _password.text : null,
        );
      }
      final receipt = await widget.deletion.request();
      if (mounted) Navigator.pop(context, receipt);
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(
          () => _error = switch (error.code) {
            'wrong-password' ||
            'invalid-credential' => 'That password did not match. Try again.',
            'user-mismatch' => 'Choose the Google account used for Compass.',
            _ => 'Could not verify your sign-in. Please try again.',
          },
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not submit your request. Try signing in again.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Delete your Compass account?'),
      scrollable: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Compass will permanently delete your profile, posts, photos, comments and direct conversations. A request can take up to 7 days. You can check the status on the welcome screen on this device.',
          ),
          if (_usePassword) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              enabled: !_busy,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(labelText: 'Compass password'),
            ),
          ],
          if (widget.needsVerification && !_usePassword && !_google) ...[
            const SizedBox(height: 12),
            const Text('Sign in again with your Compass password to continue.'),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_busy) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (_google)
          TextButton(
            onPressed: _busy ? null : () => _request(usePassword: false),
            child: const Text('Verify with Google and delete'),
          ),
        if (_usePassword || !widget.needsVerification)
          TextButton(
            onPressed: _busy ? null : () => _request(usePassword: _usePassword),
            child: const Text('Request deletion'),
          ),
      ],
    ),
  );
}

class DeletionStatus extends StatefulWidget {
  const DeletionStatus({
    super.key,
    required this.receipt,
    required this.onDismiss,
  });

  final String receipt;
  final VoidCallback onDismiss;

  @override
  State<DeletionStatus> createState() => _DeletionStatusState();
}

class _DeletionStatusState extends State<DeletionStatus> {
  late final _status = FirebaseAccountDeletion().track(widget.receipt);

  @override
  Widget build(BuildContext context) => StreamBuilder<String?>(
    stream: _status,
    builder: (context, snapshot) {
      final title = switch (snapshot.data) {
        'completed' => 'Your Compass account has been deleted.',
        'pending' => 'Account deletion requested.',
        _ => 'Checking account deletion status.',
      };
      return Column(
        children: [
          Text(title, textAlign: TextAlign.center),
          if (snapshot.data != 'pending' &&
              snapshot.connectionState == ConnectionState.active)
            TextButton(
              onPressed: widget.onDismiss,
              child: const Text('Dismiss'),
            ),
        ],
      );
    },
  );
}
