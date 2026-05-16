import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/drift_service.dart';
import 'add_loan.dart';

class LoansScreen extends StatefulWidget {
  final bool isMember;
  const LoansScreen({super.key, required this.isMember});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  List<Map<String, dynamic>> items = [];

  int? lastId;
  bool hasMore = true;
  bool isLoading = false;
  bool isInitialLoading = true;

  int total = 0;
  int count = 0;
  int overdue = 0;

  @override
  void initState() {
    super.initState();
    initLoad();
  }

  Future<void> initLoad() async {
    await Future.wait([
      loadMore(),
      loadStats(),
    ]);

    if (mounted) {
      setState(() => isInitialLoading = false);
    }
  }

  Future<void> loadMore() async {
    if (!hasMore || isLoading) return;

    if (mounted) {
      setState(() => isLoading = true);
    }

    try {

      final data = await DriftService.getLoans(
        isMember: widget.isMember,
        limit: 50,
        lastId: lastId,
      );

      if (data.isEmpty || data.length < 50) {
        hasMore = false;
      }

      if (data.isNotEmpty) {
        lastId = data.last['id'] as int;
      }

      if (!mounted) return;

      setState(() {
        items.addAll(data);
        isLoading = false;
      });

    } catch (e) {

      debugPrint("loadMore loans error: $e");

      if (mounted) {
        setState(() => isLoading = false);
      }
    }

  }

  Future<void> loadStats() async {
    final res = await DriftService.loanStats(widget.isMember);

    if (!mounted) return;

    setState(() {
      total = (res['total'] as num?)?.toInt() ?? 0;
      count = (res['count'] as num?)?.toInt() ?? 0;
      overdue = (res['overdue'] as num?)?.toInt() ?? 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        title: Text(
          widget.isMember
              ? "Member Loans"
              : "Non-Member Loans",
        ),
      ),

      floatingActionButton: FloatingActionButton(
        mini: true,

        child: const Icon(Icons.add),

        onPressed: () async {

          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddLoanScreen(
                isMember: widget.isMember,
              ),
            ),
          );

          if (result != null && mounted) {

            setState(() {
              items.clear();
              lastId = null;
              hasMore = true;
              isInitialLoading = true;
            });

            await initLoad();
          }
        },
      ),
      body: Column(
        children: [
          _summary(),

          Expanded(
            child: isInitialLoading
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                ? const Center(child: Text("No loans yet"))
                : NotificationListener<ScrollNotification>(
              onNotification: (scroll) {
                if (!isLoading &&
                    scroll.metrics.pixels >=
                        scroll.metrics.maxScrollExtent - 200) {
                  if (mounted) {
                    loadMore();
                  }
                }
                return false;
              },
              child: RefreshIndicator(
                onRefresh: () async {

                  setState(() {
                    items.clear();
                    lastId = null;
                    hasMore = true;
                    isInitialLoading = true;
                  });

                  await initLoad();
                },

                child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: items.length + (hasMore ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i >= items.length) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    );
                  }

                  final item = items[i];

                  final totalAmount =
                      (item['total_amount'] as num?)?.toDouble() ?? 0;

                  final paid =
                      (item['paid'] as num?)?.toDouble() ?? 0;

                  final remaining =
                  (totalAmount - paid).clamp(0, double.infinity);

                  final isOverdue = item['is_overdue'] == 1;

                  return ListTile(
                    isThreeLine: true,

                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    leading: CircleAvatar(
                      backgroundColor:
                      isOverdue
                          ? Colors.red.shade100
                          : Colors.green.shade100,

                      child: Icon(
                        Icons.account_balance_wallet,
                        color:
                        isOverdue
                            ? Colors.red
                            : Colors.green,
                      ),
                    ),
                    title: Text(item['name'] ?? "Unknown"),
                    subtitle: Text(
                      isOverdue ? "⚠️ Overdue" : "Active",
                      style: TextStyle(
                        color: isOverdue ? Colors.red : Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("₱${totalAmount.toStringAsFixed(0)}"),
                        Text(
                          "Remaining: ₱${remaining.toStringAsFixed(0)}",
                          style: TextStyle(
                            fontSize: 12,
                            color: remaining <= 0
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _card("Total", "₱$total", Colors.green),
          _card("Loans", "$count", Colors.blue),
          _card("Overdue", "$overdue", Colors.red),
        ],
      ),
    );
  }

  Widget _card(String t, String v, Color c) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(t, style: const TextStyle(color: Colors.white70)),
            Text(
              v,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}