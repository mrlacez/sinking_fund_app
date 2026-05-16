import 'package:flutter/material.dart';
import '../services/drift_service.dart';
import '../main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLoading = false;
  bool obscure = true;

  int attempts = 0;
  DateTime? lockedUntil;

  late final ValueNotifier<int> lockTimer = ValueNotifier(0);

  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  Future<void> login() async {
    FocusScope.of(context).unfocus();

    if (isLoading) return;

    /// 🔐 LOCK CHECK
    if (lockedUntil != null &&
        DateTime.now().isBefore(lockedUntil!)) {
      final seconds =
          lockedUntil!.difference(DateTime.now()).inSeconds;
      _showSnack("Locked. Try again in $seconds sec");
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final ok = await DriftService.validateAdmin(
        usernameController.text.trim(),
        passwordController.text.trim(),
      );

      if (!mounted) return;

      if (ok) {
        /// ✅ RESET STATE
        setState(() {
          attempts = 0;
          lockedUntil = null;
        });

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const DashboardScreen(),
          ),
        );
      } else {
        setState(() => attempts++);

        /// 🔥 LOCK AFTER 5 ATTEMPTS
        if (attempts >= 5) {
          final until =
          DateTime.now().add(const Duration(seconds: 30));

          setState(() {
            lockedUntil = until;
          });

          lockTimer.value = 30;

          Future.doWhile(() async {
            await Future.delayed(const Duration(seconds: 1));

            final remaining =
                until.difference(DateTime.now()).inSeconds;

            if (remaining <= 0) {
              lockTimer.value = 0;
              return false;
            }

            lockTimer.value = remaining;
            return true;
          });

          _showSnack("Too many attempts. Locked");
        } else {
          _showSnack("Wrong credentials");
        }
      }
    } catch (e) {
      _showSnack("Login error");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    lockTimer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining =
    attempts >= 5 ? 0 : (5 - attempts);

    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  const Icon(Icons.lock, size: 60),
                  const SizedBox(height: 10),

                  const Text(
                    "Admin Login",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 25),

                  /// USERNAME
                  TextFormField(
                    controller: usernameController,
                    textInputAction: TextInputAction.next,
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: "Username",
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                    v == null || v.trim().isEmpty
                        ? "Required"
                        : null,
                  ),

                  const SizedBox(height: 12),

                  /// PASSWORD
                  TextFormField(
                    controller: passwordController,
                    obscureText: obscure,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => login(),
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: "Password",
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () =>
                            setState(() => obscure = !obscure),
                      ),
                    ),
                    validator: (v) =>
                    v == null || v.isEmpty
                        ? "Required"
                        : null,
                  ),

                  const SizedBox(height: 20),

                  /// BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isLoading ||
                          (lockedUntil != null &&
                              DateTime.now().isBefore(lockedUntil!))
                          ? null
                          : login,
                      child: isLoading
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : ValueListenableBuilder<int>(
                        valueListenable: lockTimer,
                        builder: (_, seconds, __) {
                          if (seconds > 0) {
                            return Text("Locked ($seconds s)");
                          }

                          return Text(
                            attempts > 0
                                ? "Login ($remaining tries left)"
                                : "Login",
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}