import 'package:flutter/material.dart';
import '../services/drift_service.dart';


class AddMemberScreen extends StatefulWidget {
  final int? memberId;
  final String? initialName;

  const AddMemberScreen({
    super.key,
    this.memberId,
    this.initialName,
  });

  @override
  State<AddMemberScreen> createState() => _AddMemberScreenState();
}


class _AddMemberScreenState extends State<AddMemberScreen> {

  bool isDuplicate = false;
  bool isSaving = false;
  final TextEditingController nameController = TextEditingController();

  @override
  void initState() {
    super.initState();

    if (widget.initialName != null) {
      nameController.text = widget.initialName!;
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(widget.memberId == null ? "Add Member" : "Edit Member"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.words,
                onSubmitted: (_) => _save(),
                decoration: InputDecoration(
                  labelText: "Name",
                  errorText: isDuplicate ? "Already exists" : null,
                ),
                onChanged: (value) async {
                  final dup = await DriftService.memberExists(
                    value.trim(),
                    excludeId: widget.memberId,
                  );

                  if (mounted) {
                    setState(() => isDuplicate = dup);
                  }
                },
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (isSaving || isDuplicate) ? null : _save,
                  child: isSaving
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : Text(widget.memberId == null ? "Save" : "Update"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (isSaving) return;

    final name = nameController.text.trim();

    if (name.isEmpty) {
      showTopAlert(context, "⚠️ Name is required");
      return;
    }

    setState(() => isSaving = true);

    try {
      final dup = await DriftService.memberExists(
        name,
        excludeId: widget.memberId, // ✅ FIX duplicate bug
      );

      if (dup) {
        showTopAlert(context, "⚠️ Name already exists");
        return;
      }

      FocusScope.of(context).unfocus();

      await DriftService.saveMember(
        id: widget.memberId,
        name: name,
      );

      if (!mounted) return;

      Navigator.pop(context, true); // ✅ IMPORTANT

    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }






  void showTopAlert(BuildContext context, String message, {Color color = Colors.red}) {
    final overlay = Overlay.of(context, rootOverlay: true);
    if (overlay == null) return;

    final entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 60,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  color == Colors.green ? Icons.check_circle : Icons.error,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);

    Future.delayed(const Duration(seconds: 2), () {
      if (entry.mounted) entry.remove();
    });
  }
}