import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/drift_service.dart';
import '../db/drift_db.dart';


class AddPaymentScreen extends StatefulWidget {
  final bool isMember;
  final Map<String, dynamic> loan;

  const AddPaymentScreen({
    super.key,
    required this.isMember,
    required this.loan,
  });

  @override
  State<AddPaymentScreen> createState() => _AddPaymentScreenState();
}

class _AddPaymentScreenState extends State<AddPaymentScreen> {

  List<Map<String, dynamic>> payments = [];
  double totalPaid = 0;
  String name = "Loading...";

  DateTime? selectedDate;
  bool isSaving = false;

  final amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final p = await DriftService.getPaymentsWithRunning(
      loanId: widget.loan['id'],
    );

    final total = await DriftService.getTotalPaid(widget.loan['id']);

    final personName = await DriftService.getOwnerName(
      ownerId: widget.loan['owner_id'],
      ownerType: widget.loan['owner_type'],
    );

    if (!mounted) return;

    setState(() {
      payments = p;
      totalPaid = total;
      name = personName;
    });
  }

  Future<void> savePayment() async {
    final amount = double.tryParse(amountController.text);

    if (amount == null || amount <= 0) {
      showSnack("Enter valid amount");
      return;
    }

    final remaining = (widget.loan['total_amount'] as num).toDouble() - totalPaid;

    if (remaining <= 0) {
      showSnack("Loan already fully paid");
      return;
    }

    if (amount > remaining) {
      showSnack("Amount exceeds remaining balance");
      return;
    }

    if (isSaving) return;

    setState(() => isSaving = true);

    try {
      await DriftService.addPayment(
        amount: amount,
        loanId: widget.loan['id'],
        ownerId: widget.loan['owner_id'],
        ownerType: widget.loan['owner_type'],
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  void showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final remaining = (widget.loan['total_amount'] as num).toDouble() - totalPaid;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isMember
            ? "Add Member Payment"
            : "Add Non-Member Payment"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            ListTile(
              title: const Text("Name"),
              subtitle: Text(name),
            ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Total Loan: ₱${(widget.loan['total_amount'] as num).toDouble().toStringAsFixed(2)}"),
                Text("Paid: ₱${totalPaid.toStringAsFixed(2)}"),
                Text(
                  "Remaining: ₱${remaining.toStringAsFixed(2)}",
                  style: TextStyle(
                    color: remaining <= 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(labelText: "Amount"),
            ),

            const SizedBox(height: 10),


            const SizedBox(height: 10),

            Expanded(
              child: ListView.builder(
                itemCount: payments.length,
                itemBuilder: (_, i) {
                  final p = payments[i];

                  final cumulative = (p['cumulative_paid'] as num).toDouble();
                  final remain = (widget.loan['total_amount'] as num).toDouble() - cumulative;

                  return ListTile(
                    title: Text("₱${p['amount']}"),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p['date'].toString()),
                        if (p['note'] != null) Text("Note: ${p['note']}"),
                        Text(
                          "Remaining: ₱${remain.toStringAsFixed(2)}",
                          style: TextStyle(
                            color: remain <= 0 ? Colors.green : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSaving ? null : savePayment,
                child: isSaving
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text("Save Payment"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
  }
}