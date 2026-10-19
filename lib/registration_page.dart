import 'package:flutter/material.dart';
import 'account_recovery_page.dart';
import 'form_support.dart';
import 'services/beauty_studio_api.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key, required this.onSignedIn});
  final Future<void> Function(AuthSession) onSignedIn;
  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final form = GlobalKey<FormState>();
  final first = TextEditingController(),
      last = TextEditingController(),
      username = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController(),
      confirm = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    for (final c in [first, last, username, email, password, confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> register() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final session = await BeautyStudioApi.register(
        firstName: first.text.trim(),
        lastName: last.text.trim(),
        username: username.text.trim(),
        email: email.text.trim(),
        password: password.text,
      );
      if (!mounted) return;
      if (session.recoveryCode != null) {
        await showRecoveryCode(context, session.recoveryCode!);
      }
      await widget.onSignedIn(session);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kreirajte račun')),
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
                  'Registracija',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: first,
                  enabled: !busy,
                  validator: (v) => Validators.requiredText(v, max: 100),
                  decoration: const InputDecoration(labelText: 'Ime'),
                ),
                TextFormField(
                  controller: last,
                  enabled: !busy,
                  validator: (v) => Validators.requiredText(v, max: 100),
                  decoration: const InputDecoration(labelText: 'Prezime'),
                ),
                TextFormField(
                  controller: username,
                  enabled: !busy,
                  validator: (v) =>
                      (v?.trim().length ?? 0) >= 3 &&
                          (v?.trim().length ?? 0) <= 50
                      ? null
                      : 'Korisničko ime mora imati 3–50 znakova.',
                  decoration: const InputDecoration(
                    labelText: 'Korisničko ime',
                  ),
                ),
                TextFormField(
                  controller: email,
                  enabled: !busy,
                  validator: Validators.email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                TextFormField(
                  controller: password,
                  enabled: !busy,
                  obscureText: true,
                  validator: (v) => Validators.password(v),
                  decoration: const InputDecoration(labelText: 'Lozinka'),
                ),
                TextFormField(
                  controller: confirm,
                  enabled: !busy,
                  obscureText: true,
                  validator: (v) =>
                      v == password.text ? null : 'Lozinke se ne podudaraju.',
                  decoration: const InputDecoration(
                    labelText: 'Potvrdite lozinku',
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
                  onPressed: busy ? null : register,
                  child: Text(busy ? 'Kreiranje naloga...' : 'Kreirajte račun'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
