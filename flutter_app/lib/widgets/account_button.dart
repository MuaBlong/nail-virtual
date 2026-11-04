import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../screens/auth_screen.dart';

class AccountButton extends StatefulWidget {
  final AuthService? auth;
  const AccountButton({super.key, this.auth});
  @override
  State<AccountButton> createState() => _AccountButtonState();
}

class _AccountButtonState extends State<AccountButton> {
  AuthService get auth => widget.auth ?? AuthService.instance;
  bool leaving = false;
  @override
  void initState() {
    super.initState();
    auth.restore();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: auth,
    builder: (context, _) {
      final user = auth.user;
      if (user == null) {
        return TextButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AuthScreen(auth: auth)),
          ),
          icon: const Icon(Icons.person_outline),
          label: const Text('Đăng nhập'),
        );
      }
      return PopupMenuButton<String>(
        tooltip: 'Tài khoản: ${user.fullName}',
        enabled: !leaving,
        onSelected: (_) async {
          setState(() => leaving = true);
          try {
            await auth.logout();
          } on AuthException catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(e.message)));
            }
          } finally {
            if (mounted) setState(() => leaving = false);
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            enabled: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.fullName),
                Text(user.email, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          const PopupMenuItem(value: 'logout', child: Text('Đăng xuất')),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_circle_outlined),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 100),
                child: Text(
                  user.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
