import 'dart:async';
import 'package:flutter/material.dart';
import 'services/beauty_studio_api.dart';

class ContactMessagesPage extends StatefulWidget {
  const ContactMessagesPage({super.key, required this.token});
  final String token;
  @override
  State<ContactMessagesPage> createState() => _ContactMessagesPageState();
}

class _ContactMessagesPageState extends State<ContactMessagesPage> {
  late Future<List<ContactMessageRecord>> rows;
  String search = '';
  Timer? debounce;
  @override
  void initState() {
    super.initState();
    rows = BeautyStudioApi.contactMessages(widget.token);
  }

  @override
  void dispose() {
    debounce?.cancel();
    super.dispose();
  }

  Future<void> reload() async {
    if (mounted) {
      setState(
        () => rows = BeautyStudioApi.contactMessages(
          widget.token,
          search: search,
        ),
      );
    }
    await rows;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Poruke klijenata')),
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
              labelText: 'Pretražite ime, email ili tekst poruke',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<ContactMessageRecord>>(
            future: rows,
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
              if (s.data!.isEmpty) {
                return const Center(
                  child: Text('Nema poruka prema odabranim kriterijima.'),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: s.data!.length,
                separatorBuilder: (_, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final p = s.data![index];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.fullName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Text('${p.email} · ${p.phone}'),
                          const SizedBox(height: 8),
                          Text(p.message),
                          Text(
                            '${p.createdAtUtc.day}.${p.createdAtUtc.month}.${p.createdAtUtc.year}.',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}
