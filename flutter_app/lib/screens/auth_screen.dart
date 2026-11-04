import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  final AuthService? auth;
  final bool requiredLogin;
  const AuthScreen({super.key, this.auth, this.requiredLogin = false});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController(),
      confirmation = TextEditingController();
  bool register = false, busy = false, obscure = true;
  String? error;
  AuthService get auth => widget.auth ?? AuthService.instance;
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (register) {
        await auth.register(name.text, email.text, password.text);
      } else {
        await auth.login(email.text, password.text);
      }
      TextInput.finishAutofillContext(shouldSave: true);
      if (mounted && !widget.requiredLogin) Navigator.pop(context, true);
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Chưa hoàn tất được. Hãy thử lại.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFFF7FA),
    appBar: AppBar(
      automaticallyImplyLeading: !widget.requiredLogin,
      title: Text(register ? 'Tạo tài khoản' : 'Đăng nhập'),
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: AutofillGroup(
              child: Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 64,
                      color: Colors.pink,
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Đăng nhập')),
                        ButtonSegment(value: true, label: Text('Đăng ký')),
                      ],
                      selected: {register},
                      onSelectionChanged: busy
                          ? null
                          : (values) => setState(() {
                              register = values.first;
                              error = null;
                              form.currentState?.reset();
                            }),
                    ),
                    const SizedBox(height: 24),
                    if (register) ...[
                      TextFormField(
                        controller: name,
                        enabled: !busy,
                        autofillHints: const [AutofillHints.name],
                        decoration: const InputDecoration(
                          labelText: 'Họ và tên',
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                        maxLength: 100,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Hãy nhập họ và tên.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: email,
                      enabled: !busy,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null ||
                              value.trim().length > 150 ||
                              !RegExp(
                                r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                              ).hasMatch(value.trim())
                          ? 'Hãy nhập email hợp lệ.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: password,
                      enabled: !busy,
                      obscureText: obscure,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: [
                        register
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      textInputAction: register
                          ? TextInputAction.next
                          : TextInputAction.done,
                      onFieldSubmitted: register ? null : (_) => submit(),
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu',
                        helperText: register ? 'Từ 8 đến 128 ký tự.' : null,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                          onPressed: busy
                              ? null
                              : () => setState(() => obscure = !obscure),
                          icon: Icon(
                            obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Hãy nhập mật khẩu.'
                          : register &&
                                (value.length < 8 || value.length > 128)
                          ? 'Mật khẩu cần từ 8 đến 128 ký tự.'
                          : null,
                    ),
                    if (register) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: confirmation,
                        enabled: !busy,
                        obscureText: obscure,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => submit(),
                        decoration: const InputDecoration(
                          labelText: 'Xác nhận mật khẩu',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value != password.text
                            ? 'Mật khẩu xác nhận chưa khớp.'
                            : null,
                      ),
                    ],
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: busy ? null : submit,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(register ? 'TẠO TÀI KHOẢN' : 'ĐĂNG NHẬP'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.requiredLogin
                          ? 'Đăng nhập hoặc tạo tài khoản để bắt đầu thử nail.'
                          : 'Đăng nhập để sử dụng tài khoản của bạn.',
                      textAlign: TextAlign.center,
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
