import 'package:flutter/material.dart';
import '../services/drift_service.dart';
import '../main.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final controller = TextEditingController();
  final confirmController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  bool isSaving = false;
  bool obscure = true;

  @override
  void dispose() {
    controller.dispose();
    confirmController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    FocusScope.of(context).unfocus();

    if (isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSaving = true);

    try {
      await DriftService.changePassword(controller.text.trim());

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password set successfully")),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  /// 🔐 STRONG VALIDATION
  String? validatePassword(String? v) {
    if (v == null || v.isEmpty) return "Required";
    if (v.length < 4) return "Min 4 characters";
    if (!RegExp(r'[0-9]').hasMatch(v)) {
      return "Must contain a number";
    }
    if (!RegExp(r'[a-zA-Z]').hasMatch(v)) {
      return "Must contain a letter";
    }
    if (RegExp(r'^(.)\1+$').hasMatch(v)) {
      return "Too weak password";
    }
    return null;
  }

  /// 🔐 SAFE CONFIRM
  String? validateConfirm(String? v) {
    if (v == null || v.isEmpty) return "Required";
    if (v != controller.text) return "Passwords do not match";
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
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
                      "Secure Your App",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 25),

                    /// PASSWORD
                    TextFormField(
                      controller: controller,
                      autofocus: true,
                      obscureText: obscure,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        labelText: "Enter Password",
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
                      validator: validatePassword,
                    ),

                    const SizedBox(height: 12),

                    /// CONFIRM
                    TextFormField(
                      controller: confirmController,
                      obscureText: obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => save(),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        labelText: "Confirm Password",
                      ),
                      validator: validateConfirm,
                    ),

                    const SizedBox(height: 25),

                    /// BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isSaving ? null : save,
                        style: ElevatedButton.styleFrom(
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Text(
                          "Save Password",
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}