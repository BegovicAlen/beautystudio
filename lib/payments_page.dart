import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'services/beauty_studio_api.dart';

String paymentStatusLabel(String value) => switch (value) {
  'Paid' => 'Plaćeno',
  'Pending' => 'Na čekanju',
  'Refunded' => 'Vraćeno',
  'RefundPending' => 'Povrat u toku',
  'PartiallyRefunded' => 'Djelimično vraćeno',
  'Failed' => 'Neuspjelo',
  'Expired' => 'Isteklo',
  _ => 'Nije plaćeno',
};
Future<void> savePdf(
  BuildContext context,
  List<int> bytes,
  String name, {
  bool print = false,
}) async {
  if (print) {
    await Printing.layoutPdf(onLayout: (_) => Uint8List.fromList(bytes));
    return;
  }
  final directory =
      await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
  final file = File(
    '${directory.path}${Platform.pathSeparator}$name-${DateTime.now().millisecondsSinceEpoch}.pdf',
  );
  await file.writeAsBytes(bytes, flush: true);
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('PDF je sačuvan: ${file.path}')));
  }
}

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key, required this.token});
  final String token;
  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  late Future<List<PaymentRecord>> rows;
  String search = '', status = 'Sve';
  bool busy = false;
  Timer? _refresh;
  @override
  void initState() {
    super.initState();
    rows = BeautyStudioApi.myPayments(widget.token);
    _refresh = Timer.periodic(const Duration(seconds: 30), (_) => reload());
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  Future<void> reload() async {
    if (mounted) {
      setState(() {
        rows = BeautyStudioApi.myPayments(widget.token);
      });
    }
    await rows;
  }

  Future<void> receipt(PaymentRecord p, bool print) async {
    setState(() => busy = true);
    try {
      final data = await BeautyStudioApi.paymentReceipt(
        widget.token,
        p.reservationId,
      );
      if (mounted) {
        await savePdf(context, data, 'potvrda-placanja', print: print);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String date(DateTime x) =>
      '${x.day.toString().padLeft(2, "0")}.${x.month.toString().padLeft(2, "0")}.${x.year}. ${x.hour.toString().padLeft(2, "0")}:${x.minute.toString().padLeft(2, "0")}';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Historija plaćanja')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (v) => setState(() => search = v),
            decoration: const InputDecoration(
              labelText: 'Pretražite uslugu',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Wrap(
          spacing: 6,
          children:
              [
                    'Sve',
                    'Paid',
                    'Pending',
                    'Refunded',
                    'RefundPending',
                    'Expired',
                    'Failed',
                  ]
                  .map(
                    (s) => ChoiceChip(
                      label: Text(s == 'Sve' ? s : paymentStatusLabel(s)),
                      selected: status == s,
                      onSelected: (_) => setState(() => status = s),
                    ),
                  )
                  .toList(),
        ),
        Expanded(
          child: FutureBuilder<List<PaymentRecord>>(
            future: rows,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: TextButton(
                    onPressed: reload,
                    child: const Text('Pokušajte ponovo'),
                  ),
                );
              }
              final items = snapshot.data!
                  .where(
                    (p) =>
                        (status == 'Sve' || p.status == status) &&
                        p.serviceName.toLowerCase().contains(
                          search.toLowerCase(),
                        ),
                  )
                  .toList();
              return RefreshIndicator(
                onRefresh: reload,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Nema plaćanja prema odabranim kriterijima.',
                        ),
                      ),
                    ...items.map(
                      (p) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.serviceName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              Text(
                                '${p.amount.toStringAsFixed(2)} ${p.currency.toUpperCase()} · ${p.provider == "OnSite" ? "Na mjestu" : "Stripe"}',
                              ),
                              Chip(label: Text(paymentStatusLabel(p.status))),
                              Text(
                                'Datum: ${date(p.paidAtUtc ?? p.createdAtUtc)}',
                              ),
                              if (p.refundedAmount > 0)
                                Text(
                                  'Povrat: ${p.refundedAmount.toStringAsFixed(2)} ${p.currency.toUpperCase()} · ${p.refundedAtUtc == null ? "" : date(p.refundedAtUtc!)}',
                                ),
                              if (p.paidAtUtc != null)
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    TextButton.icon(
                                      onPressed: busy
                                          ? null
                                          : () => receipt(p, false),
                                      icon: const Icon(Icons.download),
                                      label: const Text('Preuzmite potvrdu'),
                                    ),
                                    TextButton.icon(
                                      onPressed: busy
                                          ? null
                                          : () => receipt(p, true),
                                      icon: const Icon(Icons.print),
                                      label: const Text('Štampajte'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}
