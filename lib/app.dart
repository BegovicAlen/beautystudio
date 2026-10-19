import 'dart:async';
import 'package:app_links/app_links.dart';
import 'account_recovery_page.dart';
import 'reference_management_page.dart';
import 'payments_page.dart';
import 'form_support.dart';
import 'reservation_history_page.dart';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'content_editor_page.dart';
import 'service_management_page.dart';
import 'user_management_page.dart';
import 'reports_page.dart';
import 'profile_page.dart';
import 'registration_page.dart';
import 'help_faq_page.dart';
import 'studio_info_page.dart';
import 'contact_messages_page.dart';
import 'information_management_page.dart';
import 'services/beauty_studio_api.dart';
import 'services/service_catalog_api.dart';

const _pink = Color(0xffe91e63);

/// Shared in-memory signal for every reservation mutation in this application.
final reservationChanges = ValueNotifier<int>(0);
final reservationCreated = ValueNotifier<int>(0);
final paymentReturns = ValueNotifier<String?>(null);

void notifyReservationChanged() => reservationChanges.value++;

class BeautyStudioApp extends StatefulWidget {
  const BeautyStudioApp({super.key});

  @override
  State<BeautyStudioApp> createState() => _BeautyStudioAppState();
}

class _BeautyStudioAppState extends State<BeautyStudioApp> {
  static const _tokenKey = 'session_token';
  static const _roleKey = 'session_role';
  static const _expiryKey = 'session_expiry';
  final _navigator = GlobalKey<NavigatorState>();
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _links;
  AuthSession? _session;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
    sessionExpired.addListener(_expireSession);
    signInRequested.addListener(_openSignIn);
    _links = _appLinks.uriLinkStream.listen(
      _handleLink,
      onError: (Object e) => debugPrint('Deep link: $e'),
    );
    _appLinks
        .getInitialLink()
        .then((uri) {
          if (uri != null) _handleLink(uri);
        })
        .catchError((Object e) {
          debugPrint('Initial deep link: $e');
        });
  }

  void _handleLink(Uri uri) {
    if (uri.scheme == 'beautystudio' && uri.host == 'payment-return') {
      paymentReturns.value = uri.queryParameters['reservationId'];
    }
  }

  void _openSignIn() => _navigator.currentState?.push(
    MaterialPageRoute<void>(builder: (_) => LoginPage(onSignedIn: _signIn)),
  );
  void _expireSession() {
    if (_session == null) return;
    _clearSession();
    _navigator.currentState?.popUntil((r) => r.isFirst);
    _messenger.currentState?.showSnackBar(
      const SnackBar(content: Text('Sesija je istekla. Prijavite se ponovo.')),
    );
  }

  @override
  void dispose() {
    sessionExpired.removeListener(_expireSession);
    signInRequested.removeListener(_openSignIn);
    _links?.cancel();
    super.dispose();
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final role = prefs.getString(_roleKey);
    final expiry = DateTime.tryParse(prefs.getString(_expiryKey) ?? '');
    if (token != null &&
        role != null &&
        expiry != null &&
        expiry.isAfter(DateTime.now().toUtc())) {
      _session = AuthSession(token: token, role: role, expiresAtUtc: expiry);
    }
    BeautyStudioApi.sessionToken = _session?.token;
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _signIn(AuthSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, session.token);
    await prefs.setString(_roleKey, session.role);
    await prefs.setString(_expiryKey, session.expiresAtUtc.toIso8601String());
    BeautyStudioApi.sessionToken = session.token;
    if (mounted) setState(() => _session = session);
    _navigator.currentState?.popUntil((r) => r.isFirst);
  }

  Future<void> _signOut() async {
    try {
      if (_session != null) await BeautyStudioApi.logout(_session!.token);
    } on ApiException catch (e) {
      _messenger.currentState?.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    await _clearSession();
  }

  Future<void> _clearSession() async {
    BeautyStudioApi.sessionToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_expiryKey);
    if (mounted) setState(() => _session = null);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: _navigator,
    scaffoldMessengerKey: _messenger,
    debugShowCheckedModeBanner: false,
    title: 'BeautyStudio',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _pink,
        primary: _pink,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xfff5f5f5),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xff333333),
        elevation: 0,
        surfaceTintColor: Colors.white,
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
    ),
    home: _loading
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : StudioShell(
            session:
                _session ??
                AuthSession(
                  token: '',
                  role: 'Guest',
                  expiresAtUtc: DateTime.fromMillisecondsSinceEpoch(
                    0,
                    isUtc: true,
                  ),
                ),
            onSignOut: _signOut,
          ),
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onSignedIn});
  final Future<void> Function(AuthSession session) onSignedIn;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    if (_username.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Unesite korisničko ime i lozinku.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSignedIn(
        await BeautyStudioApi.login(_username.text.trim(), _password.text),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Form(
                key: _form,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: Color(0x1ae91e63),
                      child: Icon(Icons.auto_awesome, color: _pink, size: 30),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Dobrodošli u BeautyStudio',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Prijavite se kako biste rezervisali termin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xff666666)),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _username,
                      validator: (v) => Validators.requiredText(v),
                      enabled: !_busy,
                      decoration: const InputDecoration(
                        labelText: 'Korisničko ime ili email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      validator: (v) => Validators.requiredText(v),
                      enabled: !_busy,
                      obscureText: true,
                      onFieldSubmitted: (_) => _login(),
                      decoration: const InputDecoration(
                        labelText: 'Lozinka',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _login,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: _busy
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Prijava'),
                      ),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => RegistrationPage(
                                  onSignedIn: widget.onSignedIn,
                                ),
                              ),
                            ),
                      child: const Text('Nemate račun? Registrujte se'),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const AccountRecoveryPage(),
                              ),
                            ),
                      child: const Text('Zaboravili ste lozinku?'),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Za demonstraciju: mobile / test',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xff777777)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class StudioShell extends StatefulWidget {
  const StudioShell({
    super.key,
    required this.session,
    required this.onSignOut,
  });
  final AuthSession session;
  final Future<void> Function() onSignOut;

  @override
  State<StudioShell> createState() => _StudioShellState();
}

class _StudioShellState extends State<StudioShell> with WidgetsBindingObserver {
  var _index = 0;
  var _serviceCategory = 'Sve';
  var _unreadNotificationCount = 0;
  Timer? _notificationPoller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    referenceLabelsChanged.addListener(_labelsChanged);
    BeautyStudioApi.refreshStatusLabels();
    reservationCreated.addListener(_showCreatedReservation);
    paymentReturns.addListener(_paymentReturn);
    _refreshUnreadNotifications();
    if (paymentReturns.value != null) _paymentReturn();
    _notificationPoller = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshUnreadNotifications(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    referenceLabelsChanged.removeListener(_labelsChanged);
    reservationCreated.removeListener(_showCreatedReservation);
    paymentReturns.removeListener(_paymentReturn);
    _notificationPoller?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshUnreadNotifications();
  }

  Future<void> _refreshUnreadNotifications() async {
    if (widget.session.token.isEmpty) return;
    try {
      final unreadCount = await BeautyStudioApi.unreadNotificationCount(
        widget.session.token,
      );
      if (mounted && unreadCount != _unreadNotificationCount) {
        setState(() => _unreadNotificationCount = unreadCount);
      }
    } on ApiException {
      // A temporary API error must not interrupt the rest of the application.
    }
  }

  void _showCreatedReservation() {
    if (mounted) setState(() => _index = 2);
  }

  Future<void> _paymentReturn() async {
    final id = paymentReturns.value;
    if (id == null || widget.session.token.isEmpty) return;
    paymentReturns.value = null;
    if (mounted) setState(() => _index = 2);
    try {
      final payment = await BeautyStudioApi.verifyPayment(
        widget.session.token,
        id,
      );
      notifyReservationChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              payment.status == 'Paid'
                  ? 'Plaćanje je potvrđeno.'
                  : 'Status plaćanja: ${payment.status}',
            ),
          ),
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

  @override
  void didUpdateWidget(covariant StudioShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.token != widget.session.token) {
      _index = 0;
      _unreadNotificationCount = 0;
      _refreshUnreadNotifications();
      if (paymentReturns.value != null) _paymentReturn();
    }
  }

  void _labelsChanged() {
    if (mounted) setState(() {});
  }

  Widget _notificationIcon(bool selected) => Stack(
    clipBehavior: Clip.none,
    children: [
      Icon(selected ? Icons.notifications : Icons.notifications_outlined),
      if (_unreadNotificationCount > 0)
        Positioned(
          right: -9,
          top: -7,
          child: Container(
            constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: const BoxDecoration(
              color: Color(0xffd81b60),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              _unreadNotificationCount > 9 ? '9+' : '$_unreadNotificationCount',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
    ],
  );

  void _showCategory(String category) => setState(() {
    _serviceCategory = category;
    _index = 1;
  });

  @override
  Widget build(BuildContext context) {
    final isStaff =
        widget.session.role == 'Owner' || widget.session.role == 'Admin';
    final isAdmin = widget.session.role == 'Admin';
    final compactHeader = MediaQuery.sizeOf(context).width < 430;
    final pages = <Widget>[
      isStaff
          ? StaffDashboardPage(token: widget.session.token)
          : HomePage(
              token: widget.session.token,
              onShowServices: () => setState(() => _index = 1),
              onShowCategory: _showCategory,
            ),
      ServicesPage(
        token: widget.session.token,
        initialCategory: _serviceCategory,
      ),
      widget.session.token.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Prijavite se za rezervaciju i pregled svojih termina.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => signInRequested.value++,
                    child: const Text('Prijava'),
                  ),
                ],
              ),
            )
          : ReservationsPage(token: widget.session.token),
      if (!isStaff) ContentPage(token: widget.session.token),
      if (!isStaff) StudioInfoPage(token: widget.session.token),
      if (isStaff) StaffReservationsPage(token: widget.session.token),
      if (isAdmin) ServiceManagementPage(token: widget.session.token),
      if (isAdmin) UserManagementPage(token: widget.session.token),
      if (isAdmin) ReferenceManagementPage(token: widget.session.token),
      if (isStaff) ReportsPage(token: widget.session.token),
      if (isStaff)
        NotificationsPage(
          token: widget.session.token,
          onNotificationsChanged: _refreshUnreadNotifications,
          isStaff: true,
        ),
    ];
    final destinations = <NavigationDestination>[
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Početna',
      ),
      NavigationDestination(
        icon: Icon(Icons.auto_awesome_outlined),
        selectedIcon: Icon(Icons.auto_awesome),
        label: 'Usluge',
      ),
      NavigationDestination(
        icon: Icon(Icons.calendar_month_outlined),
        selectedIcon: Icon(Icons.calendar_month),
        label: 'Termini',
      ),
      if (!isStaff)
        const NavigationDestination(
          icon: Icon(Icons.photo_library_outlined),
          label: 'Galerija',
        ),
      if (!isStaff)
        const NavigationDestination(
          icon: Icon(Icons.info_outline),
          label: 'O nama',
        ),
      if (isStaff)
        const NavigationDestination(
          icon: Icon(Icons.manage_accounts_outlined),
          selectedIcon: Icon(Icons.manage_accounts),
          label: 'Upravljanje',
        ),
      if (isAdmin)
        const NavigationDestination(
          icon: Icon(Icons.design_services_outlined),
          selectedIcon: Icon(Icons.design_services),
          label: 'Katalog',
        ),
      if (isAdmin)
        const NavigationDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: 'Korisnici',
        ),
      if (isAdmin)
        const NavigationDestination(
          icon: Icon(Icons.list_alt),
          label: 'Šifrarnici',
        ),
      if (isStaff)
        const NavigationDestination(
          icon: Icon(Icons.picture_as_pdf_outlined),
          selectedIcon: Icon(Icons.picture_as_pdf),
          label: 'Izvještaji',
        ),
      if (isStaff)
        NavigationDestination(
          icon: _notificationIcon(false),
          selectedIcon: _notificationIcon(true),
          label: 'Obavijesti',
        ),
    ];
    final desktop = isStaff && MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: compactHeader ? 8 : 20,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!compactHeader) ...[
              const CircleAvatar(
                radius: 17,
                backgroundColor: Color(0x1ae91e63),
                child: Icon(Icons.auto_awesome, color: _pink, size: 20),
              ),
              const SizedBox(width: 10),
            ],
            Text(
              'BeautyStudio',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compactHeader ? 16 : 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (isStaff)
              IconButton(
                tooltip: 'Galerija i blog',
                constraints: const BoxConstraints.tightFor(width: 40, height: 40),
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ContentPage(token: widget.session.token),
                  ),
                ),
                icon: const Icon(Icons.collections_bookmark_outlined),
              ),
          ],
        ),
        actions: [
          if (isStaff)
            IconButton(
              tooltip: 'O nama i kontakt',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => StudioInfoPage(token: widget.session.token),
                ),
              ),
              icon: const Icon(Icons.info_outline),
            ),
          IconButton(
            tooltip: 'Help i FAQ',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => HelpFaqPage(token: widget.session.token),
              ),
            ),
            icon: const Icon(Icons.help_outline),
          ),
          if (!isStaff && widget.session.token.isNotEmpty)
            IconButton(
              tooltip: 'Obavijesti',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Obavijesti')),
                    body: NotificationsPage(
                      token: widget.session.token,
                      onNotificationsChanged: _refreshUnreadNotifications,
                    ),
                  ),
                ),
              ),
              icon: _notificationIcon(false),
            ),
          if (widget.session.token.isNotEmpty)
            IconButton(
              tooltip: 'Moj profil',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ProfilePage(token: widget.session.token),
                ),
              ),
              icon: const Icon(Icons.account_circle_outlined),
            ),
          if (widget.session.token.isNotEmpty)
            IconButton(
              tooltip: 'Odjava',
              onPressed: widget.onSignOut,
              icon: const Icon(Icons.logout),
            )
          else
            TextButton(
              onPressed: () => signInRequested.value++,
              child: const Text('Prijava'),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: desktop
            ? Row(
                children: [
                  NavigationRail(
                    extended: true,
                    selectedIndex: _index,
                    onDestinationSelected: (i) => setState(() => _index = i),
                    destinations: destinations
                        .map(
                          (d) => NavigationRailDestination(
                            icon: d.icon,
                            selectedIcon: d.selectedIcon,
                            label: Text(d.label),
                          ),
                        )
                        .toList(),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: pages[_index]),
                ],
              )
            : pages[_index],
      ),
      bottomNavigationBar: desktop
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (index) => setState(() => _index = index),
              destinations: destinations,
            ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.token,
    required this.onShowServices,
    required this.onShowCategory,
  });
  final String token;
  final VoidCallback onShowServices;
  final ValueChanged<String> onShowCategory;
  @override
  State<HomePage> createState() => _HomePageState();
}

class StaffDashboardPage extends StatefulWidget {
  const StaffDashboardPage({super.key, required this.token});
  final String token;

  @override
  State<StaffDashboardPage> createState() => _StaffDashboardPageState();
}

class _StaffDashboardPageState extends State<StaffDashboardPage> {
  late Future<DashboardData> _dashboard;
  late Future<List<ServiceReviewSummary>> _reviewSummary;

  @override
  void initState() {
    super.initState();
    _dashboard = BeautyStudioApi.dashboard(widget.token);
    _reviewSummary = BeautyStudioApi.reviewSummary(widget.token);
    reservationChanges.addListener(_reload);
  }

  @override
  void dispose() {
    reservationChanges.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async => setState(() {
    _dashboard = BeautyStudioApi.dashboard(widget.token);
    _reviewSummary = BeautyStudioApi.reviewSummary(widget.token);
  });

  @override
  Widget build(BuildContext context) => FutureBuilder<DashboardData>(
    future: _dashboard,
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
      final dashboard = snapshot.data!;
      return RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          children: [
            const Text(
              'Administrativni dashboard',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pregled trenutnog poslovanja salona.',
              style: TextStyle(color: Color(0xff777777)),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 700;
                final cards = [
                  _DashboardMetric(
                    icon: Icons.calendar_month_outlined,
                    label: 'Ukupno rezervacija',
                    value: '${dashboard.totalReservations}',
                  ),
                  _DashboardMetric(
                    icon: Icons.pending_actions_outlined,
                    label: 'Aktivne rezervacije',
                    value: '${dashboard.activeReservations}',
                  ),
                  _DashboardMetric(
                    icon: Icons.people_outline,
                    label: 'Aktivni klijenti',
                    value: '${dashboard.activeClients}',
                  ),
                  _DashboardMetric(
                    icon: Icons.payments_outlined,
                    label: 'Ostvareni prihod',
                    value: '${dashboard.completedRevenue} KM',
                  ),
                ];
                return wide
                    ? Row(
                        children: cards
                            .map(
                              (card) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: card,
                                ),
                              ),
                            )
                            .toList(),
                      )
                    : Column(
                        children: cards
                            .map(
                              (card) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: card,
                              ),
                            )
                            .toList(),
                      );
              },
            ),
            const SizedBox(height: 22),
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0x1ae91e63),
                  child: Icon(Icons.workspace_premium_outlined, color: _pink),
                ),
                title: const Text('Najtraženija usluga'),
                subtitle: Text(
                  dashboard.mostPopularService ?? 'Još nema rezervacija',
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ContactMessagesPage(token: widget.token),
                  ),
                ),
                icon: const Icon(Icons.mail_outline),
                label: const Text('Poruke klijenata'),
              ),
            ),
            const SizedBox(height: 26),
            const Text(
              'Najtraženije usluge',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            if (dashboard.popularServices.isEmpty)
              const Text('Još nema podataka o rezervacijama.')
            else
              ...dashboard.popularServices.map(
                (service) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Tooltip(
                    message:
                        '${service.reservationCount} rezervacija · ${service.completedCount} završenih tretmana',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(service.name),
                        const SizedBox(height: 5),
                        LayoutBuilder(
                          builder: (context, c) {
                            final max = dashboard.popularServices
                                .map((x) => x.reservationCount)
                                .reduce((a, b) => a > b ? a : b);
                            return Row(
                              children: [
                                Container(
                                  height: 24,
                                  width: max == 0
                                      ? 0
                                      : c.maxWidth *
                                            0.8 *
                                            service.reservationCount /
                                            max,
                                  decoration: BoxDecoration(
                                    color: _pink,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('${service.reservationCount}'),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 26),
            const Text(
              'Posljednje rezervacije',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            if (dashboard.recentReservations.isEmpty)
              const Text(
                'Još nema rezervacija.',
                style: TextStyle(color: Color(0xff777777)),
              )
            else
              ...dashboard.recentReservations.map(
                (reservation) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(
                      reservation.serviceName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${reservation.clientName} · ${formatDateTime(reservation.startAtUtc)}',
                    ),
                    trailing: Chip(
                      label: Text(statusLabel(reservation.status)),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 26),
            const Text(
              'Ocjene usluga',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<ServiceReviewSummary>>(
              future: _reviewSummary,
              builder: (context, reviews) {
                if (reviews.connectionState != ConnectionState.done ||
                    reviews.hasError ||
                    reviews.data!.isEmpty) {
                  return const Text(
                    'Još nema recenzija.',
                    style: TextStyle(color: Color(0xff777777)),
                  );
                }
                return Column(
                  children: reviews.data!
                      .map(
                        (review) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ServiceReviewsPage(
                                  serviceId: review.serviceId,
                                  serviceName: review.serviceName,
                                ),
                              ),
                            ),
                            leading: const Icon(
                              Icons.star_outline,
                              color: _pink,
                            ),
                            title: Text(review.serviceName),
                            subtitle: Text('${review.reviewCount} recenzija'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${review.averageRating.toStringAsFixed(1)} / 5',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      );
    },
  );
}

class _DashboardMetric extends StatelessWidget {
  const _DashboardMetric({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0x1ae91e63),
            child: Icon(icon, color: _pink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xff777777),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late Future<List<ApiBeautyService>> _services;
  late Future<List<ServiceRecommendation>> _recommendations;
  late Future<ContentRecommendations> _contentRecommendations;
  late final AnimationController _tickerController;

  @override
  void initState() {
    super.initState();
    _services = ServiceCatalogApi.fetch();
    _recommendations = widget.token.isEmpty
        ? Future.value([])
        : BeautyStudioApi.recommendations(widget.token);
    _contentRecommendations = widget.token.isEmpty
        ? Future.value(
            const ContentRecommendations(categories: [], blogPosts: []),
          )
        : BeautyStudioApi.contentRecommendations(widget.token);
    _tickerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) {
      _recommendations = widget.token.isEmpty
          ? Future.value([])
          : BeautyStudioApi.recommendations(widget.token);
      _contentRecommendations = widget.token.isEmpty
          ? Future.value(
              const ContentRecommendations(categories: [], blogPosts: []),
            )
          : BeautyStudioApi.contentRecommendations(widget.token);
    }
  }

  @override
  void dispose() {
    _tickerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.only(bottom: 24),
    children: [
      Container(
        padding: const EdgeInsets.fromLTRB(24, 42, 24, 34),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xff7a1d45), _pink, Color(0xfff8bbd0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'BEAUTY\nSTUDIO',
              style: TextStyle(
                color: Colors.white,
                fontSize: 31,
                height: .9,
                letterSpacing: 6,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'NJEGA • LJEPOTA • SAMOPOUZDANJE',
              style: TextStyle(
                color: Color(0xffffe7f0),
                fontSize: 10,
                letterSpacing: 1.55,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Profesionalna njega i beauty tretmani prilagođeni vama.',
              style: TextStyle(color: Colors.white, fontSize: 16, height: 1.4),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: widget.onShowServices,
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('Rezerviši'),
                ),
                OutlinedButton(
                  onPressed: widget.onShowServices,
                  child: const Text(
                    'Sve usluge',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      _CareTicker(controller: _tickerController),
      Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const _FeaturedCarePanel(),
            const SizedBox(height: 24),
            const _BenefitsRow(),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Izdvojene usluge',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                ),
                TextButton(
                  onPressed: widget.onShowServices,
                  child: const Text('Sve usluge'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<ApiBeautyService>>(
              future: _services,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: TextButton(
                      onPressed: () => setState(() {
                        _services = ServiceCatalogApi.fetch();
                      }),
                      child: const Text(
                        'Usluge trenutno nisu dostupne. Pokušajte ponovo.',
                      ),
                    ),
                  );
                }
                return Column(
                  children: snapshot.data!
                      .take(3)
                      .map(
                        (service) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ServiceCard(
                            token: widget.token,
                            service: service,
                            openReservation: true,
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 22),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Preporučeno za vas',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<ServiceRecommendation>>(
              future: _recommendations,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done ||
                    snapshot.hasError ||
                    snapshot.data!.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Column(
                  children: snapshot.data!
                      .take(3)
                      .map(
                        (item) => Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            onTap: () => _openRecommendedService(item),
                            leading: const CircleAvatar(
                              backgroundColor: Color(0x1ae91e63),
                              child: Icon(Icons.favorite_outline, color: _pink),
                            ),
                            title: Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(item.reason),
                            trailing: Text(
                              '${item.price} KM',
                              style: const TextStyle(
                                color: Color(0xffb51652),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 20),
            FutureBuilder<ContentRecommendations>(
              future: _contentRecommendations,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done ||
                    snapshot.hasError ||
                    (snapshot.data!.categories.isEmpty &&
                        snapshot.data!.blogPosts.isEmpty)) {
                  return const SizedBox.shrink();
                }
                final content = snapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (content.categories.isNotEmpty) ...[
                      const Text(
                        'Preporučene kategorije',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: content.categories
                            .map(
                              (category) => Tooltip(
                                message: category.reason,
                                child: ActionChip(
                                  avatar: const Icon(
                                    Icons.category_outlined,
                                    size: 17,
                                    color: _pink,
                                  ),
                                  label: Text(category.name),
                                  onPressed: () =>
                                      widget.onShowCategory(category.name),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 18),
                    ],
                    if (content.blogPosts.isNotEmpty) ...[
                      const Text(
                        'Preporučeno iz bloga',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...content.blogPosts.map(
                        (post) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => RecommendedBlogPage(
                                  token: widget.token,
                                  recommendation: post,
                                ),
                              ),
                            ),
                            leading: const CircleAvatar(
                              backgroundColor: Color(0x1ae91e63),
                              child: Icon(Icons.article_outlined, color: _pink),
                            ),
                            title: Text(post.title),
                            subtitle: Text(post.reason),
                            trailing: const Icon(Icons.chevron_right),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ],
  );

  Future<void> _openRecommendedService(
    ServiceRecommendation recommendation,
  ) async {
    try {
      final services = await ServiceCatalogApi.fetch();
      final matches = services
          .where((item) => item.id == recommendation.serviceId)
          .toList();
      if (matches.isNotEmpty && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                ServiceDetailPage(token: widget.token, service: matches.first),
          ),
        );
      }
    } on ApiException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preporučena kategorija trenutno nije dostupna.'),
          ),
        );
      }
    }
  }
}

class _CareTicker extends StatelessWidget {
  const _CareTicker({required this.controller});
  final Animation<double> controller;

  static const _items = [
    'OBRVE',
    'TREPAVICE',
    'NJEGA LICA',
    'PREMIUM NJEGA',
    'KREME',
    'MAKEUP',
  ];

  @override
  Widget build(BuildContext context) => Container(
    height: 42,
    color: const Color(0xff2a2024),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final text = _items.join('     ✦     ');
        final contentWidth = constraints.maxWidth * 1.9;
        return ClipRect(
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, child) => Transform.translate(
              offset: Offset(-contentWidth * controller.value, 0),
              child: child,
            ),
            child: SizedBox(
              width: contentWidth * 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '$text     ✦     $text',
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  style: const TextStyle(
                    color: Color(0xffffdce9),
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _FeaturedCarePanel extends StatelessWidget {
  const _FeaturedCarePanel();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xffffe7ef),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xffffc5d8)),
    ),
    child: Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.visibility_outlined, color: _pink, size: 28),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Istaknuta njega',
                style: TextStyle(
                  color: Color(0xffa71b4e),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .5,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Obrve, trepavice i njega lica',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 3),
              Text(
                'Pronađite tretman za sebe.',
                style: TextStyle(color: Color(0xff6f5962), fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class ServicesPage extends StatefulWidget {
  const ServicesPage({
    super.key,
    required this.token,
    this.initialCategory = 'Sve',
  });
  final String token;
  final String initialCategory;
  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  String _category = 'Sve';
  late Future<List<ApiBeautyService>> _services;
  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    _services = ServiceCatalogApi.fetch();
    if (_category != 'Sve') {
      _services.then((rows) {
        final chosen = rows.where((s) => s.category == _category);
        if (chosen.isNotEmpty) _recordCategory(chosen.first.categoryId);
      });
    }
  }

  Future<void> _recordCategory(int categoryId) async {
    try {
      await BeautyStudioApi.recordCategoryView(widget.token, categoryId);
    } on ApiException catch (e) {
      debugPrint('Praćenje aktivnosti nije uspjelo: ${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<ApiBeautyService>>(
    future: _services,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: FilledButton(
            onPressed: () => setState(() {
              _services = ServiceCatalogApi.fetch();
            }),
            child: const Text('Pokušajte ponovo'),
          ),
        );
      }
      final categories = [
        'Sve',
        ...snapshot.data!.map((service) => service.category).toSet(),
      ];
      final visible = _category == 'Sve'
          ? snapshot.data!
          : snapshot.data!
                .where((service) => service.category == _category)
                .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 6),
            child: Text(
              'Usluge',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Odaberite tretman koji najbolje odgovara vašim potrebama.',
              style: TextStyle(color: Color(0xff777777)),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 42,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = categories[index];
                return ChoiceChip(
                  label: Text(category),
                  selected: _category == category,
                  onSelected: (_) {
                    setState(() => _category = category);
                    if (category != 'Sve') {
                      final matches = snapshot.data!
                          .where((service) => service.category == category)
                          .toList();
                      if (matches.isNotEmpty) {
                        _recordCategory(matches.first.categoryId);
                      }
                    }
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              itemCount: visible.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  ServiceCard(token: widget.token, service: visible[index]),
            ),
          ),
        ],
      );
    },
  );
}

class ServiceCard extends StatelessWidget {
  const ServiceCard({
    super.key,
    required this.token,
    required this.service,
    this.openReservation = false,
  });
  final String token;
  final ApiBeautyService service;
  final bool openReservation;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ServiceDetailPage(
            token: token,
            service: service,
            openReservation: openReservation,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 86,
            height: 110,
            color: const Color(0xffffe1eb),
            alignment: Alignment.center,
            child: const Icon(
              Icons.auto_awesome_outlined,
              color: Color(0xffb51652),
              size: 36,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.category,
                    style: const TextStyle(
                      color: Color(0xffa71b4e),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    service.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_outlined,
                        size: 16,
                        color: Color(0xff777777),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${service.durationMinutes} min',
                        style: const TextStyle(color: Color(0xff777777)),
                      ),
                      const Spacer(),
                      Text(
                        '${service.price} KM',
                        style: const TextStyle(
                          color: Color(0xffb51652),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 10),
            child: Icon(Icons.chevron_right, color: Color(0xff777777)),
          ),
        ],
      ),
    ),
  );
}

Future<void> showReviewDetails(
  BuildContext context,
  ServiceReview review,
  String serviceName,
) => showDialog<void>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    title: const Text('Detalji recenzije'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(serviceName, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text('Klijent: ${review.clientName}'),
          Text('Ocjena: ${review.rating}/5 ★'),
          Text('Datum: ${formatDateTime(review.createdAtUtc)}'),
          const SizedBox(height: 16),
          const Text('Komentar', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          SelectableText(review.comment?.isNotEmpty == true
              ? review.comment!
              : 'Klijent nije ostavio komentar.'),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(dialogContext).pop(),
        child: const Text('Zatvori'),
      ),
    ],
  ),
);

class ServiceReviewsPage extends StatefulWidget {
  const ServiceReviewsPage({
    super.key,
    required this.serviceId,
    required this.serviceName,
  });

  final int serviceId;
  final String serviceName;

  @override
  State<ServiceReviewsPage> createState() => _ServiceReviewsPageState();
}

class _ServiceReviewsPageState extends State<ServiceReviewsPage> {
  late Future<List<ServiceReview>> _reviews;

  @override
  void initState() {
    super.initState();
    _reviews = BeautyStudioApi.serviceReviews(widget.serviceId);
  }

  void _reload() => setState(() {
    _reviews = BeautyStudioApi.serviceReviews(widget.serviceId);
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Recenzije: ${widget.serviceName}')),
    body: FutureBuilder<List<ServiceReview>>(
      future: _reviews,
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
        final reviews = snapshot.data!;
        if (reviews.isEmpty) {
          return const Center(child: Text('Još nema recenzija za ovu uslugu.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: reviews.length,
          itemBuilder: (context, index) {
            final review = reviews[index];
            return Card(
              child: ListTile(
                title: Text(review.clientName),
                subtitle: Text(
                  '${review.rating}/5 ★ · ${formatDateTime(review.createdAtUtc)}\n${review.comment?.isNotEmpty == true ? review.comment! : 'Bez komentara'}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showReviewDetails(context, review, widget.serviceName),
              ),
            );
          },
        );
      },
    ),
  );
}

class ServiceDetailPage extends StatefulWidget {
  const ServiceDetailPage({
    super.key,
    required this.token,
    required this.service,
    this.openReservation = false,
  });
  final String token;
  final ApiBeautyService service;
  final bool openReservation;
  @override
  State<ServiceDetailPage> createState() => _ServiceDetailPageState();
}

class _ServiceDetailPageState extends State<ServiceDetailPage> {
  DateTime? _selected;
  var _busy = false;
  late Future<List<ServiceReview>> _reviews;

  @override
  void initState() {
    super.initState();
    _recordView();
    _reviews = BeautyStudioApi.serviceReviews(widget.service.id);
    if (widget.openReservation) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _chooseSlot());
    }
  }

  Future<void> _recordView() async {
    try {
      await BeautyStudioApi.recordServiceView(widget.token, widget.service.id);
    } on ApiException catch (e) {
      debugPrint('Praćenje aktivnosti nije uspjelo: ${e.message}');
    }
  }

  Future<void> _chooseSlot() async {
    if (widget.token.isEmpty) {
      signInRequested.value++;
      return;
    }
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: _selected ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (day == null || !mounted) return;
    try {
      final slots = await BeautyStudioApi.availableSlots(
        widget.token,
        widget.service.id,
        day,
      );
      if (!mounted) return;
      final selected = await showDialog<DateTime>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Odaberite slobodan termin'),
          content: SizedBox(
            width: 420,
            child: slots.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Nema slobodnih termina za odabrani datum.'),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: slots
                        .map(
                          (slot) => OutlinedButton(
                            onPressed: () => Navigator.pop(context, slot),
                            child: Text(
                              '${slot.hour.toString().padLeft(2, '0')}:${slot.minute.toString().padLeft(2, '0')}',
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Nazad'),
            ),
          ],
        ),
      );
      if (selected != null && mounted) setState(() => _selected = selected);
    } on ApiException catch (error) {
      _show(error.message);
    }
  }

  Future<void> _reserve() async {
    if (_selected == null) {
      _show('Odaberite datum i vrijeme termina.');
      return;
    }
    if (!_selected!.isAfter(DateTime.now())) {
      _show('Termin mora biti u budućnosti.');
      return;
    }
    final paymentMethod = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Odaberite način plaćanja'),
        content: const Text(
          'Kartično plaćanje završavate putem Stripea. Plaćanje na mjestu bit će označeno kao plaćeno tek kada se tretman završi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Nazad'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context, 'OnSite'),
            icon: const Icon(Icons.storefront_outlined),
            label: const Text('Na mjestu'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, 'Card'),
            icon: const Icon(Icons.credit_card_outlined),
            label: const Text('Kartično'),
          ),
        ],
      ),
    );
    if (paymentMethod == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await BeautyStudioApi.createReservation(
        widget.token,
        widget.service.id,
        _selected!,
        paymentMethod,
      );
      notifyReservationChanged();
      reservationCreated.value++;
      if (mounted) {
        _show(
          paymentMethod == 'Card'
              ? 'Rezervacija je zaprimljena. Plaćanje karticom možete pokrenuti u Mojim terminima.'
              : 'Rezervacija je zaprimljena i čeka potvrdu. Plaćate na mjestu nakon tretmana.',
        );
        Navigator.of(context).pop();
      }
    } on ApiException catch (error) {
      _show(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _show(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Detalji usluge')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          height: 190,
          decoration: BoxDecoration(
            color: const Color(0xffffe1eb),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.auto_awesome,
            size: 72,
            color: Color(0xffb51652),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          widget.service.category.toUpperCase(),
          style: const TextStyle(
            color: Color(0xffa71b4e),
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.service.name,
          style: const TextStyle(
            fontSize: 30,
            height: 1.1,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Opis tretmana',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(widget.service.description, style: const TextStyle(height: 1.4)),
        const SizedBox(height: 20),
        Row(
          children: [
            const Icon(Icons.schedule_outlined),
            const SizedBox(width: 8),
            Text('Trajanje: ${widget.service.durationMinutes} min'),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.payments_outlined),
            const SizedBox(width: 8),
            Text('Cijena: ${widget.service.price} KM'),
          ],
        ),
        const SizedBox(height: 28),
        const Text(
          'Rezervišite termin',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _busy ? null : _chooseSlot,
          icon: const Icon(Icons.calendar_month),
          label: Text(
            _selected == null
                ? 'Odaberite datum i vrijeme'
                : formatDateTime(_selected!),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy ? null : _reserve,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: _busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Pošaljite rezervaciju'),
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Recenzije klijenata',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<ServiceReview>>(
          future: _reviews,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done ||
                snapshot.hasError) {
              return const SizedBox.shrink();
            }
            if (snapshot.data!.isEmpty) {
              return const Text(
                'Još nema recenzija za ovu uslugu.',
                style: TextStyle(color: Color(0xff777777)),
              );
            }
            final reviews = snapshot.data!;
            final average =
                reviews
                    .map((review) => review.rating)
                    .reduce((left, right) => left + right) /
                reviews.length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Text(
                          average.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: _pink,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Prosječna ocjena · ${reviews.length} ${reviews.length == 1 ? 'recenzija' : 'recenzija'}',
                              ),
                              const SizedBox(height: 6),
                              ...List.generate(5, (index) {
                                final rating = 5 - index;
                                final count = reviews
                                    .where((review) => review.rating == rating)
                                    .length;
                                return Row(
                                  children: [
                                    SizedBox(
                                      width: 26,
                                      child: Text('$rating ★'),
                                    ),
                                    Expanded(
                                      child: LinearProgressIndicator(
                                        value: count / reviews.length,
                                        color: _pink,
                                        backgroundColor: const Color(
                                          0xffffe1eb,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(width: 18, child: Text('$count')),
                                  ],
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ...reviews.map(
                  (review) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      onTap: () => showReviewDetails(
                        context,
                        review,
                        widget.service.name,
                      ),
                      title: Text(review.clientName),
                      subtitle: Text(
                        '${review.comment ?? 'Bez komentara'}\n${formatDateTime(review.createdAtUtc)}',
                      ),
                      isThreeLine: true,
                      trailing: Text(
                        '${review.rating}/5 ★',
                        style: const TextStyle(
                          color: Color(0xffb51652),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class ContentPage extends StatefulWidget {
  const ContentPage({super.key, required this.token});
  final String token;
  @override
  State<ContentPage> createState() => _ContentPageState();
}

class _ContentPageState extends State<ContentPage> {
  late Future<List<GalleryContentItem>> _gallery;
  late Future<List<BlogContentItem>> _blogPosts;
  String _galleryQuery = '';
  String _galleryCategory = 'Sve';
  @override
  void initState() {
    super.initState();
    _gallery = BeautyStudioApi.gallery();
    _blogPosts = BeautyStudioApi.blogPosts();
  }

  Future<void> _openGallery(GalleryContentItem item) async {
    try {
      await BeautyStudioApi.recordGalleryView(widget.token, item.id);
    } on ApiException catch (e) {
      debugPrint('Praćenje aktivnosti nije uspjelo: ${e.message}');
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.title),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RemoteImage(url: item.imageUrl, height: 280),
                const SizedBox(height: 12),
                Text(
                  item.category,
                  style: const TextStyle(color: Color(0xff777777)),
                ),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(item.description),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zatvorite'),
          ),
        ],
      ),
    );
  }

  Future<void> _openBlog(BlogContentItem post) async {
    try {
      post = await BeautyStudioApi.blog(post.id);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    }
    try {
      await BeautyStudioApi.recordBlogView(widget.token, post.id);
    } on ApiException catch (e) {
      debugPrint('Praćenje aktivnosti nije uspjelo: ${e.message}');
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(post.title),
        content: SizedBox(
          width: 760,
          child: Scrollbar(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(right: 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post.imageUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: _RemoteImage(url: post.imageUrl!, height: 300),
                    ),
                  Text(
                    post.content,
                    style: const TextStyle(fontSize: 16, height: 1.55),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zatvorite'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Galerija i blog')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Galerija radova',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<GalleryContentItem>>(
          future: _gallery,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError || snapshot.data!.isEmpty) {
              return const Text(
                'Galerija će uskoro sadržavati objavljene radove.',
                style: TextStyle(color: Color(0xff777777)),
              );
            }
            final categories = [
              'Sve',
              ...snapshot.data!.map((item) => item.category).toSet(),
            ];
            final visible = snapshot.data!
                .where(
                  (item) =>
                      (_galleryCategory == 'Sve' ||
                          item.category == _galleryCategory) &&
                      (_galleryQuery.trim().isEmpty ||
                          item.title.toLowerCase().contains(
                            _galleryQuery.trim().toLowerCase(),
                          ) ||
                          item.description.toLowerCase().contains(
                            _galleryQuery.trim().toLowerCase(),
                          ) ||
                          item.category.toLowerCase().contains(
                            _galleryQuery.trim().toLowerCase(),
                          )),
                )
                .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  onChanged: (value) => setState(() => _galleryQuery = value),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Pretražite galeriju',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _galleryCategory,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Kategorija',
                    border: OutlineInputBorder(),
                  ),
                  items: categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _galleryCategory = value);
                  },
                ),
                const SizedBox(height: 14),
                if (visible.isEmpty)
                  const Text(
                    'Nema radova prema odabranim kriterijima.',
                    style: TextStyle(color: Color(0xff777777)),
                  )
                else
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: visible
                        .map(
                          (item) => SizedBox(
                            width: 220,
                            child: Card(
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => _openGallery(item),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _RemoteImage(
                                      url: item.imageUrl,
                                      height: 132,
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            item.category,
                                            style: const TextStyle(
                                              color: Color(0xff777777),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 30),
        const Text(
          'Beauty blog',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Savjeti, postupci i njega nakon tretmana.',
          style: TextStyle(color: Color(0xff777777)),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<BlogContentItem>>(
          future: _blogPosts,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError || snapshot.data!.isEmpty) {
              return const Text(
                'Blog objave će uskoro biti dostupne.',
                style: TextStyle(color: Color(0xff777777)),
              );
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth >= 780;
                final cardWidth = twoColumns
                    ? (constraints.maxWidth - 16) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: snapshot.data!
                      .map(
                        (post) => SizedBox(
                          width: cardWidth,
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => _openBlog(post),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  post.imageUrl == null
                                      ? const AspectRatio(
                                          aspectRatio: 16 / 9,
                                          child: ColoredBox(
                                            color: Color(0xffffe1eb),
                                            child: Center(
                                              child: Icon(
                                                Icons.brush_outlined,
                                                size: 48,
                                                color: _pink,
                                              ),
                                            ),
                                          ),
                                        )
                                      : AspectRatio(
                                          aspectRatio: 16 / 9,
                                          child: _RemoteImage(
                                            url: post.imageUrl!,
                                            height: double.infinity,
                                          ),
                                        ),
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          post.title,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 7),
                                        Text(
                                          post.content,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            height: 1.4,
                                            color: Color(0xff5f5458),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        const Row(
                                          children: [
                                            Text(
                                              'Pročitajte članak',
                                              style: TextStyle(
                                                color: _pink,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            Spacer(),
                                            Icon(
                                              Icons.arrow_forward,
                                              color: _pink,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            );
          },
        ),
      ],
    ),
  );
}

class RecommendedBlogPage extends StatefulWidget {
  const RecommendedBlogPage({
    super.key,
    required this.token,
    required this.recommendation,
  });
  final String token;
  final BlogRecommendation recommendation;

  @override
  State<RecommendedBlogPage> createState() => _RecommendedBlogPageState();
}

class _RecommendedBlogPageState extends State<RecommendedBlogPage> {
  late final Future<BlogContentItem?> _post;

  @override
  void initState() {
    super.initState();
    _post = _load();
  }

  Future<BlogContentItem?> _load() async {
    try {
      await BeautyStudioApi.recordBlogView(
        widget.token,
        widget.recommendation.blogPostId,
      );
    } on ApiException {
      // Prikaz članka ne treba blokirati ako se signal preporuke ne može evidentirati.
    }
    return BeautyStudioApi.blog(widget.recommendation.blogPostId);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Beauty blog')),
    body: FutureBuilder<BlogContentItem?>(
      future: _post,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Članak trenutno nije dostupan.'));
        }
        final post = snapshot.data;
        if (post == null) {
          return const Center(child: Text('Ovaj članak više nije objavljen.'));
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (post.imageUrl != null) ...[
              _RemoteImage(url: post.imageUrl!, height: 230),
              const SizedBox(height: 20),
            ],
            Text(
              post.title,
              style: const TextStyle(
                fontSize: 28,
                height: 1.1,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              post.content,
              style: const TextStyle(fontSize: 16, height: 1.55),
            ),
          ],
        );
      },
    ),
  );
}

class _RemoteImage extends StatelessWidget {
  const _RemoteImage({required this.url, required this.height});
  final String url;
  final double height;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: height,
    child: Image.network(
      BeautyStudioApi.contentImageUrl(url),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const ColoredBox(
        color: Color(0xffffe1eb),
        child: Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: _pink,
            size: 34,
          ),
        ),
      ),
    ),
  );
}

class ReservationsPage extends StatefulWidget {
  const ReservationsPage({super.key, required this.token});
  final String token;
  @override
  State<ReservationsPage> createState() => _ReservationsPageState();
}

class _ReservationsPageState extends State<ReservationsPage> {
  late Future<List<ReservationRecord>> _reservations;
  final Set<String> _reviewedReservationIds = {};
  var _reservationRevision = 0;
  Timer? _statusPoller;

  @override
  void initState() {
    super.initState();
    _reservations = BeautyStudioApi.myReservations(widget.token);
    reservationChanges.addListener(_reload);
    _statusPoller = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _reload(),
    );
  }

  @override
  void dispose() {
    reservationChanges.removeListener(_reload);
    _statusPoller?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    final reservations = BeautyStudioApi.myReservations(widget.token);
    if (mounted) {
      setState(() {
        _reservationRevision++;
        _reservations = reservations;
      });
    }
    try {
      await reservations;
    } on ApiException {
      // FutureBuilder shows the request error while this listener stays safe.
    }
  }

  Future<void> _cancel(ReservationRecord item) async {
    final reason = await reservationReasonDialog(
      context,
      'Otkažite rezervaciju',
      'Razlog otkazivanja',
      'Otkažite',
    );
    if (reason == null || !mounted) return;
    try {
      final cancelled = await BeautyStudioApi.cancelReservation(
        widget.token,
        item.id,
        reason,
      );
      final displayedReservations = await _reservations;
      if (!mounted) return;
      setState(() {
        _reservationRevision++;
        _reservations = Future.value(
          displayedReservations
              .map(
                (current) => current.id == cancelled.id ? cancelled : current,
              )
              .toList(),
        );
      });
      notifyReservationChanged();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _review(ReservationRecord item) async {
    var rating = 5;
    final comment = TextEditingController();
    final accepted = await showCompletedDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Ocijenite: ${item.serviceName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: rating,
                decoration: const InputDecoration(labelText: 'Ocjena'),
                items: List.generate(5, (index) {
                  final value = index + 1;
                  return DropdownMenuItem(
                    value: value,
                    child: Text('$value / 5'),
                  );
                }),
                onChanged: (value) => setDialogState(() => rating = value ?? 5),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: comment,
                maxLines: 3,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Komentar (opcionalno)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Nazad'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Pošaljite'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) return;
    try {
      await BeautyStudioApi.createReview(
        widget.token,
        item.id,
        rating,
        comment.text.trim().isEmpty ? null : comment.text.trim(),
      );
      if (mounted) {
        setState(() => _reviewedReservationIds.add(item.id));
        notifyReservationChanged();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hvala na vašoj recenziji.')),
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _pay(ReservationRecord item) async {
    final accepted = await showCompletedDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Potvrdite plaćanje'),
        content: Text(
          'Želite li pokrenuti kartično plaćanje za ${item.serviceName}? Ukupna cijena rezervacije je ${item.totalAmount.toStringAsFixed(2)} ${item.currency.toUpperCase()}. Stripe će prikazati tačan iznos punog plaćanja ili avansa prije potvrde.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Nazad'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Nastavite na plaćanje'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    try {
      final checkout = await BeautyStudioApi.startCheckout(
        widget.token,
        item.id,
      );
      await _reload();
      if (!await launchUrl(
        Uri.parse(checkout.url),
        mode: LaunchMode.externalApplication,
      )) {
        throw const ApiException('Stripe Checkout nije moguće otvoriti.');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nakon plaćanja automatski se vraćate u aplikaciju.'),
          ),
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

  Future<void> _verifyPayment(ReservationRecord item) async {
    try {
      final payment = await BeautyStudioApi.verifyPayment(
        widget.token,
        item.id,
      );
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              payment.status == 'Paid'
                  ? 'Plaćanje je evidentirano: ${payment.amount.toStringAsFixed(2)} ${payment.currency.toUpperCase()}.'
                  : 'Plaćanje još nije završeno.',
            ),
          ),
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PaymentsPage(token: widget.token),
              ),
            ),
            icon: const Icon(Icons.receipt_long),
            label: const Text('Historija plaćanja'),
          ),
        ),
      ),
      const Padding(
        padding: EdgeInsets.fromLTRB(20, 24, 20, 4),
        child: Text(
          'Moji termini',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
        ),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          'Pratite status svojih rezervacija.',
          style: TextStyle(color: Color(0xff777777)),
        ),
      ),
      const SizedBox(height: 16),
      Expanded(
        child: FutureBuilder<List<ReservationRecord>>(
          key: ValueKey(_reservationRevision),
          future: _reservations,
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
            if (snapshot.data!.isEmpty) {
              return RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  children: const [
                    SizedBox(height: 150),
                    Center(child: Text('Još nemate rezervisanih termina.')),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                itemCount: snapshot.data!.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = snapshot.data![index];
                  final cancellable =
                      item.status == 'Pending' || item.status == 'Confirmed';
                  final canReview =
                      item.status.split('|').first == 'Completed' &&
                      !item.hasReview &&
                      !_reviewedReservationIds.contains(item.id);
                  final isCardPayment = item.paymentMethod == 'Card';
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.serviceName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(formatDateTime(item.startAtUtc)),
                          const SizedBox(height: 6),
                          Text(
                            'Način plaćanja: ${isCardPayment ? 'Kartično' : 'Na mjestu'}',
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              Chip(
                                backgroundColor: statusColor(
                                  item.status,
                                ).withValues(alpha: .12),
                                label: Text(reservationStatusLabel(item)),
                              ),
                              Chip(
                                label: Text(
                                  paymentStatusLabel(item.paymentStatus),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Cijena: ${item.totalAmount.toStringAsFixed(2)} KM · Plaćeno: ${item.paidAmount.toStringAsFixed(2)} KM',
                          ),
                          if (item.isPaid && item.remainingAmount > 0)
                            Text(
                              'Preostalo na mjestu: ${item.remainingAmount.toStringAsFixed(2)} KM',
                            ),
                          if (item.cancellationReason != null)
                            Text('Razlog: ${item.cancellationReason!}'),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Wrap(
                              spacing: 4,
                              children: [
                                TextButton.icon(
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          ReservationDetailPage(item: item),
                                    ),
                                  ),
                                  icon: const Icon(Icons.visibility_outlined),
                                  label: const Text('Detalji'),
                                ),
                                if (cancellable)
                                  TextButton(
                                    onPressed: () => _cancel(item),
                                    child: const Text('Otkažite termin'),
                                  ),
                                if (cancellable &&
                                    isCardPayment &&
                                    !item.isPaid &&
                                    item.paymentStatus != 'RefundPending' &&
                                    item.paymentStatus != 'Refunded')
                                  TextButton.icon(
                                    onPressed: () => _pay(item),
                                    icon: const Icon(Icons.payment_outlined),
                                    label: const Text('Platite'),
                                  ),
                                if (cancellable &&
                                    isCardPayment &&
                                    !item.isPaid)
                                  TextButton(
                                    onPressed: () => _verifyPayment(item),
                                    child: const Text('Provjerite plaćanje'),
                                  ),
                                if (canReview)
                                  FilledButton.tonal(
                                    onPressed: () => _review(item),
                                    child: const Text('Ostavite recenziju'),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    ],
  );
}

class ReservationDetailPage extends StatelessWidget {
  const ReservationDetailPage({super.key, required this.item});
  final ReservationRecord item;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Detalji rezervacije')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.calendar_month_outlined, size: 58, color: _pink),
        const SizedBox(height: 18),
        Text(
          item.serviceName,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 18),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.schedule_outlined, color: _pink),
                title: const Text('Početak termina'),
                subtitle: Text(formatDateTime(item.startAtUtc)),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.timer_outlined, color: _pink),
                title: const Text('Završetak termina'),
                subtitle: Text(formatDateTime(item.endAtUtc)),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Status plaćanja'),
                subtitle: Text(paymentStatusLabel(item.paymentStatus)),
              ),
              ListTile(
                title: const Text('Cijena i naplaćeni iznos'),
                subtitle: Text(
                  '${item.totalAmount.toStringAsFixed(2)} KM · Plaćeno ${item.paidAmount.toStringAsFixed(2)} KM',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline, color: _pink),
                title: const Text('Status'),
                subtitle: Text(reservationStatusLabel(item)),
              ),
            ],
          ),
        ),
        if (item.cancellationReason != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.cancel_outlined, color: _pink),
                title: const Text('Razlog otkazivanja'),
                subtitle: Text(item.cancellationReason!),
              ),
            ),
          ),
      ],
    ),
  );
}

class StaffReservationsPage extends StatefulWidget {
  const StaffReservationsPage({super.key, required this.token});
  final String token;

  @override
  State<StaffReservationsPage> createState() => _StaffReservationsPageState();
}

class _StaffReservationsPageState extends State<StaffReservationsPage> {
  List<StaffReservationRecord> _reservations = const [];
  var _loading = true;
  String? _error;
  String _query = '';
  String _statusFilter = 'Sve';
  DateTime? _dateFilter;
  var _reservationRevision = 0;
  Timer? _statusPoller;

  @override
  void initState() {
    super.initState();
    reservationChanges.addListener(_reload);
    _reload();
    _statusPoller = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _reload(),
    );
  }

  @override
  void dispose() {
    reservationChanges.removeListener(_reload);
    _statusPoller?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final reservations = await BeautyStudioApi.staffReservations(
        widget.token,
      );
      if (mounted) {
        setState(() {
          _reservations = reservations;
          _loading = false;
          _reservationRevision++;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _changeStatus(StaffReservationRecord item, String target) async {
    final reason = await reservationReasonDialog(
      context,
      '${statusLabel(target)} rezervaciju',
      'Razlog promjene statusa',
      'Potvrdite',
    );
    if (reason == null || !mounted) return;
    try {
      final changed = await BeautyStudioApi.changeReservationStatus(
        widget.token,
        item.id,
        target,
        reason,
      );
      final updatedItems = _reservations
          .map(
            (current) => current.id == item.id
                ? StaffReservationRecord(
                    id: current.id,
                    clientId: current.clientId,
                    clientName: current.clientName,
                    clientEmail: current.clientEmail,
                    serviceName: current.serviceName,
                    startAtUtc: current.startAtUtc,
                    endAtUtc: current.endAtUtc,
                    paymentMethod: current.paymentMethod,
                    status: changed.status,
                    statusDisplayName: changed.statusDisplayName,
                    paymentStatus: current.paymentStatus,
                    paymentAmount: current.paymentAmount,
                    paymentCurrency: current.paymentCurrency,
                    paidAtUtc: current.paidAtUtc,
                    cancellationReason: changed.cancellationReason,
                  )
                : current,
          )
          .toList();
      if (mounted) {
        setState(() {
          _reservations = updatedItems;
          _reservationRevision++;
        });
      }
      notifyReservationChanged();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _showAudit(StaffReservationRecord item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ReservationAuditPage(token: widget.token, reservationId: item.id),
      ),
    );
  }

  Future<void> _showClientHistory(StaffReservationRecord item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ClientHistoryPage(token: widget.token, clientId: item.clientId),
      ),
    );
  }

  List<String> _nextStatuses(String status) {
    final allowed = switch (status) {
      'Pending' => ['Confirmed', 'Cancelled'],
      'Confirmed' => ['Completed', 'Cancelled'],
      _ => <String>[],
    };
    return [
      for (final definition in BeautyStudioApi.statusDefinitions)
        if (definition.isActive && allowed.contains(definition.code))
          '${definition.code}|${definition.id}',
    ];
  }

  List<StaffReservationRecord> get _visibleReservations =>
      _reservations.where((item) {
        final matchesQuery =
            _query.trim().isEmpty ||
            '${item.clientName} ${item.clientEmail} ${item.serviceName}'
                .toLowerCase()
                .contains(_query.trim().toLowerCase());
        final matchesStatus =
            _statusFilter == 'Sve' || item.status == _statusFilter;
        final matchesDate =
            _dateFilter == null ||
            (item.startAtUtc.year == _dateFilter!.year &&
                item.startAtUtc.month == _dateFilter!.month &&
                item.startAtUtc.day == _dateFilter!.day);
        return matchesQuery && matchesStatus && matchesDate;
      }).toList();

  Future<void> _chooseDateFilter() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _dateFilter ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected != null && mounted) setState(() => _dateFilter = selected);
  }

  Widget _table(List<StaffReservationRecord> items) => SingleChildScrollView(
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        dataRowMinHeight: 64,
        dataRowMaxHeight: 80,
        columns: const [
          DataColumn(label: Text('Klijent')),
          DataColumn(label: Text('Usluga')),
          DataColumn(label: Text('Termin')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Plaćanje')),
          DataColumn(label: Text('Akcije')),
        ],
        rows: items
            .map(
              (item) => DataRow(
                cells: [
                  DataCell(Text(item.clientName)),
                  DataCell(Text(item.serviceName)),
                  DataCell(Text(formatDateTime(item.startAtUtc))),
                  DataCell(
                    Chip(
                      backgroundColor: statusColor(
                        item.status,
                      ).withValues(alpha: .12),
                      label: Text(reservationStatusLabel(item)),
                    ),
                  ),
                  DataCell(_PaymentStatusBadge(item: item, compact: true)),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Historija klijenta',
                          onPressed: () => _showClientHistory(item),
                          icon: const Icon(Icons.person_search),
                        ),
                        IconButton(
                          tooltip: 'Historija promjena',
                          onPressed: () => _showAudit(item),
                          icon: const Icon(Icons.history),
                        ),
                        if (_nextStatuses(item.status).isNotEmpty)
                          PopupMenuButton<String>(
                            onSelected: (status) => _changeStatus(item, status),
                            itemBuilder: (context) => _nextStatuses(item.status)
                                .map(
                                  (status) => PopupMenuItem(
                                    value: status,
                                    enabled:
                                        status.split('|').first !=
                                            'Completed' ||
                                        !item.endAtUtc.isAfter(DateTime.now()),
                                    child: Tooltip(
                                      message:
                                          status.split('|').first ==
                                                  'Completed' &&
                                              item.endAtUtc.isAfter(
                                                DateTime.now(),
                                              )
                                          ? 'Tretman možete završiti nakon isteka zakazanog trajanja.'
                                          : 'Promijenite status',
                                      child: Text(statusLabel(status)),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final visible = _visibleReservations;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 4),
          child: Text(
            'Upravljanje terminima',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Potvrdite, otkažite ili završite rezervacije. Svaka promjena ostaje zabilježena.',
            style: TextStyle(color: Color(0xff777777)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ContentEditorPage(token: widget.token),
                  ),
                ),
                icon: const Icon(Icons.edit_note),
                label: const Text('Uredite galeriju i blog'),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        InformationManagementPage(token: widget.token),
                  ),
                ),
                icon: const Icon(Icons.quiz_outlined),
                label: const Text('Uredite FAQ i O nama'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Pretražite klijenta, email ili uslugu',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...['Sve', 'Pending', 'Confirmed', 'Cancelled', 'Completed'].map(
                (status) => ChoiceChip(
                  label: Text(
                    status == 'Sve' ? 'Svi statusi' : statusLabel(status),
                  ),
                  selected: _statusFilter == status,
                  onSelected: (_) => setState(() => _statusFilter = status),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _chooseDateFilter,
                icon: const Icon(Icons.event_outlined),
                label: Text(
                  _dateFilter == null
                      ? 'Svi datumi'
                      : formatDateTime(_dateFilter!).split('  ').first,
                ),
              ),
              if (_dateFilter != null)
                TextButton(
                  onPressed: () => setState(() => _dateFilter = null),
                  child: const Text('Uklonite datum'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          key: ValueKey(_reservationRevision),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: FilledButton(
                    onPressed: _reload,
                    child: const Text('Pokušajte ponovo'),
                  ),
                )
              : visible.isEmpty
              ? const Center(
                  child: Text('Nema rezervacija prema odabranim kriterijima.'),
                )
              : MediaQuery.sizeOf(context).width >= 1100
              ? _table(visible)
              : RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = visible[index];
                      final next = _nextStatuses(item.status);
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.serviceName,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Chip(
                                    backgroundColor: statusColor(
                                      item.status,
                                    ).withValues(alpha: .12),
                                    label: Text(reservationStatusLabel(item)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('${item.clientName} · ${item.clientEmail}'),
                              const SizedBox(height: 4),
                              Text(formatDateTime(item.startAtUtc)),
                              const SizedBox(height: 8),
                              _PaymentStatusBadge(item: item),
                              if (item.cancellationReason != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    'Razlog otkazivanja: ${item.cancellationReason!}',
                                  ),
                                ),
                              const SizedBox(height: 6),
                              Wrap(
                                alignment: WrapAlignment.end,
                                spacing: 4,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _showClientHistory(item),
                                    icon: const Icon(
                                      Icons.person_search_outlined,
                                    ),
                                    label: const Text('Historija klijenta'),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => _showAudit(item),
                                    icon: const Icon(Icons.history),
                                    label: const Text('Historija termina'),
                                  ),
                                  if (next.isNotEmpty)
                                    PopupMenuButton<String>(
                                      onSelected: (status) =>
                                          _changeStatus(item, status),
                                      itemBuilder: (context) => next
                                          .map(
                                            (status) => PopupMenuItem(
                                              value: status,
                                              enabled:
                                                  status.split('|').first !=
                                                      'Completed' ||
                                                  !item.endAtUtc.isAfter(
                                                    DateTime.now(),
                                                  ),
                                              child: Text(statusLabel(status)),
                                            ),
                                          )
                                          .toList(),
                                      child: const Padding(
                                        padding: EdgeInsets.all(8),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text('Promijenite status'),
                                            Icon(Icons.arrow_drop_down),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _PaymentStatusBadge extends StatelessWidget {
  const _PaymentStatusBadge({required this.item, this.compact = false});
  final StaffReservationRecord item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final details = item.paymentMethod == 'OnSite'
        ? switch (item.status) {
            'Completed' => (
              Icons.storefront_outlined,
              Colors.green.shade700,
              'Plaćeno na mjestu',
            ),
            'Cancelled' => (
              Icons.money_off_csred_outlined,
              Colors.red.shade700,
              'Plaćanje na mjestu otkazano',
            ),
            _ => (
              Icons.storefront_outlined,
              Colors.orange.shade800,
              'Plaćanje na mjestu',
            ),
          }
        : switch (item.paymentStatus) {
            'Paid' => (
              Icons.credit_card_outlined,
              Colors.green.shade700,
              'Plaćeno karticom',
            ),
            'Pending' => (
              Icons.hourglass_top_outlined,
              Colors.orange.shade800,
              'Kartično plaćanje na čekanju',
            ),
            'Refunded' => (
              Icons.currency_exchange,
              Colors.blue.shade700,
              'Sredstva vraćena',
            ),
            'RefundPending' => (
              Icons.hourglass_top,
              Colors.orange.shade800,
              'Povrat sredstava u toku',
            ),
            'PartiallyRefunded' => (
              Icons.currency_exchange,
              Colors.orange.shade800,
              'Djelimičan povrat',
            ),
            'Failed' => (
              Icons.cancel_outlined,
              Colors.red.shade700,
              'Kartično plaćanje nije uspjelo',
            ),
            'Expired' => (
              Icons.timer_off_outlined,
              Colors.red.shade700,
              'Kartično plaćanje je isteklo',
            ),
            _ => (
              Icons.money_off_csred_outlined,
              Colors.red.shade700,
              'Kartično nije plaćeno',
            ),
          };
    final amount = item.paymentAmount == null
        ? ''
        : ' · ${item.paymentAmount!.toStringAsFixed(2)} ${(item.paymentCurrency ?? 'bam').toUpperCase()}';
    return Tooltip(
      message: 'Status plaćanja rezervacije: ${details.$3}$amount',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: details.$2.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(details.$1, color: details.$2, size: 18),
            const SizedBox(width: 6),
            Text(
              '${details.$3}$amount',
              style: TextStyle(
                color: details.$2,
                fontWeight: FontWeight.w700,
                fontSize: compact ? 12 : 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
    required this.token,
    required this.onNotificationsChanged,
    this.isStaff = false,
  });
  final String token;
  final Future<void> Function() onNotificationsChanged;
  final bool isStaff;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late Future<List<AppNotification>> _notifications;
  Timer? _refreshTimer;
  Timer? _searchTimer;
  String _search = '';
  bool _onlyUnread = false;
  bool _opening = false;
  bool _markingAll = false;
  @override
  void initState() {
    super.initState();
    _notifications = BeautyStudioApi.notifications(widget.token);
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _reload(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchTimer?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    if (!mounted) return;
    setState(() {
      _notifications = BeautyStudioApi.notifications(
        widget.token,
        search: _search,
        unreadOnly: _onlyUnread,
      );
    });
    await widget.onNotificationsChanged();
  }

  Future<void> _openNotification(AppNotification notification) async {
    if (_opening) return;
    _opening = true;
    final dialog = showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(notification.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(notification.message),
              const SizedBox(height: 16),
              Text(formatDateTime(notification.createdAtUtc)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Zatvori'),
          ),
        ],
      ),
    );
    try {
      await dialog;
    } finally {
      _opening = false;
    }
    if (!mounted || notification.isRead) return;
    try {
      await BeautyStudioApi.markNotificationRead(widget.token, notification.id);
      await _reload();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _markAllRead() async {
    if (_markingAll) return;
    setState(() => _markingAll = true);
    try {
      await BeautyStudioApi.markAllNotificationsRead(widget.token);
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sve obavijesti su označene kao pročitane.'),
          ),
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: EdgeInsets.fromLTRB(20, 24, 20, 4),
        child: Wrap(
          spacing: 20,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'Obavijesti',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
            ),
            FilledButton.tonalIcon(
              onPressed: _markingAll ? null : _markAllRead,
              icon: _markingAll
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.done_all),
              label: const Text('Označi sve kao pročitano'),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          widget.isStaff
              ? 'Nove rezervacije, poruke klijenata, otkazivanja i recenzije ostaju sačuvane ovdje.'
              : 'Promjene vaših rezervacija ostaju sačuvane ovdje.',
          style: const TextStyle(color: Color(0xff777777)),
        ),
      ),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: (v) {
                  _search = v;
                  _searchTimer?.cancel();
                  _searchTimer = Timer(
                    const Duration(milliseconds: 300),
                    _reload,
                  );
                },
                decoration: const InputDecoration(
                  labelText: 'Pretražite obavijesti',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilterChip(
              label: const Text('Nepročitane'),
              selected: _onlyUnread,
              onSelected: (v) {
                _onlyUnread = v;
                _reload();
              },
            ),
          ],
        ),
      ),
      Expanded(
        child: FutureBuilder<List<AppNotification>>(
          future: _notifications,
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
            if (snapshot.data!.isEmpty) {
              return const Center(child: Text('Nemate obavijesti.'));
            }
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                itemCount: snapshot.data!.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = snapshot.data![index];
                  return Card(
                    child: ListTile(
                      onTap: () => _openNotification(item),
                      leading: Icon(
                        item.isRead
                            ? Icons.notifications_none
                            : Icons.notifications,
                        color: _pink,
                      ),
                      title: Text(
                        item.title,
                        style: TextStyle(
                          fontWeight: item.isRead
                              ? FontWeight.w500
                              : FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        '${item.message}\n${formatDateTime(item.createdAtUtc)}',
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    ],
  );
}

class _BenefitsRow extends StatelessWidget {
  const _BenefitsRow();
  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.star_outline, 'Vrhunska\nkvaliteta'),
      (Icons.schedule_outlined, 'Fleksibilno\nradno vrijeme'),
      (Icons.location_on_outlined, 'Odlična\nlokacija'),
    ];
    return Row(
      children: items
          .map(
            (item) => Expanded(
              child: Column(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0x1ae91e63),
                    child: Icon(item.$1, color: _pink),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.$2,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

String formatDateTime(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}.  ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
Color statusColor(String value) => switch (value) {
  'Confirmed' => Colors.green,
  'Cancelled' => Colors.red,
  'Completed' => Colors.indigo,
  _ => Colors.orange,
};
String statusLabel(String status) {
  if (status.contains('|')) {
    final id = int.tryParse(status.split('|').last);
    for (final item in BeautyStudioApi.statusDefinitions) {
      if (item.id == id) return item.name;
    }
  }
  return BeautyStudioApi.statusLabels[status.split('|').first] ?? status;
}

String reservationStatusLabel(ReservationRecord item) =>
    item.statusDisplayName.isNotEmpty
    ? item.statusDisplayName
    : statusLabel(item.status);

Future<String?> reservationReasonDialog(
  BuildContext context,
  String title,
  String label,
  String action,
) async {
  final controller = TextEditingController();
  try {
    final accepted = await showCompletedDialog<bool>(
      context: context,
      builder: (_) => FormDialog(
        title: title,
        saveLabel: action,
        content: TextFormField(
          controller: controller,
          maxLines: 3,
          validator: (value) => Validators.requiredText(value, max: 500),
          decoration: InputDecoration(labelText: label),
        ),
      ),
    );
    return accepted == true ? controller.text.trim() : null;
  } finally {
    controller.dispose();
  }
}
