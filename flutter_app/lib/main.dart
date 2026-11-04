import 'package:flutter/material.dart';
import 'screens/home.dart';
import 'screens/auth_screen.dart';
import 'services/auth_service.dart';

void main() {
  runApp(const NailApp());
}

class NailApp extends StatelessWidget {
  final AuthService? auth;
  const NailApp({super.key, this.auth});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Nail Virtual',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink),
        useMaterial3: true,
      ),
      home: AccountGate(auth: auth ?? AuthService.instance),
    );
  }
}

class AccountGate extends StatefulWidget {
  final AuthService auth;
  const AccountGate({super.key, required this.auth});

  @override
  State<AccountGate> createState() => _AccountGateState();
}

class _AccountGateState extends State<AccountGate> {
  late final Future<void> restoration = widget.auth.restore();

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: restoration,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return AnimatedBuilder(
        animation: widget.auth,
        builder: (context, _) => Navigator(
          // Recreate the entire application stack when the account changes.
          key: ValueKey(widget.auth.user?.id),
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => widget.auth.user == null
                ? AuthScreen(auth: widget.auth, requiredLogin: true)
                : HomeScreen(auth: widget.auth),
          ),
        ),
      );
    },
  );
}
