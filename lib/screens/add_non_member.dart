import 'package:flutter/material.dart';
import '../services/drift_service.dart';

class AddNonMemberScreen extends StatefulWidget {
  final int? nonMemberId;
  final String? initialName;

  const AddNonMemberScreen({
    super.key,
    this.nonMemberId,
    this.initialName,
  });

  @override
  State<AddNonMemberScreen> createState() => _AddNonMemberScreenState();
}

class _AddNonMemberScreenState extends State<AddNonMemberScreen> {
  bool isDuplicate = false;
  bool isSaving = false;
  bool isEmpty = false;

  final nameController = TextEditingController();

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

  Future<void> _save() async {
    if (isSaving) return;

    final name = nameController.text.trim();

    setState(() {
      isEmpty = name.isEmpty;
    });

    if (name.isEmpty) {
      showTopAlert(context, "⚠️ Name is required");
      return;
    }

    setState(() => isSaving = true);

    try {
      final dup = await DriftService.nonMemberExists(
        name,
        excludeId: widget.nonMemberId,
      );

      if (dup) {
        showTopAlert(context, "⚠️ Name already exists");
        return;
      }

      FocusScope.of(context).unfocus();

      await DriftService.saveNonMember(
        id: widget.nonMemberId,
        name: name,
      );

      if (!mounted) return;

      Navigator.pop(context, true); // ✅ important

    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.nonMemberId == null
              ? "Add Non-Member"
              : "Edit Non-Member",
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                labelText: "Name",
                errorText: isDuplicate
                    ? "Already exists"
                    : isEmpty
                    ? "Required"
                    : null,
              ),
              onChanged: (value) async {
                final text = value.trim();

                setState(() {
                  isEmpty = text.isEmpty;
                });

                if (text.isEmpty) {
                  setState(() => isDuplicate = false);
                  return;
                }

                final dup = await DriftService.nonMemberExists(
                  text,
                  excludeId: widget.nonMemberId,
                );

                if (mounted && text == nameController.text.trim()) {
                  setState(() => isDuplicate = dup);
                }
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (isSaving || isDuplicate || isEmpty) ? null : _save,
                child: isSaving
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : Text(widget.nonMemberId == null ? "Save" : "Update"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void showTopAlert(BuildContext context, String message,
      {Color color = Colors.red}) {
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
                  color == Colors.green
                      ? Icons.check_circle
                      : Icons.error,
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