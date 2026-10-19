import 'dart:async';
import 'package:flutter/material.dart';
import 'form_support.dart';
import 'services/beauty_studio_api.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key, required this.token});
  final String token;
  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  late Future<List<ManagedUser>> users;
  String search = '';
  bool? active;
  Timer? debounce;
  @override
  void initState() {
    super.initState();
    users = load();
  }

  @override
  void dispose() {
    debounce?.cancel();
    super.dispose();
  }

  Future<List<ManagedUser>> load() =>
      BeautyStudioApi.managedUsers(widget.token, search: search);
  Future<void> reload() async {
    if (mounted) {
      setState(() {
        users = load();
      });
    }
    await users;
  }

  Future<void> editor([ManagedUser? existing]) async {
    final first = TextEditingController(text: existing?.firstName),
        last = TextEditingController(text: existing?.lastName),
        username = TextEditingController(text: existing?.username),
        email = TextEditingController(text: existing?.email),
        password = TextEditingController(),
        confirm = TextEditingController();
    var role = existing?.role ?? 'Client';
    var enabled = existing?.isActive ?? true;
    final saved = await showCompletedDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => FormDialog(
          title: existing == null ? 'Dodajte korisnika' : 'Uredite korisnika',
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
                    controller: username,
                    validator: (v) =>
                        RegExp(
                          r'^[\p{L}0-9_.-]{3,50}$',
                          unicode: true,
                        ).hasMatch(v?.trim() ?? '')
                        ? null
                        : 'Korisničko ime mora imati 3–50 slova ili cifara.',
                    decoration: const InputDecoration(
                      labelText: 'Korisničko ime',
                    ),
                  ),
                  TextFormField(
                    controller: email,
                    validator: Validators.email,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  TextFormField(
                    controller: password,
                    obscureText: true,
                    validator: (v) =>
                        Validators.password(v, optional: existing != null),
                    decoration: InputDecoration(
                      labelText: existing == null
                          ? 'Lozinka'
                          : 'Nova lozinka (opcionalno)',
                    ),
                  ),
                  TextFormField(
                    controller: confirm,
                    obscureText: true,
                    validator: (v) =>
                        v == password.text ? null : 'Lozinke se ne podudaraju.',
                    decoration: const InputDecoration(
                      labelText: 'Potvrdite lozinku',
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    items: ['Client', 'Owner', 'Admin']
                        .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                        .toList(),
                    onChanged: (v) => setDialog(() => role = v!),
                    decoration: const InputDecoration(labelText: 'Uloga'),
                  ),
                  SwitchListTile(
                    title: const Text('Aktivan nalog'),
                    value: enabled,
                    onChanged: (v) => setDialog(() => enabled = v),
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
        await BeautyStudioApi.saveUser(
          widget.token,
          existing: existing,
          firstName: first.text.trim(),
          lastName: last.text.trim(),
          username: username.text.trim(),
          email: email.text.trim(),
          password: password.text.isEmpty ? null : password.text,
          role: role,
          isActive: enabled,
        );
        await reload();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Korisnik je sačuvan.')));
        }
      } on ApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.message)));
        }
      }
    }
    for (final c in [first, last, username, email, password, confirm]) {
      c.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Upravljanje korisnicima')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) {
                    search = v;
                    debounce?.cancel();
                    debounce = Timer(const Duration(milliseconds: 300), reload);
                  },
                  decoration: const InputDecoration(
                    labelText: 'Pretražite ime, email ili korisničko ime',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => editor(),
                icon: const Icon(Icons.add),
                label: const Text('Dodajte'),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Svi'),
              selected: active == null,
              onSelected: (_) => setState(() => active = null),
            ),
            ChoiceChip(
              label: const Text('Aktivni'),
              selected: active == true,
              onSelected: (_) => setState(() => active = true),
            ),
            ChoiceChip(
              label: const Text('Neaktivni'),
              selected: active == false,
              onSelected: (_) => setState(() => active = false),
            ),
          ],
        ),
        Expanded(
          child: FutureBuilder<List<ManagedUser>>(
            future: users,
            builder: (context, s) {
              if (s.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (s.hasError) {
                return Center(
                  child: TextButton(
                    onPressed: reload,
                    child: Text(s.error.toString()),
                  ),
                );
              }
              final rows = s.data!
                  .where((x) => active == null || x.isActive == active)
                  .toList();
              if (rows.isEmpty) {
                return const Center(
                  child: Text('Nema korisnika prema odabranim kriterijima.'),
                );
              }
              return SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Ime i prezime')),
                      DataColumn(label: Text('Korisničko ime')),
                      DataColumn(label: Text('Email')),
                      DataColumn(label: Text('Uloga')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Uređivanje')),
                    ],
                    rows: rows
                        .map(
                          (x) => DataRow(
                            cells: [
                              DataCell(Text('${x.firstName} ${x.lastName}')),
                              DataCell(Text(x.username)),
                              DataCell(Text(x.email)),
                              DataCell(Text(x.role)),
                              DataCell(
                                Text(x.isActive ? 'Aktivan' : 'Neaktivan'),
                              ),
                              DataCell(
                                IconButton(
                                  tooltip: 'Uredite ili deaktivirajte',
                                  onPressed: () => editor(x),
                                  icon: const Icon(Icons.edit),
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}
