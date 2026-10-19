import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:beautystudio_aplikacija/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Headers implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.statusCode, this.body);
  @override
  final int statusCode;
  final Object? body;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      Stream<List<int>>.value(
        body == null ? [] : utf8.encode(jsonEncode(body)),
      ).listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Store {
  final read = {'one': false, 'two': false};
  int singleWrites = 0, allWrites = 0;
  _Response respond(Uri uri) {
    if (uri.path.endsWith('/read-all')) {
      allWrites++;
      read.updateAll((key, value) => true);
      return _Response(204, null);
    }
    if (uri.path.endsWith('/read')) {
      singleWrites++;
      read[uri.path.split('/')[3]] = true;
      return _Response(204, null);
    }
    final items = read.entries
        .where(
          (entry) => uri.queryParameters['active'] != 'true' || !entry.value,
        )
        .map(
          (entry) => {
            'id': entry.key,
            'title': 'Obavijest ${entry.key}',
            'message': 'Puni tekst ${entry.key}',
            'isRead': entry.value,
            'createdAtUtc': '2026-10-11T10:00:00Z',
          },
        )
        .toList();
    return _Response(200, {
      'items': items,
      'total': items.length,
      'page': 1,
      'pageSize': 100,
    });
  }
}

class _Request implements HttpClientRequest {
  _Request(this.uri, this.store);
  @override
  final Uri uri;
  final _Store store;
  @override
  HttpHeaders get headers => _Headers();
  @override
  Future<HttpClientResponse> close() async => store.respond(uri);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Client implements HttpClient {
  _Client(this.store);
  final _Store store;
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _Request(url, store);
  @override
  void close({bool force = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Overrides extends HttpOverrides {
  _Overrides(this.store);
  final _Store store;
  @override
  HttpClient createHttpClient(SecurityContext? context) => _Client(store);
}

void main() {
  testWidgets(
    'notification details reopen and mark all updates list and counter',
    (tester) async {
      final previous = HttpOverrides.current;
      final store = _Store();
      HttpOverrides.global = _Overrides(store);
      var changes = 0;
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NotificationsPage(
                token: 'test-token',
                onNotificationsChanged: () async {
                  changes++;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(store.singleWrites, 0);
        await tester.tap(find.text('Obavijest one'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.byType(SelectableText), findsOneWidget);
        expect(store.singleWrites, 0);
        await tester.tap(find.text('Zatvori'));
        await tester.pumpAndSettle();
        expect(store.read['one'], isTrue);
        expect(store.singleWrites, 1);
        await tester.tap(find.text('Obavijest one'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.tap(find.text('Zatvori'));
        await tester.pumpAndSettle();
        expect(store.singleWrites, 1);
        await tester.tap(find.text('Obavijest two'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.tap(find.text('Zatvori'));
        await tester.pumpAndSettle();
        expect(store.read['two'], isTrue);
        store.read['two'] = false;
        await tester.tap(find.text('Nepročitane'));
        await tester.pumpAndSettle();
        expect(find.text('Obavijest two'), findsOneWidget);
        await tester.tap(find.text('Označi sve kao pročitano'));
        await tester.pumpAndSettle();
        expect(store.allWrites, 1);
        expect(store.read.values.every((v) => v), isTrue);
        expect(find.text('Nemate obavijesti.'), findsOneWidget);
        expect(changes, greaterThanOrEqualTo(4));
        await tester.pumpWidget(const SizedBox());
      } finally {
        HttpOverrides.global = previous;
      }
    },
  );
}
