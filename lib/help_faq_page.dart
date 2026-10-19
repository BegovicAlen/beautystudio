import 'package:flutter/material.dart';
import 'services/beauty_studio_api.dart';

class HelpFaqPage extends StatefulWidget {
  const HelpFaqPage({super.key, required this.token});
  final String token;
  @override
  State<HelpFaqPage> createState() => _HelpFaqPageState();
}

class _HelpFaqPageState extends State<HelpFaqPage> {
  late Future<List<FaqEntry>> _faq;
  @override
  void initState() {
    super.initState();
    _faq = BeautyStudioApi.faq();
  }

  void _reload() => setState(() {
    _faq = BeautyStudioApi.faq();
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Help i FAQ')),
    body: FutureBuilder<List<FaqEntry>>(
      future: _faq,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: FilledButton(
              onPressed: _reload,
              child: const Text('Pokušajte ponovo'),
            ),
          );
        }
        final items = snapshot.data!;
        if (items.isEmpty) {
          return const Center(
            child: Text('FAQ sadržaj će uskoro biti dostupan.'),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Česta pitanja',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            ...items.map(
              (item) => ExpansionTile(
                title: Text(
                  item.question,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(item.answer),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}
