import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/drift_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../db/drift_db.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:drift/drift.dart' as drift;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, dynamic>> trend = [];
  List<Map<String, dynamic>> top = [];

  int total = 0;
  int count = 0;
  double avg = 0;

  @override
  void initState() {
    super.initState();
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    final t = await DriftService.monthlyTrend();
    final topList = await DriftService.topContributors();
    final stats = await DriftService.contributionStats();

    setState(() {
      trend = t;
      top = topList;
      total = (stats['total'] as num?)?.toInt() ?? 0;
      count = (stats['count'] as num?)?.toInt() ?? 0;
      avg = (stats['avg'] as num?)?.toDouble() ?? 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Dashboard")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _summary(),
            const SizedBox(height: 20),
            _chart(),
            const SizedBox(height: 20),
            _topContributors(),
          ],
        ),
      ),
    );
  }

  Widget _summary() {
    return Row(
      children: [
        _card("Total", "₱$total", Colors.green),
        _card("Entries", "$count", Colors.blue),
        _card("Avg", "₱${avg.toStringAsFixed(0)}", Colors.orange),
      ],
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
            Text(v,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _chart() {
    if (trend.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text("No data yet")),
      );
    }

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              isCurved: false,
              spots: List.generate(trend.length, (i) {
                return FlSpot(
                  i.toDouble(),
                  (trend[i]['total'] as num).toDouble(),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topContributors() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("🏆 Top Contributors"),
        ...top.map((e) {
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            title: Text(e['name'] ?? "Unknown"),
            trailing: Text("₱${e['total']}"),
          );
        }).toList(),
      ],
    );
  }
}


class ContributionsScreen extends StatefulWidget {
  const ContributionsScreen({super.key});

  @override
  State<ContributionsScreen> createState() => _ContributionsScreenState();
}

class _ContributionsScreenState extends State<ContributionsScreen> {

  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> items = [];

  int? lastId;

  bool hasMore = true;
  bool isLoading = false;
  bool isInitialLoading = true;

  int total = 0;
  int count = 0;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_onScroll);

    _init();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {

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

    setState(() => isLoading = true);

    try {

      final data = await DriftService.getContributions(
        limit: 15,
        lastId: lastId,
      );

      hasMore = data.length >= 15;

      if (data.isNotEmpty) {
        lastId = data.last['id'] as int;
      }

      if (!mounted) return;

      setState(() {
        items.addAll(data);
        isLoading = false;
      });

    } catch (e) {

      debugPrint("loadMore error: $e");

      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> loadStats() async {

    final res = await DriftService.db.customSelect('''
      SELECT IFNULL(SUM(amount),0) as total,
             COUNT(*) as count
      FROM contributions
    ''').getSingle();

    if (!mounted) return;

    setState(() {
      total = (res.data['total'] as num?)?.toInt() ?? 0;
      count = (res.data['count'] as num?)?.toInt() ?? 0;
    });
  }


  DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime(2000);

    if (value is DateTime) return value;

    try {
      return DateTime.parse(value.toString());
    } catch (e) {
      return DateTime(2000);
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("Contributions"),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _showAddContribution,
        child: const Icon(Icons.add),
      ),

      body: Column(
        children: [

          _summary(),

          Expanded(

            child: isInitialLoading

                ? const Center(
              child: CircularProgressIndicator(),
            )

                : items.isEmpty

                ? const Center(
              child: Text("No contributions yet"),
            )

                : RefreshIndicator(

              onRefresh: () async {

                setState(() {
                  items.clear();
                  lastId = null;
                  hasMore = true;
                  isInitialLoading = true;
                });

                await _init();
              },

              child: ListView.builder(

                physics: const BouncingScrollPhysics(),

                controller: _scrollController,

                padding: const EdgeInsets.only(bottom: 80),

                itemCount: items.length + (hasMore ? 1 : 0),

                itemBuilder: (_, i) {

                  if (i >= items.length) {

                    if (!hasMore) {
                      return const SizedBox.shrink();
                    }

                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    );
                  }

                  final item = items[i];

                  final prev =
                  i == 0
                      ? ""
                      : items[i - 1]['month_key'];

                  final curr = item['month_key'];

                  final date = _parseDate(item['date']);

                  return Column(

                    crossAxisAlignment:
                    CrossAxisAlignment.start,

                    children: [

                      if (curr != null &&
                          curr.isNotEmpty &&
                          curr != prev)

                        Padding(

                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),

                          child: Row(

                            mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,

                            children: [

                              Text(
                                "📅 ${DriftService.formatMonth(curr)}",
                              ),

                              Row(
                                children: [

                                  IconButton(
                                    icon: const Icon(Icons.picture_as_pdf),
                                    onPressed: () {
                                      printMonth(curr);
                                    },
                                  ),

                                  IconButton(
                                    icon: const Icon(Icons.download),
                                    onPressed: () {
                                      _exportMonth(curr);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                      Container(

                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),

                        decoration: BoxDecoration(

                          color: Colors.white,

                          border: Border.all(
                            color: Colors.grey.shade300,
                          ),

                          borderRadius:
                          BorderRadius.circular(10),
                        ),

                        child: ListTile(

                          contentPadding:
                          const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),

                          title: Text(
                            item['name'] ?? "Unknown",
                          ),

                          subtitle: Text(

                            date.year < 2005
                                ? "No date"
                                : DateFormat.yMMMd().format(date),
                          ),

                          trailing: Text(
                            "₱${(item['amount'] as num).toStringAsFixed(2)}",
                          ),

                          onLongPress: () async {

                            HapticFeedback.mediumImpact();

                            final pos = await _getTapPosition(context);

                            if (!mounted) return;

                            await _showOptions(
                              context,
                              pos,
                              item,
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<Offset> _getTapPosition(BuildContext context) async {

    final box =
    context.findRenderObject() as RenderBox;

    return box.localToGlobal(
      Offset(
        box.size.width / 2,
        box.size.height / 2,
      ),
    );
  }


  Widget _summary() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _card("Total", "₱$total", Colors.green),
          _card("Entries", "$count", Colors.blue),
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
            Text(v,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  void _showAddContribution() async {
    final ctrl = TextEditingController();
    final members = await DriftService.getMembersList();

    int? memberId;
    DateTime? selectedDate; // ✅ allow null

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  /// 👤 MEMBER
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: "Member"),
                    items: members.map<DropdownMenuItem<int>>((m) {
                      return DropdownMenuItem<int>(
                        value: m['id'] as int,
                        child: Text(m['name']),
                      );
                    }).toList(),
                    onChanged: (v) => setModalState(() => memberId = v),
                  ),

                  const SizedBox(height: 12),

                  /// 💰 AMOUNT
                  TextField(
                    controller: ctrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Amount",
                    ),
                  ),

                  const SizedBox(height: 12),

                  /// 📅 DATE PICKER
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Select Date"),
                    subtitle: Text(
                      selectedDate == null
                          ? "No date selected"
                          : DateFormat.yMMMd().format(selectedDate!),
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );

                      if (picked != null) {
                        setModalState(() => selectedDate = picked);
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  /// 💾 SAVE
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final amount = double.tryParse(ctrl.text) ?? 0;
                        if (memberId == null || amount <= 0) return;

                        final now = selectedDate ?? DateTime.now();

                        /// 🔥 GET NAME (para display dayon)
                        final members = await DriftService.getMembersList();
                        final selected = members.firstWhere(
                              (m) => m['id'] == memberId,
                          orElse: () => {'name': 'Unknown'},
                        );

                        /// 🔥 INSERT TO DB (async, but we don’t wait UI)
                        await DriftService.db.into(
                          DriftService.db.contributions,
                        ).insert(
                          ContributionsCompanion.insert(
                            amount: amount,
                            date: now,
                            memberId: memberId!,
                          ),
                        );

                        Navigator.pop(context);

                        /// 🔥 INSTANT UI UPDATE (no waiting)
                        setState(() {
                          items.insert(0, {
                            'id': DateTime.now().millisecondsSinceEpoch,
                            'name': selected['name'],
                            'amount': amount,
                            'date': now.toString(),
                            'month_key': DateFormat('yyyy-MM').format(now),
                          });

                          total += amount.toInt();
                          count += 1;
                        });

                        /// 🔥 optional: sync with DB in background
                        await Future.delayed(const Duration(milliseconds: 200));
                        await loadStats();
                      },
                      child: const Text("Save"),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showOptions(
      BuildContext context,
      Offset position,
      Map<String, dynamic> item,
      ) async {

    final overlayState = Overlay.of(context);

    if (overlayState == null) return;

    final overlay = overlayState.context.findRenderObject();

    if (overlay is! RenderBox) return;

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(position, position),
        Offset.zero & overlay.size,
      ),
      items: [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit),
              SizedBox(width: 10),
              Text('Edit'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete),
              SizedBox(width: 10),
              Text('Delete'),
            ],
          ),
        ),
      ],
    );

    if (!mounted) return;

    if (selected == 'edit') {
      _editContribution(item);
    } else if (selected == 'delete') {
      _deleteContribution(item);
    }
  }


  Future<void> _deleteContribution(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Confirm Delete"),
          content: Text(
            "Delete contribution ni ${item['name']} (₱${item['amount']})?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );

    /// ❌ if cancel → stop
    if (confirm != true) return;

    /// ✅ proceed delete
    final id = item['id'];
    final amount = (item['amount'] as num).toInt();

    await DriftService.db.customStatement(
      'DELETE FROM contributions WHERE id = ?',
      [id],
    );

    if (!mounted) return;

    setState(() {
      items.removeWhere((e) => e['id'] == id);
      total -= amount;
      count -= 1;
    });

    /// optional: snackbar feedback
    _showCenterPopup(
      message: "Deleted successfully",
      icon: Icons.check,
    );
  }


  void _editContribution(Map<String, dynamic> item) {
    final ctrl = TextEditingController(text: item['amount'].toString());
    DateTime selectedDate = _parseDate(item['date']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Edit Contribution",
                      style: TextStyle(fontSize: 18)),

                  const SizedBox(height: 12),

                  TextField(
                    controller: ctrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Amount"),
                  ),

                  const SizedBox(height: 12),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Select Date"),
                    subtitle: Text(DateFormat.yMMMd().format(selectedDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );

                      if (picked != null) {
                        setModalState(() => selectedDate = picked);
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  ElevatedButton(
                    onPressed: () async {
                      final newAmount =
                          double.tryParse(ctrl.text) ?? 0;
                      if (newAmount <= 0) return;

                      final oldAmount =
                      (item['amount'] as num).toDouble();

                      await DriftService.db.customStatement('''
UPDATE contributions
SET amount = ?, date = ?
WHERE id = ?
''', [
                        newAmount,
                        selectedDate.toIso8601String(),
                        item['id'],
                      ]);

                      Navigator.pop(context);

                      /// 🔥 SUCCESS MESSAGE
                      _showCenterPopup(
                        message: "Successfully updated",
                        icon: Icons.check,
                      );

                      /// 🔥 UPDATE UI + GROUP FIX
                      setState(() {
                        final index = items.indexWhere(
                                (e) => e['id'] == item['id']);

                        if (index != -1) {
                          items[index]['amount'] = newAmount;
                          items[index]['date'] =
                              selectedDate.toString();
                          items[index]['month_key'] =
                              DateFormat('yyyy-MM')
                                  .format(selectedDate);
                        }

                        total = total - oldAmount.toInt() +
                            newAmount.toInt();
                      });

                      await loadStats();
                    },
                    child: const Text("Save"),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCenterPopup({
    required String message,
    Color color = Colors.black87,
    IconData? icon,
  }) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    message,
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    /// 🔥 auto close
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;

      if (Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    });
  }


  Future<void> _exportMonth(String monthKey) async {
    final data = await DriftService.db.customSelect('''
    SELECT m.name, c.amount, c.date
    FROM contributions c
    LEFT JOIN members m ON m.id = c.member_id
    WHERE strftime('%Y-%m', c.date) = ?
    ORDER BY c.date DESC
  ''', variables: [
      drift.Variable.withString(monthKey)
    ]).get();

    if (data.isEmpty) {
      _showCenterPopup(message: "No data to export");
      return;
    }

    /// 🔥 build CSV
    String csv = "Name,Amount,Date\n";

    for (final row in data) {
      final name = row.data['name'] ?? '';
      final amount = row.data['amount'] ?? 0;
      final date = row.data['date'] ?? '';

      csv += "$name,$amount,$date\n";
    }

    /// 🔥 save file
    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/contributions_$monthKey.csv");

    await file.writeAsString(csv);

    /// 🔥 share file
    await Share.shareXFiles([XFile(file.path)]);

    _showCenterPopup(
      message: "Exported $monthKey",
      icon: Icons.check,
    );
  }


  Future<void> printMonth(String monthKey) async {

    final data = await DriftService.db.customSelect(
      '''
    SELECT
      m.name,
      c.amount,
      c.date

    FROM contributions c

    LEFT JOIN members m
      ON m.id = c.member_id

    WHERE strftime('%Y-%m', datetime(c.date)) = ?

    ORDER BY c.date DESC
    ''',
      variables: [
        drift.Variable.withString(monthKey),
      ],
    ).get();

    if (data.isEmpty) return;

    final pdf = pw.Document();

    double total = 0;

    for (final row in data) {
      total +=
          (row.data['amount'] as num?)?.toDouble() ?? 0;
    }

    pdf.addPage(
      pw.MultiPage(
        build: (context) {
          return [

            pw.Text(
              'Monthly Contributions',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
              ),
            ),

            pw.SizedBox(height: 10),

            pw.Text(
              'Month: ${DriftService.formatMonth(monthKey)}',
            ),

            pw.Text(
              'Total: ₱${total.toStringAsFixed(2)}',
            ),

            pw.SizedBox(height: 20),

            pw.Table.fromTextArray(
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
              ),

              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              headers: [
                'Name',
                'Amount',
                'Date',
              ],


              data: data.map((e) {

                return [
                  e.data['name']?.toString() ?? '',

                  '₱${(e.data['amount'] as num).toStringAsFixed(2)}',

                  DateFormat.yMMMd().format(
                    DateTime.parse(
                      e.data['date'].toString(),
                    ),
                  ),
                ];
              }).toList(),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }
}