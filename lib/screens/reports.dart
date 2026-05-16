import 'package:flutter/material.dart';
import '../services/drift_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  double funds = 0;
  double loans = 0;
  double paid = 0;
  double remaining = 0;

  bool isLoading = true;

  bool get _isEmpty =>
      funds == 0 && loans == 0 && paid == 0 && remaining == 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final res = await DriftService.getReportStats();

    if (!mounted) return;

    setState(() {
      funds = (res['funds'] as num?)?.toDouble() ?? 0;
      loans = (res['loans'] as num?)?.toDouble() ?? 0;
      paid = (res['paid'] as num?)?.toDouble() ?? 0;
      remaining = (res['remaining'] as num?)?.toDouble() ?? 0;
      isLoading = false;
    });
  }

  /// 🔥 NO FLICKER REFRESH
  Future<void> refresh() async {
    final res = await DriftService.getReportStats();

    if (!mounted) return;

    setState(() {
      funds = (res['funds'] as num?)?.toDouble() ?? 0;
      loans = (res['loans'] as num?)?.toDouble() ?? 0;
      paid = (res['paid'] as num?)?.toDouble() ?? 0;
      remaining = (res['remaining'] as num?)?.toDouble() ?? 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final collectionRate =
    loans <= 0 ? 0.0 : (paid / loans * 100).clamp(0, 100).toDouble();

    final utilization =
    funds <= 0 ? 0.0 : (loans / funds * 100).clamp(0, 100).toDouble();

    return Scaffold(
      appBar: AppBar(title: const Text("Reports")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isEmpty
          ? const Center(child: Text("No data yet"))
          : RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [

            LayoutBuilder(
              builder: (context, constraints) {

                final width = constraints.maxWidth;

                final cardHeight =
                width < 360 ? 78.0 : 90.0;

                final fontSize =
                width < 360 ? 15.0 : 17.0;

                return GridView.count(
                  shrinkWrap: true,
                  physics:
                  const NeverScrollableScrollPhysics(),

                  crossAxisCount: 2,

                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,

                  childAspectRatio:
                  width < 360 ? 1.9 : 1.6,

                  children: [

                    _card(
                      "Funds",
                      funds,
                      Colors.green,
                      height: cardHeight,
                      fontSize: fontSize,
                    ),

                    _card(
                      "Loans",
                      loans,
                      Colors.blue,
                      height: cardHeight,
                      fontSize: fontSize,
                    ),

                    _card(
                      "Paid",
                      paid,
                      Colors.orange,
                      height: cardHeight,
                      fontSize: fontSize,
                    ),

                    _card(
                      "Remaining",
                      remaining,
                      Colors.red,
                      height: cardHeight,
                      fontSize: fontSize,
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 20),

            /// 🔥 INSIGHTS
            _insightCard(
              "Collection Rate",
              collectionRate,
              "%",
              _trendColor(collectionRate),
            ),

            _insightCard(
              "Utilization",
              utilization,
              "%",
              _trendColor(utilization),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔥 SMART COLOR
  Color _trendColor(double value) {
    if (value > 80) return Colors.green;
    if (value > 50) return Colors.orange;
    return Colors.red;
  }

  Widget _card(
      String title,
      double value,
      Color color, {
        double height = 90,
        double fontSize = 17,
      }) {

    return SizedBox(
      height: height,

      child: Card(
        elevation: 1,
        color: color,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),

        child: Padding(
          padding: const EdgeInsets.all(10),

          child: Column(
            mainAxisAlignment:
            MainAxisAlignment.center,

            children: [

              Text(
                title,

                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),

                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 4),

              FittedBox(
                child: Text(
                  "₱${value.toStringAsFixed(0)}",

                  style: TextStyle(
                    color: Colors.white,
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _insightCard(
      String title, double value, String suffix, Color color) {
    return Card(
      elevation: 1,
      color: color.withOpacity(0.95),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment:
          MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: const TextStyle(color: Colors.white)),
            Text(
              "${value.toStringAsFixed(1)}$suffix",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
