import 'package:flutter/material.dart';
import 'form_support.dart';
import 'services/beauty_studio_api.dart';

class InformationManagementPage extends StatefulWidget {
  const InformationManagementPage({super.key, required this.token});
  final String token;
  @override
  State<InformationManagementPage> createState() =>
      _InformationManagementPageState();
}

class _InformationManagementPageState extends State<InformationManagementPage> {
  late Future<AboutContent> about;
  late Future<List<FaqEntry>> faq;
  String search = '';
  bool? active;
  @override
  void initState() {
    super.initState();
    about = BeautyStudioApi.about();
    faq = BeautyStudioApi.managedFaq(widget.token);
  }

  Future<void> reload() async {
    setState(() {
      about = BeautyStudioApi.about();
      faq = BeautyStudioApi.managedFaq(widget.token);
    });
    await Future.wait<Object>([about, faq]);
  }

  Future<void> editAbout(AboutContent value) async {
    final cities = await BeautyStudioApi.references('cities');
    if (!mounted) return;
    final title = TextEditingController(text: value.title),
        content = TextEditingController(text: value.content),
        image = TextEditingController(text: value.imageUrl),
        address = TextEditingController(text: value.address),
        phone = TextEditingController(text: value.phone),
        email = TextEditingController(text: value.email),
        year = TextEditingController(text: value.foundedYear.toString()),
        opening = TextEditingController(text: value.openingHour.toString()),
        closing = TextEditingController(text: value.closingHour.toString()),
        deposit = TextEditingController(text: value.depositPercent.toString());
    int? city = value.cityId;
    final saved = await showCompletedDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => FormDialog(
          title: 'Informacije i postavke salona',
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: title,
                    validator: (v) => Validators.requiredText(v, max: 200),
                    decoration: const InputDecoration(labelText: 'Naslov'),
                  ),
                  TextFormField(
                    controller: content,
                    maxLines: 5,
                    validator: (v) => Validators.requiredText(v, max: 5000),
                    decoration: const InputDecoration(labelText: 'Naša priča'),
                  ),
                  TextFormField(
                    controller: image,
                    decoration: const InputDecoration(
                      labelText: 'URL fotografije tima',
                    ),
                  ),
                  TextFormField(
                    controller: address,
                    validator: (v) => Validators.requiredText(v, max: 200),
                    decoration: const InputDecoration(
                      labelText: 'Ulica i broj',
                    ),
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: city,
                    validator: (v) => v == null ? 'Odaberite grad.' : null,
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
                  TextFormField(
                    controller: phone,
                    validator: Validators.phone,
                    decoration: const InputDecoration(labelText: 'Telefon'),
                  ),
                  TextFormField(
                    controller: email,
                    validator: Validators.email,
                    decoration: const InputDecoration(
                      labelText: 'Kontakt email',
                    ),
                  ),
                  TextFormField(
                    controller: year,
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        Validators.number(v, 1900, DateTime.now().year),
                    decoration: const InputDecoration(
                      labelText: 'Godina osnivanja',
                    ),
                  ),
                  TextFormField(
                    controller: opening,
                    keyboardType: TextInputType.number,
                    validator: (v) => Validators.number(v, 0, 22),
                    decoration: const InputDecoration(
                      labelText: 'Otvaranje (sat, 0–22)',
                    ),
                  ),
                  TextFormField(
                    controller: closing,
                    keyboardType: TextInputType.number,
                    validator: (v) => Validators.number(
                      v,
                      (int.tryParse(opening.text) ?? 0) + 1,
                      23,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Zatvaranje (sat)',
                    ),
                  ),
                  TextFormField(
                    controller: deposit,
                    keyboardType: TextInputType.number,
                    validator: (v) => Validators.number(v, 1, 100),
                    decoration: const InputDecoration(
                      labelText: 'Kartična naplata u % (100 = puni iznos)',
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
        final updated = await BeautyStudioApi.saveAbout(
          widget.token,
          AboutContent(
            title: title.text.trim(),
            content: content.text.trim(),
            imageUrl: image.text.trim().isEmpty ? null : image.text.trim(),
            address: address.text.trim(),
            phone: phone.text.trim(),
            email: email.text.trim(),
            foundedYear: int.parse(year.text),
            openingHour: int.parse(opening.text),
            closingHour: int.parse(closing.text),
            depositPercent: int.parse(deposit.text),
            cityId: city,
          ),
        );
        if (mounted) {
          setState(() {
            about = Future.value(updated);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Postavke salona su sačuvane.')),
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
    for (final c in [
      title,
      content,
      image,
      address,
      phone,
      email,
      year,
      opening,
      closing,
      deposit,
    ]) {
      c.dispose();
    }
  }

  Future<void> editFaq([FaqEntry? item]) async {
    final question = TextEditingController(text: item?.question),
        answer = TextEditingController(text: item?.answer),
        order = TextEditingController(text: (item?.sortOrder ?? 0).toString());
    bool enabled = item?.isActive ?? true;
    final saved = await showCompletedDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => FormDialog(
          title: item == null ? 'Dodajte FAQ' : 'Uredite FAQ',
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: question,
                    validator: (v) => Validators.requiredText(v, max: 300),
                    decoration: const InputDecoration(labelText: 'Pitanje'),
                  ),
                  TextFormField(
                    controller: answer,
                    maxLines: 5,
                    validator: (v) => Validators.requiredText(v, max: 3000),
                    decoration: const InputDecoration(labelText: 'Odgovor'),
                  ),
                  TextFormField(
                    controller: order,
                    keyboardType: TextInputType.number,
                    validator: (v) => Validators.number(v, 0, 10000),
                    decoration: const InputDecoration(labelText: 'Redoslijed'),
                  ),
                  SwitchListTile(
                    title: const Text('Vidljivo korisnicima'),
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
        await BeautyStudioApi.saveFaq(
          widget.token,
          existing: item,
          question: question.text.trim(),
          answer: answer.text.trim(),
          isActive: enabled,
          sortOrder: int.parse(order.text),
        );
        await reload();
      } on ApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.message)));
        }
      }
    }
    question.dispose();
    answer.dispose();
    order.dispose();
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('FAQ i informacije salona'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Salon'),
            Tab(text: 'FAQ'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          FutureBuilder<AboutContent>(
            future: about,
            builder: (context, s) {
              if (!s.hasData) {
                return Center(
                  child: s.hasError
                      ? TextButton(
                          onPressed: reload,
                          child: const Text('Pokušajte ponovo'),
                        )
                      : const CircularProgressIndicator(),
                );
              }
              final p = s.data!;
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    p.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(p.content),
                  const SizedBox(height: 16),
                  Text(
                    '${p.address}, ${p.cityName ?? ""}\n${p.phone}\n${p.email}\nRadno vrijeme: ${p.openingHour}:00–${p.closingHour}:00\nKartična naplata: ${p.depositPercent}%',
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => editAbout(p),
                    icon: const Icon(Icons.edit),
                    label: const Text('Uredite informacije i postavke'),
                  ),
                ],
              );
            },
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => search = v),
                        decoration: const InputDecoration(
                          labelText: 'Pretražite pitanja',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () => editFaq(),
                      icon: const Icon(Icons.add),
                      label: const Text('Dodajte'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<FaqEntry>>(
                  future: faq,
                  builder: (context, s) {
                    if (!s.hasData) {
                      return Center(
                        child: s.hasError
                            ? TextButton(
                                onPressed: reload,
                                child: const Text('Pokušajte ponovo'),
                              )
                            : const CircularProgressIndicator(),
                      );
                    }
                    final items = s.data!
                        .where(
                          (x) => x.question.toLowerCase().contains(
                            search.toLowerCase(),
                          ),
                        )
                        .toList();
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: items
                          .map(
                            (x) => Card(
                              child: ListTile(
                                title: Text(x.question),
                                subtitle: Text(
                                  '${x.isActive ? "Vidljivo" : "Skriveno"} · Redoslijed ${x.sortOrder}',
                                ),
                                trailing: IconButton(
                                  tooltip: 'Uredite ili deaktivirajte',
                                  onPressed: () => editFaq(x),
                                  icon: const Icon(Icons.edit),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
