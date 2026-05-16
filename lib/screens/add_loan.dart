import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/drift_service.dart';
import 'package:intl/intl.dart';

class AddLoanScreen extends StatefulWidget {
  final bool isMember;
  const AddLoanScreen({super.key, required this.isMember});

  @override
  State<AddLoanScreen> createState() => _AddLoanScreenState();
}

class _AddLoanScreenState extends State<AddLoanScreen> {

  Widget buildDropdown() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: widget.isMember
          ? DriftService.getMembersList()
          : DriftService.getNonMembersList(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data as List<Map<String, dynamic>>;

        if (data.isEmpty) {
          return const Text("No users available");
        }

        return DropdownButtonFormField<int>(
          hint: Text(widget.isMember ? "Select Member" : "Select Non-Member"),
          items: data.map((e) {
            return DropdownMenuItem<int>(
              value: e['id'] as int,
              child: Text(e['name'].toString()),
            );
          }).toList(),
          onChanged: (v) {

            if (!mounted) return;

            setState(() {
              if (widget.isMember) {
                selectedMemberId = v;
              } else {
                selectedNonMemberId = v;
              }
            });
          },
        );
      },
    );
  }


  bool isSaving = false;
  final amountCtrl = TextEditingController();

  DateTime? dueDate;



  int? selectedMemberId;
  int? selectedNonMemberId;

  @override
  void initState() {
    super.initState();

  }

  @override
  void dispose() {
    amountCtrl.dispose();
    super.dispose();
  }



  Future<void> saveLoan() async {
    if (isSaving) return;

    setState(() => isSaving = true);

    try {

      FocusScope.of(context).unfocus();

      final amount = double.tryParse(amountCtrl.text);
      if (amount == null || amount <= 0) {

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Enter valid amount")),
        );
        return;
      }

      if (dueDate == null) {

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Select due date")),
        );
        return;
      }

      final ownerId = widget.isMember
          ? selectedMemberId
          : selectedNonMemberId;

      if (ownerId == null) {

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Select a user")),
        );
        return;
      }

      final id = await DriftService.addLoan(
        amount: amount,
        ownerId: ownerId,
        ownerType: widget.isMember ? "member" : "non_member",
        dueDate: dueDate!,
      );

      if (!mounted) return;

      FocusScope.of(context).unfocus();

      Navigator.pop(context, id);
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Loan")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              buildDropdown(),

              const SizedBox(height: 16),

              TextField(
                controller: amountCtrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'^\d*\.?\d{0,2}'),
                  ),
                ],
                decoration: const InputDecoration(labelText: "Amount"),
              ),

              const SizedBox(height: 16),

              ListTile(
                title: const Text("Due Date"),
                subtitle: Text(
                  dueDate == null
                      ? "Select date"
                      : DateFormat.yMMMd().format(dueDate!),
                ),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                    initialDate: DateTime.now(),
                  );
                  if (d != null && mounted) {
                    setState(() => dueDate = d);
                  }
                },
              ),

              const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () {

                  final amount =
                  double.tryParse(amountCtrl.text);

                  final ownerId = widget.isMember
                      ? selectedMemberId
                      : selectedNonMemberId;

                  if (amount == null ||
                      amount <= 0 ||
                      dueDate == null ||
                      ownerId == null) {
                    return;
                  }

                  saveLoan();
                },
                child: isSaving
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Text("Save Loan"),
              ),
          ),
            ],
          ),
        ),
      ),
    );
  }
}