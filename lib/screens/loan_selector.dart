import 'package:flutter/material.dart';
import 'loans.dart';
import '../services/drift_service.dart';

class LoanSelectorScreen extends StatefulWidget {
  const LoanSelectorScreen({super.key});

  @override
  State<LoanSelectorScreen> createState() => _LoanSelectorScreenState();
}

class _LoanSelectorScreenState extends State<LoanSelectorScreen> {
  int? loadingIndex;

  final items = const [
    _LoanOption(
      title: "Members",
      icon: Icons.people,
      isMember: true,
    ),
    _LoanOption(
      title: "Non-Members",
      icon: Icons.person_outline,
      isMember: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Loan Type"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        children: [
          const SizedBox(height: 20),

          const Text(
            "Choose a category",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 25),

          for (int i = 0; i < items.length; i++)
            _buildButton(context, items[i], i),
        ],
      ),
    );
  }

  Widget _buildButton(BuildContext context, _LoanOption item, int index) {
    final isLoading = loadingIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: RepaintBoundary(
        child: SizedBox(
          width: double.infinity,
          height: 65,
          child: ElevatedButton.icon(
            icon: isLoading
                ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            )
                : Icon(item.icon, size: 26),

            label: Text(
              item.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest,
              foregroundColor: Theme.of(context).colorScheme.primary,
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),

            onPressed: isLoading
                ? null
                : () async {
              setState(() => loadingIndex = index);

              await Navigator.push(
                context,
                PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 250),
                  pageBuilder: (_, __, ___) =>
                      LoansScreen(isMember: item.isMember),
                  transitionsBuilder: (_, animation, __, child) {
                    return FadeTransition(
                      opacity: animation,
                      child: child,
                    );
                  },
                ),
              );

              if (mounted) {
                setState(() => loadingIndex = null);
              }
            },
          ),
        ),
      ),
    );
  }
}

/// 🔥 CLEAN MODEL (KEEP THIS ✔)
class _LoanOption {
  final String title;
  final IconData icon;
  final bool isMember;

  const _LoanOption({
    required this.title,
    required this.icon,
    required this.isMember,
  });
}