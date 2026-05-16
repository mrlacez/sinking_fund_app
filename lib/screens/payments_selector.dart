import 'package:flutter/material.dart';
import 'payments.dart';
import 'package:flutter/services.dart';
import '../services/drift_service.dart';

class PaymentsSelectorScreen extends StatefulWidget {
  const PaymentsSelectorScreen({super.key});

  @override
  State<PaymentsSelectorScreen> createState() =>
      _PaymentsSelectorScreenState();
}

class _PaymentsSelectorScreenState
    extends State<PaymentsSelectorScreen> {
  int? loadingIndex;

  final items = const [
    _PaymentOption(
      title: "Members",
      icon: Icons.people,
      color: Colors.blue,
      isMember: true,
    ),
    _PaymentOption(
      title: "Non-Members",
      icon: Icons.person_off,
      color: Colors.red,
      isMember: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Payment Type"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          itemCount: items.length,
          gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1,
          ),
          itemBuilder: (_, i) =>
              _buildCard(context, items[i], i),
        ),
      ),
    );
  }

  Widget _buildCard(
      BuildContext context, _PaymentOption item, int index) {
    final isLoading = loadingIndex == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        splashColor: item.color.withOpacity(0.2),
        highlightColor: item.color.withOpacity(0.05),
        onTap: loadingIndex != null
            ? null
            : () async {

          HapticFeedback.selectionClick();
          setState(() => loadingIndex = index);

          await Navigator.push(
            context,
            PageRouteBuilder(
              transitionDuration:
              const Duration(milliseconds: 250),
              pageBuilder: (_, __, ___) =>
                  PaymentsScreen(isMember: item.isMember),
              transitionsBuilder:
                  (_, animation, __, child) {
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
        child: Card(
          elevation: 1,
          clipBehavior: Clip.antiAlias,
          color: item.color.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                isLoading
                    ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: item.color,
                  ),
                )
                    : Icon(
                  item.icon,
                  size: 46,
                  color: item.color,
                ),
                const SizedBox(height: 10),
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 🔥 CLEAN MODEL
class _PaymentOption {
  final String title;
  final IconData icon;
  final Color color;
  final bool isMember;

  const _PaymentOption({
    required this.title,
    required this.icon,
    required this.color,
    required this.isMember,
  });
}