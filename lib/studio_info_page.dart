import 'package:flutter/material.dart';
import 'form_support.dart';
import 'services/beauty_studio_api.dart';

class StudioInfoPage extends StatefulWidget {
  const StudioInfoPage({super.key, required this.token});
  final String token;
  @override
  State<StudioInfoPage> createState() => _StudioInfoPageState();
}

class _StudioInfoPageState extends State<StudioInfoPage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      email = TextEditingController(),
      phone = TextEditingController(),
      message = TextEditingController();
  late Future<AboutContent> about;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    about = BeautyStudioApi.about();
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    message.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await BeautyStudioApi.sendContactMessage(
        token: widget.token,
        fullName: name.text.trim(),
        email: email.text.trim(),
        phone: phone.text.trim(),
        message: message.text.trim(),
      );
      if (mounted) {
        name.clear();
        email.clear();
        phone.clear();
        message.clear();
        form.currentState!.reset();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Poruka je zaprimljena.')));
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('O nama i kontakt')),
    body: FutureBuilder<AboutContent>(
      future: about,
      builder: (context, s) {
        if (s.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(() {
                about = BeautyStudioApi.about();
              }),
              child: const Text('Pokušajte ponovo'),
            ),
          );
        }
        final p = s.data!;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (p.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  BeautyStudioApi.contentImageUrl(p.imageUrl!),
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, error, stack) => const SizedBox.shrink(),
                ),
              ),
            const SizedBox(height: 18),
            Text(
              p.title,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(p.content),
            const SizedBox(height: 20),
            Wrap(
              spacing: 18,
              runSpacing: 12,
              children: [
                Chip(label: Text('Od ${p.foundedYear}. godine')),
                Chip(label: Text('${p.clientCount} klijenata')),
                Chip(
                  label: Text(
                    'Prosječna ocjena ${p.averageRating.toStringAsFixed(1)} / 5',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.location_on),
              title: Text('${p.address}, ${p.cityName ?? ""}'),
            ),
            ListTile(leading: const Icon(Icons.phone), title: Text(p.phone)),
            ListTile(leading: const Icon(Icons.email), title: Text(p.email)),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: Text(
                'Radno vrijeme: ${p.openingHour.toString().padLeft(2, "0")}:00 – ${p.closingHour.toString().padLeft(2, "0")}:00',
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Kontaktirajte nas',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Form(
              key: form,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                children: [
                  TextFormField(
                    controller: name,
                    validator: (v) => Validators.requiredText(v),
                    decoration: const InputDecoration(
                      labelText: 'Ime i prezime',
                    ),
                  ),
                  TextFormField(
                    controller: email,
                    validator: Validators.email,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  TextFormField(
                    controller: phone,
                    validator: Validators.phone,
                    decoration: const InputDecoration(labelText: 'Telefon'),
                    keyboardType: TextInputType.phone,
                  ),
                  TextFormField(
                    controller: message,
                    validator: (v) => Validators.requiredText(v, max: 3000),
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Poruka'),
                  ),
                  if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: busy ? null : send,
                    child: Text(busy ? 'Slanje...' : 'Pošaljite poruku'),
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
