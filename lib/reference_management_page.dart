import 'dart:async';
import 'package:flutter/material.dart';
import 'form_support.dart';
import 'services/beauty_studio_api.dart';

class ReferenceManagementPage extends StatefulWidget {
  const ReferenceManagementPage({super.key, required this.token});
  final String token;
  @override
  State<ReferenceManagementPage> createState() =>
      _ReferenceManagementPageState();
}

class _ReferenceManagementPageState extends State<ReferenceManagementPage> {
  String kind = 'cities', search = '';
  bool? active;
  Timer? debounce;
  late Future<List<ReferenceItem>> rows;
  @override
  void initState() {
    super.initState();
    rows = load();
  }

  @override
  void dispose() {
    debounce?.cancel();
    super.dispose();
  }

  Future<List<ReferenceItem>> load() => BeautyStudioApi.references(
    kind,
    token: widget.token,
    managed: true,
    search: search,
  );
  Future<void> reload() async {
    if (mounted) {
      setState(() {
        rows = load();
      });
    }
    await rows;
  }

  Future<void> edit([ReferenceItem? item]) async {
    final name = TextEditingController(text: item?.name);
    bool enabled = item?.isActive ?? true;
    String? code = item?.code ?? (kind == 'statuses' ? 'Pending' : null);
    const states = {
      'Pending': 'Na čekanju',
      'Confirmed': 'Potvrđeno',
      'Cancelled': 'Otkazano',
      'Completed': 'Završeno',
    };
    final saved = await showCompletedDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => FormDialog(
          title: item == null
              ? 'Dodajte referentni podatak'
              : 'Uredite referentni podatak',
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  validator: (v) => Validators.requiredText(v, max: 100),
                  decoration: const InputDecoration(labelText: 'Naziv'),
                ),
                if (kind == 'statuses')
                  DropdownButtonFormField<String>(
                    initialValue: code,
                    items: states.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: item == null
                        ? (v) => setDialog(() => code = v)
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Poslovno stanje',
                    ),
                  ),
                if (kind == 'statuses')
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'Novi naziv zadržava pravila odabranog poslovnog stanja.',
                    ),
                  ),
                SwitchListTile(
                  title: const Text('Aktivan zapis'),
                  value: enabled,
                  onChanged: (v) => setDialog(() => enabled = v),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved == true) {
      try {
        await BeautyStudioApi.saveReference(
          widget.token,
          kind,
          id: item?.id,
          name: name.text.trim(),
          isActive: enabled,
          code: code,
        );
        if (kind == 'statuses') await BeautyStudioApi.refreshStatusLabels();
        await reload();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Referentni podatak je sačuvan.')),
          );
        }
      } on ApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.message)));
        }
      }
    }
    name.dispose();
  }

  Future<void> notice(ReferenceItem type) async {
    final users = (await BeautyStudioApi.managedUsers(
      widget.token,
    )).where((u) => u.isActive).toList();
    if (!mounted) return;
    if (users.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nema aktivnih korisnika.')));
      return;
    }
    String? recipient;
    final title = TextEditingController(), message = TextEditingController();
    final saved = await showCompletedDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => FormDialog(
          title: 'Obavijest u aplikaciji',
          saveLabel: 'Pošaljite obavijest',
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Tip: ${type.name}'),
                  DropdownButtonFormField<String>(
                    initialValue: recipient,
                    validator: (v) => v == null ? 'Odaberite korisnika.' : null,
                    items: users
                        .map(
                          (u) => DropdownMenuItem(
                            value: u.id,
                            child: Text(
                              '${u.firstName} ${u.lastName} · ${u.email}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDialog(() => recipient = v),
                    decoration: const InputDecoration(labelText: 'Primalac'),
                  ),
                  TextFormField(
                    controller: title,
                    validator: (v) => Validators.requiredText(v, max: 200),
                    decoration: const InputDecoration(labelText: 'Naslov'),
                  ),
                  TextFormField(
                    controller: message,
                    maxLines: 5,
                    validator: (v) => Validators.requiredText(v, max: 2000),
                    decoration: const InputDecoration(
                      labelText: 'Tekst obavijesti',
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
        await BeautyStudioApi.sendNotice(
          widget.token,
          recipient!,
          type.id,
          title.text.trim(),
          message.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Obavijest je sačuvana za isporuku u aplikaciji.'),
            ),
          );
        }
      } on ApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.message)));
        }
      }
    }
    title.dispose();
    message.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Referentni podaci')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ...{
                'cities': 'Gradovi',
                'statuses': 'Statusi rezervacija',
                'notification-types': 'Tipovi obavijesti',
              }.entries.map(
                (e) => ChoiceChip(
                  label: Text(e.value),
                  selected: kind == e.key,
                  onSelected: (_) {
                    setState(() {
                      kind = e.key;
                      search = '';
                      rows = load();
                    });
                  },
                ),
              ),
              FilledButton.icon(
                onPressed: () => edit(),
                icon: const Icon(Icons.add),
                label: const Text('Dodajte'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            key: ValueKey(kind),
            onChanged: (v) {
              search = v;
              debounce?.cancel();
              debounce = Timer(const Duration(milliseconds: 300), reload);
            },
            decoration: const InputDecoration(
              labelText: 'Pretražite naziv',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(
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
        ),
        Expanded(
          child: FutureBuilder<List<ReferenceItem>>(
            future: rows,
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
              final items = s.data!
                  .where((x) => active == null || x.isActive == active)
                  .toList();
              if (items.isEmpty) {
                return const Center(
                  child: Text('Nema zapisa prema odabranim kriterijima.'),
                );
              }
              return SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Naziv')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Akcije')),
                    ],
                    rows: items
                        .map(
                          (x) => DataRow(
                            cells: [
                              DataCell(Text(x.name)),
                              DataCell(
                                Text(x.isActive ? 'Aktivan' : 'Neaktivan'),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Uredite ili deaktivirajte',
                                      onPressed: () => edit(x),
                                      icon: const Icon(Icons.edit),
                                    ),
                                    if (kind == 'notification-types')
                                      IconButton(
                                        tooltip: x.isActive
                                            ? 'Pošaljite obavijest ovog tipa'
                                            : 'Tip je deaktiviran',
                                        onPressed: x.isActive
                                            ? () => notice(x)
                                            : null,
                                        icon: const Icon(Icons.send),
                                      ),
                                  ],
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
