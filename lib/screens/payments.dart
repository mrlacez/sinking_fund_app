import 'package:flutter/material.dart';
import '../services/drift_service.dart';
import 'add_payment.dart';

class PaymentsScreen extends StatefulWidget {
  final bool isMember;
  const PaymentsScreen({super.key, required this.isMember});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  List<Map<String, dynamic>> items = [];

  int? lastId;
  bool hasMore = true;
  bool isLoading = false;
  bool isInitialLoading = true;

  double total = 0;

  @override
  void initState() {
    super.initState();
    initLoad();
  }

  Future<void> initLoad() async {
    await Future.wait([
      loadMore(),
      loadTotal(),
    ]);

    if (mounted) {
      setState(() => isInitialLoading = false);
    }
  }

  Future<void> loadMore() async {
    if (!hasMore || isLoading) return;

    setState(() => isLoading = true);

    final data = await DriftService.getPayments(
      isMember: widget.isMember,
      limit: 50,
      lastId: lastId,
    );

    if (data.isEmpty) hasMore = false;

    if (data.isNotEmpty) {
      lastId = data.last['id'] as int;
    }

    if (!mounted) return;

    setState(() {
      items.addAll(data);
      isLoading = false;
    });
  }

  Future<void> loadTotal() async {
    final count = await DriftService.countPayments(widget.isMember);
    final t = count.toDouble();

    if (!mounted) return;

    setState(() => total = t);
  }

  Future<void> refresh() async {
    setState(() {
      items.clear();
      lastId = null;
      hasMore = true;
      isInitialLoading = true;
    });

    await Future.wait([
      loadMore(),
      loadTotal(),
    ]);

    if (mounted) {
      setState(() => isInitialLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isMember ? "Member Payments" : "Non-Member Payments",
        ),
      ),
      body: Column(
        children: [
          _summary(),

          Expanded(
            child: isInitialLoading
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                ? const Center(child: Text("No payments yet"))
                : NotificationListener<ScrollNotification>(
              onNotification: (scroll) {
                if (!isLoading &&
                    scroll.metrics.pixels >=
                        scroll.metrics.maxScrollExtent - 200) {
                  loadMore();
                }
                return false;
              },
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: items.length + (hasMore ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i >= items.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final item = items[i];

                  final amount =
                      (item['amount'] as num?)?.toDouble() ?? 0;

                  final rawName =
                      (item['name'] as String?) ?? "";
                  final name =
                  rawName.isNotEmpty ? rawName : "Unknown";

                  final dateStr = item['date']?.toString();
                  final date = dateStr != null
                      ? DateTime.tryParse(dateStr) ??
                      DateTime.now()
                      : DateTime.now();

                  final loan =
                      (item['total_amount'] as num?)?.toDouble() ?? 0;

                  return Card(
                    elevation: 1,
                    margin: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      title: Text(
                        "₱${amount.toStringAsFixed(0)}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500)),
                          Text(
                              "${date.day}/${date.month}/${date.year}"),
                          Text(
                              "Loan: ₱${loan.toStringAsFixed(0)}"),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _openLoanSelector,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _summary() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Total Payments",
              style: TextStyle(color: Colors.white70)),
          Text(
            "₱${total.toStringAsFixed(0)}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openLoanSelector() async {
    final loans = await DriftService.getLoans(
      isMember: widget.isMember,
      limit: 100,
      lastId: null,
    );

    if (!mounted) return;

    if (loans.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No loans available")),
      );
      return;
    }

    showModalBottomSheet(

      context: context,

      isScrollControlled: true,

      backgroundColor: Colors.transparent,

      builder: (_) {

        return Container(

          height: MediaQuery.of(context).size.height * 0.75,

          decoration: const BoxDecoration(
            color: Colors.white,

            borderRadius: BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),

          child: Column(

            children: [

              const SizedBox(height: 12),

              Container(
                width: 50,
                height: 5,

                decoration: BoxDecoration(
                  color: Colors.grey.shade300,

                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              const SizedBox(height: 16),

              Text(
                widget.isMember
                    ? "Select Member Loan"
                    : "Select Non-Member Loan",

                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              Expanded(

                child: ListView.builder(

                  itemCount: loans.length,

                  itemBuilder: (_, i) {

                    final loan = loans[i];

                    final rawName =
                        (loan['name'] as String?) ?? "";

                    final name =
                    rawName.isNotEmpty
                        ? rawName
                        : "Unknown";

                    final total =
                        (loan['total_amount'] as num?)
                            ?.toDouble() ?? 0;

                    final paid =
                        (loan['paid'] as num?)
                            ?.toDouble() ?? 0;

                    final remaining =
                        (loan['remaining'] as num?)
                            ?.toDouble() ?? total;

                    final fullyPaid =
                        remaining <= 0;

                    return Card(

                      margin: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),

                      child: ListTile(

                        enabled: !fullyPaid,

                        leading: CircleAvatar(

                          backgroundColor:
                          widget.isMember
                              ? Colors.blue.shade100
                              : Colors.red.shade100,

                          child: Icon(
                            widget.isMember
                                ? Icons.people
                                : Icons.person_outline,

                            color:
                            widget.isMember
                                ? Colors.blue
                                : Colors.red,
                          ),
                        ),

                        title: Text(
                          name,

                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        subtitle: Column(

                          crossAxisAlignment:
                          CrossAxisAlignment.start,

                          children: [

                            Text(
                              "Loan: ₱${total.toStringAsFixed(0)}",
                            ),

                            Text(
                              "Paid: ₱${paid.toStringAsFixed(0)}",
                            ),

                            Text(

                              fullyPaid
                                  ? "Fully Paid"
                                  : "Remaining: ₱${remaining.toStringAsFixed(0)}",

                              style: TextStyle(

                                color:
                                fullyPaid
                                    ? Colors.green
                                    : Colors.orange,

                                fontWeight:
                                FontWeight.w600,
                              ),
                            ),
                          ],
                        ),

                        trailing: const Icon(
                          Icons.chevron_right,
                        ),

                        onTap: fullyPaid
                            ? null
                            : () {

                          Navigator.pop(context);

                          Navigator.push(
                            context,

                            MaterialPageRoute(
                              builder: (_) => AddPaymentScreen(
                                isMember: widget.isMember,
                                loan: loan,
                              ),
                            ),
                          ).then((_) => refresh());
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}