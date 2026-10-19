import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'form_support.dart';
import 'services/beauty_studio_api.dart';

Future<void> showRecoveryCode(BuildContext context, String code) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Sačuvajte kod za oporavak'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ovaj jednokratni kod omogućava oporavak naloga ako zaboravite lozinku. Važi godinu dana. Sačuvajte ga na sigurnom mjestu.',
            ),
            const SizedBox(height: 16),
            SelectableText(
              code,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => Clipboard.setData(ClipboardData(text: code)),
              icon: const Icon(Icons.copy),
              label: const Text('Kopirajte kod'),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Sačuvao sam kod'),
        ),
      ],
    ),
  );
}

class AccountRecoveryPage extends StatefulWidget {
  const AccountRecoveryPage({super.key});
  @override
  State<AccountRecoveryPage> createState() => _AccountRecoveryPageState();
}

class _AccountRecoveryPageState extends State<AccountRecoveryPage> {
  final form = GlobalKey<FormState>();
  final identifier = TextEditingController(),
      code = TextEditingController(),
      password = TextEditingController(),
      confirm = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    identifier.dispose();
    code.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> reset() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final replacement = await BeautyStudioApi.resetPassword(
        identifier.text.trim(),
        code.text.trim(),
        password.text,
      );
      if (!mounted) return;
      await showRecoveryCode(context, replacement);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Lozinka je promijenjena. Prijavite se novom lozinkom.',
            ),
          ),
        );
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Oporavak lozinke')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Form(
            key: form,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Unesite kod za oporavak koji ste sačuvali prilikom registracije ili u profilu.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: identifier,
                  validator: (v) => Validators.requiredText(v),
                  decoration: const InputDecoration(
                    labelText: 'Korisničko ime ili email',
                  ),
                ),
                TextFormField(
                  controller: code,
                  validator: (v) =>
                      RegExp(
                        r'^[a-fA-F0-9 -]{48,64}$',
                      ).hasMatch(v?.trim() ?? '')
                      ? null
                      : 'Unesite sačuvani kod za oporavak (48 znakova).',
                  decoration: const InputDecoration(
                    labelText: 'Jednokratni kod za oporavak',
                  ),
                ),
                TextFormField(
                  controller: password,
                  obscureText: true,
                  validator: (v) => Validators.password(v),
                  decoration: const InputDecoration(labelText: 'Nova lozinka'),
                ),
                TextFormField(
                  controller: confirm,
                  obscureText: true,
                  validator: (v) =>
                      v == password.text ? null : 'Lozinke se ne podudaraju.',
                  decoration: const InputDecoration(
                    labelText: 'Potvrdite novu lozinku',
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: busy ? null : reset,
                  child: Text(busy ? 'Obrada...' : 'Promijenite lozinku'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
