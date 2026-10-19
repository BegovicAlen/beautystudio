import 'package:beautystudio_aplikacija/form_support.dart';
import 'package:beautystudio_aplikacija/registration_page.dart';
import 'package:beautystudio_aplikacija/services/beauty_studio_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beautystudio_aplikacija/app.dart';

void main() {
  testWidgets(
    'reservation reason dialog disposes after its closing animation',
    (tester) async {
      String? reason;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  reason = await reservationReasonDialog(
                    context,
                    'Otkaži rezervaciju',
                    'Razlog',
                    'Potvrdite',
                  );
                },
                child: const Text('Otkaži'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Otkaži'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Promjena plana');
      await tester.tap(find.text('Potvrdite'));
      await tester.pumpAndSettle();
      expect(reason, 'Promjena plana');
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Otkaži'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nazad'));
      await tester.pumpAndSettle();
      expect(reason, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('guest can browse and open login and registration', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const BeautyStudioApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(StudioShell), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
    expect(find.text('Rezerviši'), findsOneWidget);
    await tester.tap(find.text('Prijava'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(LoginPage), findsOneWidget);
    await tester.tap(find.text('Nemate račun? Registrujte se'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(RegistrationPage), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  test('validates account and numeric fields', () {
    expect(Validators.requiredText('   '), isNotNull);
    expect(Validators.email('bad@example'), isNotNull);
    expect(Validators.email('beauty@example.com'), isNull);
    expect(Validators.phone('abc'), isNotNull);
    expect(Validators.phone('+387 61 123 456'), isNull);
    expect(Validators.password('short'), isNotNull);
    expect(Validators.password('password123'), isNull);
    expect(Validators.integer('1.5', 1, 100), isNotNull);
    expect(Validators.number('12,5', 0, 100), isNull);
  });
  test('preserves reservation labels and payment amounts', () {
    final item = ReservationRecord.fromJson({
      'id': 'test',
      'serviceName': 'Manikir',
      'startAtUtc': '2026-10-20T10:00:00Z',
      'endAtUtc': '2026-10-20T11:00:00Z',
      'paymentMethod': 'Card',
      'status': 'Confirmed',
      'statusDisplayName': 'Dolazak potvrđen',
      'paymentStatus': 'Paid',
      'isPaid': true,
      'totalAmount': 50,
      'paidAmount': 15,
      'remainingAmount': 35,
      'currency': 'bam',
    });
    expect(item.statusDisplayName, 'Dolazak potvrđen');
    expect(item.isPaid, isTrue);
    expect(item.remainingAmount, 35);
  });
  testWidgets('registration rejects empty fields', (tester) async {
    var signedIn = false;
    await tester.pumpWidget(
      MaterialApp(
        home: RegistrationPage(
          onSignedIn: (_) async {
            signedIn = true;
          },
        ),
      ),
    );
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(find.text('Ovo polje je obavezno.'), findsWidgets);
    expect(
      find.text('Unesite email u formatu ime@domena.com.'),
      findsOneWidget,
    );
    expect(signedIn, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('dialog validates input before closing', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<bool>(
                  context: context,
                  builder: (_) => FormDialog(
                    title: 'Grad',
                    content: TextFormField(validator: Validators.requiredText),
                  ),
                );
              },
              child: const Text('Otvori'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Otvori'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sačuvajte'));
    await tester.pump();
    expect(result, isNull);
    expect(find.text('Ovo polje je obavezno.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Mostar');
    await tester.tap(find.text('Sačuvajte'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
