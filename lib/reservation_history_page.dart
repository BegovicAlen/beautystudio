import 'dart:async';
import 'package:flutter/material.dart';
import 'payments_page.dart';
import 'services/beauty_studio_api.dart';

String historyDate(DateTime x) =>
    '${x.day.toString().padLeft(2, "0")}.${x.month.toString().padLeft(2, "0")}.${x.year}. ${x.hour.toString().padLeft(2, "0")}:${x.minute.toString().padLeft(2, "0")}';

class ClientHistoryPage extends StatefulWidget {
  const ClientHistoryPage({
    super.key,
    required this.token,
    required this.clientId,
  });
  final String token, clientId;
  @override
  State<ClientHistoryPage> createState() => _ClientHistoryPageState();
}

class _ClientHistoryPageState extends State<ClientHistoryPage> {
  late Future<ClientReservationHistory> data;
  String search = '';
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

  Future<ClientReservationHistory> load() =>
      BeautyStudioApi.clientReservationHistory(
        widget.token,
        widget.clientId,
        search: search,
      );
  Future<void> reload() async {
    if (mounted) {
      setState(() {
        data = load();
      });
    }
    await data;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Historija klijenta')),
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
              labelText: 'Pretražite uslugu',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<ClientReservationHistory>(
            future: data,
            builder: (context, s) {
              if (!s.hasData) {
                return Center(
                  child: s.hasError
                      ? TextButton(
                          onPressed: reload,
                          child: Text(s.error.toString()),
                        )
                      : const CircularProgressIndicator(),
                );
              }
              final d = s.data!;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    d.clientName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(d.clientEmail),
                  const SizedBox(height: 16),
                  if (d.reservations.isEmpty)
                    const Text('Nema rezervacija prema odabranim kriterijima.'),
                  ...d.reservations.map(
                    (r) => Card(
                      child: ListTile(
                        title: Text(r.serviceName),
                        subtitle: Text(
                          '${historyDate(r.startAtUtc)}\n${r.statusDisplayName.isNotEmpty ? r.statusDisplayName : BeautyStudioApi.statusLabels[r.status] ?? r.status}',
                        ),
                        trailing: Text(paymentStatusLabel(r.paymentStatus)),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}

class ReservationAuditPage extends StatefulWidget {
  const ReservationAuditPage({
    super.key,
    required this.token,
    required this.reservationId,
  });
  final String token, reservationId;
  @override
  State<ReservationAuditPage> createState() => _ReservationAuditPageState();
}

class _ReservationAuditPageState extends State<ReservationAuditPage> {
  late Future<List<ReservationHistoryRecord>> data;
  String search = '';
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

  Future<List<ReservationHistoryRecord>> load() =>
      BeautyStudioApi.reservationHistory(
        widget.token,
        widget.reservationId,
        search: search,
      );
  Future<void> reload() async {
    if (mounted) {
      setState(() {
        data = load();
      });
    }
    await data;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Historija promjena termina')),
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
              labelText: 'Pretražite razlog promjene',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<ReservationHistoryRecord>>(
            future: data,
            builder: (context, s) {
              if (!s.hasData) {
                return Center(
                  child: s.hasError
                      ? TextButton(
                          onPressed: reload,
                          child: Text(s.error.toString()),
                        )
                      : const CircularProgressIndicator(),
                );
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (s.data!.isEmpty)
                    const Text('Nema promjena prema odabranim kriterijima.'),
                  ...s.data!.map(
                    (e) => Card(
                      child: ListTile(
                        title: Text(
                          '${e.fromStatus == null ? "Kreirano" : BeautyStudioApi.statusLabels[e.fromStatus] ?? e.fromStatus} → ${BeautyStudioApi.statusLabels[e.toStatus] ?? e.toStatus}',
                        ),
                        subtitle: Text(
                          '${e.reason}\n${e.changedByName} · ${historyDate(e.changedAtUtc)}',
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}
