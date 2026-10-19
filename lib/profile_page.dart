import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'account_recovery_page.dart';
import 'form_support.dart';
import 'payments_page.dart';
import 'services/beauty_studio_api.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.token});
  final String token;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<UserProfile> profile;
  @override
  void initState() {
    super.initState();
    profile = BeautyStudioApi.profile(widget.token);
  }

  Future<void> reload() async {
    setState(() {
      profile = BeautyStudioApi.profile(widget.token);
    });
    await profile;
  }

  Future<void> edit(UserProfile p) async {
    final cities = await BeautyStudioApi.references('cities');
    if (!mounted) return;
    final first = TextEditingController(text: p.firstName),
        last = TextEditingController(text: p.lastName),
        email = TextEditingController(text: p.email),
        current = TextEditingController(),
        password = TextEditingController(),
        confirm = TextEditingController();
    int? city = p.cityId;
    bool notifications = p.notificationsEnabled;
    List<int>? bytes;
    String? filename;
    final saved = await showCompletedDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => FormDialog(
          title: 'Uredite profil',
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: first,
                    validator: (v) => Validators.requiredText(v, max: 100),
                    decoration: const InputDecoration(labelText: 'Ime'),
                  ),
                  TextFormField(
                    controller: last,
                    validator: (v) => Validators.requiredText(v, max: 100),
                    decoration: const InputDecoration(labelText: 'Prezime'),
                  ),
                  TextFormField(
                    controller: email,
                    validator: Validators.email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: city,
                    items: cities
                        .map(
                          (x) => DropdownMenuItem(
                            value: x.id,
                            child: Text(x.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDialog(() => city = v),
                    decoration: const InputDecoration(labelText: 'Grad'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await FilePicker.platform.pickFiles(
                        type: FileType.image,
                        withData: true,
                      );
                      if (picked?.files.single.bytes != null) {
                        setDialog(() {
                          bytes = picked!.files.single.bytes;
                          filename = picked.files.single.name;
                        });
                      }
                    },
                    icon: const Icon(Icons.image),
                    label: Text(filename ?? 'Odaberite profilnu sliku'),
                  ),
                  SwitchListTile(
                    title: const Text('Primajte obavijesti'),
                    value: notifications,
                    onChanged: (v) => setDialog(() => notifications = v),
                  ),
                  const Divider(),
                  const Text('Promjena lozinke je opcionalna.'),
                  TextFormField(
                    controller: current,
                    obscureText: true,
                    validator: (v) => password.text.isNotEmpty
                        ? Validators.requiredText(v)
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Trenutna lozinka',
                    ),
                  ),
                  TextFormField(
                    controller: password,
                    obscureText: true,
                    validator: (v) => Validators.password(v, optional: true),
                    decoration: const InputDecoration(
                      labelText: 'Nova lozinka',
                    ),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (saved == true) {
      try {
        final image = bytes == null
            ? p.profileImageUrl
            : await BeautyStudioApi.uploadProfileImage(
                widget.token,
                bytes: bytes!,
                fileName: filename!,
              );
        final updated = await BeautyStudioApi.updateProfile(
          widget.token,
          firstName: first.text.trim(),
          lastName: last.text.trim(),
          email: email.text.trim(),
          profileImageUrl: image,
          notificationsEnabled: notifications,
          currentPassword: current.text.isEmpty ? null : current.text,
          newPassword: password.text.isEmpty ? null : password.text,
          cityId: city,
        );
        if (mounted) {
          setState(() {
            profile = Future.value(updated);
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Profil je sačuvan.')));
        }
        if (password.text.isNotEmpty) sessionExpired.value++;
      } on ApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.message)));
        }
      }
    }
    first.dispose();
    last.dispose();
    email.dispose();
    current.dispose();
    password.dispose();
    confirm.dispose();
  }

  Future<void> recovery() async {
    final password = TextEditingController();
    final confirmed = await showCompletedDialog<bool>(
      context: context,
      builder: (context) => FormDialog(
        title: 'Novi kod za oporavak',
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Novi kod zamjenjuje prethodni. Sačuvajte ga za slučaj da zaboravite lozinku.',
              ),
              TextFormField(
                controller: password,
                obscureText: true,
                validator: (v) => Validators.requiredText(v),
                decoration: const InputDecoration(
                  labelText: 'Trenutna lozinka',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true) {
      try {
        final code = await BeautyStudioApi.recoveryCode(
          widget.token,
          password.text,
        );
        if (mounted) await showRecoveryCode(context, code);
      } on ApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.message)));
        }
      }
    }
    password.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Moj profil')),
    body: FutureBuilder<UserProfile>(
      future: profile,
      builder: (context, s) {
        if (s.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.hasError) {
          return Center(
            child: TextButton(
              onPressed: reload,
              child: const Text('Pokušajte ponovo'),
            ),
          );
        }
        final p = s.data!;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: CircleAvatar(
                radius: 48,
                backgroundImage: p.profileImageUrl == null
                    ? null
                    : NetworkImage(
                        BeautyStudioApi.contentImageUrl(p.profileImageUrl!),
                        headers: {'Authorization': 'Bearer ${widget.token}'},
                      ),
                child: p.profileImageUrl == null
                    ? const Icon(Icons.person, size: 48)
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${p.firstName} ${p.lastName}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),
            ListTile(title: const Text('Email'), subtitle: Text(p.email)),
            if (p.cityName != null)
              ListTile(title: const Text('Grad'), subtitle: Text(p.cityName!)),
            ListTile(
              title: const Text('Obavijesti'),
              subtitle: Text(
                p.notificationsEnabled ? 'Uključene' : 'Isključene',
              ),
            ),
            FilledButton.icon(
              onPressed: () => edit(p),
              icon: const Icon(Icons.edit),
              label: const Text('Uredite profil'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => PaymentsPage(token: widget.token),
                ),
              ),
              icon: const Icon(Icons.receipt_long),
              label: const Text('Historija plaćanja i potvrde'),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: recovery,
              icon: const Icon(Icons.key),
              label: const Text('Pripremite kod za oporavak naloga'),
            ),
          ],
        );
      },
    ),
  );
}
