import 'dart:io';
import 'dart:async';
import 'payments_page.dart';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'services/beauty_studio_api.dart';

const _pink = Color(0xffe91e63);

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key, required this.token});
  final String token;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late DateTime _from;
  late DateTime _to;
  String? _busyReport;
  String _search = '';
  String? _status;
  Timer? _searchTimer;
  late Future<List<PaymentRecord>> _payments;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = DateTime(now.year, now.month, now.day);
    _payments = _loadPayments();
  }

  Future<List<PaymentRecord>> _loadPayments() => BeautyStudioApi.paymentRecords(
    widget.token,
    search: _search,
    status: _status,
    from: _from,
    to: _to,
  );
  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }

  Future<void> _selectDate({required bool isFrom}) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _from = selected;
        if (_to.isBefore(selected)) _to = selected;
      } else {
        _to = selected;
      }
      _payments = _loadPayments();
    });
  }

  Future<void> _download(String report, {bool print = false}) async {
    setState(() => _busyReport = report);
    try {
      final bytes = report == 'reservations'
          ? await BeautyStudioApi.reservationReport(widget.token, _from, _to)
          : report == 'popular'
          ? await BeautyStudioApi.popularServicesReport(
              widget.token,
              _from,
              _to,
            )
          : await BeautyStudioApi.paymentReport(widget.token, _from, _to);
      if (print) {
        if (mounted) {
          await savePdf(context, bytes, 'beautystudio-$report', print: true);
        }
        return;
      }
      final downloads = await getDownloadsDirectory();
      final directory = downloads ?? await getApplicationDocumentsDirectory();
      final prefix = report == 'reservations'
          ? 'beautystudio-rezervacije'
          : report == 'popular'
          ? 'beautystudio-najtrazenije-usluge'
          : 'beautystudio-placanja';
      final file = File(
        '${directory.path}${Platform.pathSeparator}$prefix-${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(bytes, flush: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF je sačuvan u: ${file.path}')),
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _busyReport = null);
    }
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}.';

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
    children: [
      const Text(
        'PDF izvještaji',
        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 4),
      const Text(
        'Odaberite period, generišite izvještaj i preuzmite PDF datoteku.',
        style: TextStyle(color: Color(0xff777777)),
      ),
      const SizedBox(height: 22),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _selectDate(isFrom: true),
                icon: const Icon(Icons.date_range_outlined),
                label: Text('Od: ${_date(_from)}'),
              ),
              OutlinedButton.icon(
                onPressed: () => _selectDate(isFrom: false),
                icon: const Icon(Icons.date_range_outlined),
                label: Text('Do: ${_date(_to)}'),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      _ReportCard(
        icon: Icons.calendar_month_outlined,
        title: 'Izvještaj rezervacija po periodu',
        description:
            'Klijent, usluga, termin i status svih rezervacija u odabranom periodu.',
        busy: _busyReport == 'reservations',
        onDownload: () => _download('reservations'),
        onPrint: () => _download('reservations', print: true),
      ),
      const SizedBox(height: 12),
      _ReportCard(
        icon: Icons.auto_graph_outlined,
        title: 'Izvještaj najtraženijih usluga',
        description:
            'Broj rezervacija i broj završenih tretmana po usluzi u odabranom periodu.',
        busy: _busyReport == 'popular',
        onDownload: () => _download('popular'),
        onPrint: () => _download('popular', print: true),
      ),
      const SizedBox(height: 12),
      _ReportCard(
        icon: Icons.payments_outlined,
        title: 'Izvještaj plaćanja',
        description:
            'Stripe test evidencija plaćanja, iznosi, statusi i povezane rezervacije.',
        busy: _busyReport == 'payments',
        onDownload: () => _download('payments'),
        onPrint: () => _download('payments', print: true),
      ),
      const SizedBox(height: 28),
      TextField(
        onChanged: (v) {
          _search = v;
          _searchTimer?.cancel();
          _searchTimer = Timer(const Duration(milliseconds: 300), () {
            if (mounted) setState(() => _payments = _loadPayments());
          });
        },
        decoration: const InputDecoration(
          labelText: 'Pretražite plaćanja po klijentu ili usluzi',
          prefixIcon: Icon(Icons.search),
        ),
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        initialValue: _status,
        items: [
          const DropdownMenuItem<String>(
            value: null,
            child: Text('Svi statusi'),
          ),
          ...[
            'Paid',
            'Pending',
            'Expired',
            'Failed',
            'RefundPending',
            'Refunded',
          ].map(
            (x) =>
                DropdownMenuItem(value: x, child: Text(paymentStatusLabel(x))),
          ),
        ],
        onChanged: (v) => setState(() {
          _status = v;
          _payments = _loadPayments();
        }),
        decoration: const InputDecoration(labelText: 'Status plaćanja'),
      ),
      const SizedBox(height: 16),
      const Text(
        'Evidencija plaćanja',
        style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      FutureBuilder<List<PaymentRecord>>(
        future: _payments,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Text('Evidencija plaćanja trenutno nije dostupna.');
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Text('Još nema evidentiranih plaćanja.');
          }
          final paid = items
              .where((x) => x.status == 'Paid')
              .fold<num>(0, (sum, x) => sum + x.amount);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: _pink,
                  ),
                  title: Text(
                    'Ukupno potvrđeno: ${paid.toStringAsFixed(2)} BAM',
                  ),
                  subtitle: Text(
                    '${items.where((x) => x.status == 'Paid').length} plaćenih od ${items.length} evidentiranih zapisa',
                  ),
                ),
              ),
              ...items.map(
                (item) => Card(
                  child: ListTile(
                    leading: Icon(
                      item.status == 'Paid'
                          ? Icons.check_circle_outline
                          : Icons.pending_outlined,
                      color: item.status == 'Paid' ? Colors.green : _pink,
                    ),
                    title: Text(
                      '${item.clientName} · ${item.amount.toStringAsFixed(2)} ${item.currency.toUpperCase()}',
                    ),
                    subtitle: Text(
                      '${item.serviceName}\nTermin: ${_date(item.appointmentStartAtUtc)} · Status: ${item.status}',
                    ),
                    trailing: item.paidAtUtc == null
                        ? null
                        : Text(
                            'Plaćeno\n${_date(item.paidAtUtc!)}',
                            textAlign: TextAlign.right,
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ],
  );
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.busy,
    required this.onDownload,
    this.onPrint,
  });
  final IconData icon;
  final String title;
  final String description;
  final bool busy;
  final VoidCallback onDownload;
  final VoidCallback? onPrint;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0x1ae91e63),
                child: Icon(icon, color: _pink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(description),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            children: [
              if (onPrint != null)
                OutlinedButton.icon(
                  onPressed: busy ? null : onPrint,
                  icon: const Icon(Icons.print),
                  label: const Text('Štampajte'),
                ),
              FilledButton.icon(
                onPressed: busy ? null : onDownload,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download),
                label: Text(busy ? 'Generisanje...' : 'Preuzmite PDF'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
