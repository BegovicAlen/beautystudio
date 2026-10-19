import 'dart:async';
import 'package:flutter/material.dart';
import 'form_support.dart';
import 'services/beauty_studio_api.dart';

class ServiceManagementPage extends StatefulWidget {
  const ServiceManagementPage({super.key, required this.token});
  final String token;
  @override
  State<ServiceManagementPage> createState() => _ServiceManagementPageState();
}

class _ServiceManagementPageState extends State<ServiceManagementPage> {
  late Future<_Catalog> data;
  String search = '';
  int? category;
  Timer? debounce;
  @override
  void initState() {
    super.initState();
    data = load();
  }

  @override
  void dispose() {
    debounce?.cancel();
    super.dispose();
  }

  Future<_Catalog> load() async {
    final result = await Future.wait<Object>([
      BeautyStudioApi.managedServices(
        widget.token,
        search: search,
        categoryId: category,
      ),
      BeautyStudioApi.managedCategories(widget.token),
    ]);
    return _Catalog(
      result[0] as List<ManagedBeautyService>,
      result[1] as List<ManagedServiceCategory>,
    );
  }

  Future<void> reload() async {
    if (mounted) {
      setState(() {
        data = load();
      });
    }
    await data;
  }

  Future<void> editCategory([ManagedServiceCategory? existing]) async {
    final name = TextEditingController(text: existing?.name);
    bool enabled = existing?.isActive ?? true;
    final save = await showCompletedDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => FormDialog(
          title: 'Kategorija',
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  validator: (v) => Validators.requiredText(v),
                  decoration: const InputDecoration(
                    labelText: 'Naziv kategorije',
                  ),
                ),
                SwitchListTile(
                  title: const Text('Aktivna kategorija'),
                  value: enabled,
                  onChanged: (v) => setDialog(() => enabled = v),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (save == true) {
      try {
        await BeautyStudioApi.saveCategory(
          widget.token,
          existing: existing,
          name: name.text.trim(),
          isActive: enabled,
        );
        await reload();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kategorija je sačuvana.')),
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

  Future<void> editService(
    _Catalog catalog, [
    ManagedBeautyService? existing,
  ]) async {
    final categories = catalog.categories.where((x) => x.isActive).toList();
    if (categories.isEmpty) {
      await editCategory();
      return;
    }
    final name = TextEditingController(text: existing?.name),
        description = TextEditingController(text: existing?.description),
        price = TextEditingController(text: existing?.price.toString()),
        duration = TextEditingController(
          text: existing?.durationMinutes.toString(),
        );
    var chosen = categories.any((x) => x.id == existing?.categoryId)
        ? existing!.categoryId
        : categories.first.id;
    bool enabled = existing?.isActive ?? true;
    final save = await showCompletedDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => FormDialog(
          title: existing == null ? 'Dodajte uslugu' : 'Uredite uslugu',
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    validator: (v) => Validators.requiredText(v),
                    decoration: const InputDecoration(labelText: 'Naziv'),
                  ),
                  TextFormField(
                    controller: description,
                    maxLines: 4,
                    validator: (v) => Validators.requiredText(v, max: 2000),
                    decoration: const InputDecoration(labelText: 'Opis'),
                  ),
                  TextFormField(
                    controller: price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) => Validators.number(v, .01, 10000),
                    decoration: const InputDecoration(labelText: 'Cijena u KM'),
                  ),
                  TextFormField(
                    controller: duration,
                    keyboardType: TextInputType.number,
                    validator: (v) => Validators.integer(v, 5, 660),
                    decoration: const InputDecoration(
                      labelText: 'Trajanje u minutama',
                    ),
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: chosen,
                    items: categories
                        .map(
                          (x) => DropdownMenuItem(
                            value: x.id,
                            child: Text(x.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDialog(() => chosen = v!),
                    decoration: const InputDecoration(labelText: 'Kategorija'),
                  ),
                  SwitchListTile(
                    title: const Text('Aktivna usluga'),
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
    if (save == true) {
      try {
        await BeautyStudioApi.saveService(
          widget.token,
          existing: existing,
          name: name.text.trim(),
          description: description.text.trim(),
          price: num.parse(price.text.replaceAll(',', '.')),
          durationMinutes: int.parse(duration.text),
          categoryId: chosen,
          isActive: enabled,
        );
        await reload();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Usluga je sačuvana.')));
        }
      } on ApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.message)));
        }
      }
    }
    for (final c in [name, description, price, duration]) {
      c.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Katalog usluga'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Usluge'),
            Tab(text: 'Kategorije'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
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
          Expanded(
            child: FutureBuilder<_Catalog>(
              future: data,
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
                final d = s.data!;
                final categories = d.categories
                    .where(
                      (x) =>
                          x.name.toLowerCase().contains(search.toLowerCase()),
                    )
                    .toList();
                return TabBarView(
                  children: [
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  initialValue: category,
                                  items: [
                                    const DropdownMenuItem<int>(
                                      value: null,
                                      child: Text('Sve kategorije'),
                                    ),
                                    ...d.categories.map(
                                      (x) => DropdownMenuItem(
                                        value: x.id,
                                        child: Text(x.name),
                                      ),
                                    ),
                                  ],
                                  onChanged: (v) {
                                    category = v;
                                    reload();
                                  },
                                  decoration: const InputDecoration(
                                    labelText: 'Kategorija',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              FilledButton.icon(
                                onPressed: () => editService(d),
                                icon: const Icon(Icons.add),
                                label: const Text('Dodajte uslugu'),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Naziv')),
                                  DataColumn(label: Text('Kategorija')),
                                  DataColumn(label: Text('Trajanje')),
                                  DataColumn(label: Text('Cijena')),
                                  DataColumn(label: Text('Status')),
                                  DataColumn(label: Text('Uređivanje')),
                                ],
                                rows: d.services
                                    .map(
                                      (x) => DataRow(
                                        cells: [
                                          DataCell(Text(x.name)),
                                          DataCell(Text(x.categoryName)),
                                          DataCell(
                                            Text('${x.durationMinutes} min'),
                                          ),
                                          DataCell(Text('${x.price} KM')),
                                          DataCell(
                                            Text(
                                              x.isActive
                                                  ? 'Aktivna'
                                                  : 'Neaktivna',
                                            ),
                                          ),
                                          DataCell(
                                            IconButton(
                                              tooltip:
                                                  'Uredite ili deaktivirajte',
                                              onPressed: () =>
                                                  editService(d, x),
                                              icon: const Icon(Icons.edit),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: FilledButton.icon(
                              onPressed: () => editCategory(),
                              icon: const Icon(Icons.add),
                              label: const Text('Dodajte kategoriju'),
                            ),
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Naziv')),
                                DataColumn(label: Text('Usluge')),
                                DataColumn(label: Text('Status')),
                                DataColumn(label: Text('Uređivanje')),
                              ],
                              rows: categories
                                  .map(
                                    (x) => DataRow(
                                      cells: [
                                        DataCell(Text(x.name)),
                                        DataCell(Text('${x.serviceCount}')),
                                        DataCell(
                                          Text(
                                            x.isActive
                                                ? 'Aktivna'
                                                : 'Neaktivna',
                                          ),
                                        ),
                                        DataCell(
                                          IconButton(
                                            tooltip:
                                                'Uredite ili deaktivirajte',
                                            onPressed: () => editCategory(x),
                                            icon: const Icon(Icons.edit),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _Catalog {
  const _Catalog(this.services, this.categories);
  final List<ManagedBeautyService> services;
  final List<ManagedServiceCategory> categories;
}
