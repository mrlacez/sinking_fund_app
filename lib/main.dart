import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../services/drift_service.dart';

import 'package:sinking_fund_app/screens/members.dart';
import 'package:sinking_fund_app/screens/non_members.dart';
import 'package:sinking_fund_app/screens/contributions.dart';
import 'package:sinking_fund_app/screens/reports.dart';
import 'package:sinking_fund_app/screens/loan_selector.dart';
import 'package:sinking_fund_app/screens/login.dart';
import 'package:sinking_fund_app/screens/setup.dart';
import 'package:sinking_fund_app/screens/payments.dart';

import '../widgets/app_card.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp(hasPassword: false));
}

class MyApp extends StatelessWidget {
  final bool hasPassword;

  const MyApp({super.key, required this.hasPassword});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  void _handleTap(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }


  void openPaymentsSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            ListTile(
              leading: const Icon(Icons.people),
              title: const Text("Member Payments"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PaymentsScreen(isMember: true),
                  ),
                );
              },
            ),

            ListTile(
              leading: const Icon(Icons.person_off),
              title: const Text("Non-Member Payments"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PaymentsScreen(isMember: false),
                  ),
                );
              },
            ),

            const SizedBox(height: 10),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
              );
            },
          )
        ],
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [

              /// HEADER
              const _HeaderSection(),

              const SizedBox(height: 8),

              /// SUMMARY
              const _SummarySection(),

              const SizedBox(height: 8),

              /// MENU GRID
              Expanded(
                child: GridView.count(
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.82,
                  children: [

                    MenuCard(
                      title: "Members",
                      icon: Icons.people,
                      onTap: () => _handleTap(
                        context,
                        const MembersScreen(),
                      ),
                    ),

                    MenuCard(
                      title: "Non-Members",
                      icon: Icons.person_off,
                      onTap: () => _handleTap(
                        context,
                        const NonMembersScreen(),
                      ),
                    ),

                    MenuCard(
                      title: "Contributions",
                      icon: Icons.savings,
                      onTap: () => _handleTap(
                        context,
                        const ContributionsScreen(),
                      ),
                    ),

                    MenuCard(
                      title: "Loans",
                      icon: Icons.account_balance,
                      onTap: () => _handleTap(
                        context,
                        const LoanSelectorScreen(),
                      ),
                    ),

                    MenuCard(
                      title: "Payments",
                      icon: Icons.payment,
                      onTap: () => openPaymentsSelector(context),
                    ),

                    MenuCard(
                      title: "Reports",
                      icon: Icons.bar_chart,
                      onTap: () => _handleTap(
                        context,
                        const ReportsScreen(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Sinking Fund",
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 5),
          Text(
            "Manage your finances efficiently",
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _SummarySection extends StatefulWidget {
  const _SummarySection();

  @override
  State<_SummarySection> createState() => _SummarySectionState();
}

class _SummarySectionState extends State<_SummarySection> {
  String filter = "All";

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: DriftService.dashboardStream(),
      builder: (context, snapshot) {

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;

        final funds = (data["funds"] as num).toDouble();
        final loans = (data["loans"] as num).toDouble();
        final payments = (data["payments"] as num).toDouble();
        final monthly = data["monthly"] as List;

        final hasData = funds > 0 || loans > 0 || payments > 0;

        return Column(
          children: [

            /// 🔥 FILTER (optional, UI only)
            DropdownButton(
              value: filter,
              items: ["All", "This Month", "This Year"]
                  .map((e) => DropdownMenuItem(
                value: e,
                child: Text(e),
              ))
                  .toList(),
              onChanged: (v) {
                setState(() => filter = v.toString());
              },
            ),

            /// 🔥 SUMMARY
            Row(
              children: [
                Expanded(
                  child: SummaryCard(
                    title: "Funds",
                    amount: "₱${funds.toStringAsFixed(0)}",
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SummaryCard(
                    title: "Loans",
                    amount: "₱${loans.toStringAsFixed(0)}",
                    color: Colors.red,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: SummaryCard(
                    title: "Collected",
                    amount: "₱${payments.toStringAsFixed(0)}",
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SummaryCard(
                    title: "Balance",
                    amount: "₱${(loans - payments).toStringAsFixed(0)}",
                    color: Colors.orange,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            /// 🔥 CHART
            hasData
                ? buildChart(monthly)
                : Container(
              height: 110,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bar_chart,
                    size: 40,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 10),
                  Text(
                    "No financial data yet",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget buildChart(List data) {
    return SizedBox(
      height: 110,
      child: LineChart(
        LineChartData(
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              isCurved: true,
              spots: [
                for (int i = 0; i < data.length; i++)
                  FlSpot(
                    i.toDouble(),
                    (data[i]['total'] as num).toDouble(),
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class SummaryCard extends StatelessWidget {
  final String title;
  final String amount;
  final Color color;

  const SummaryCard({
    super.key,
    required this.title,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text(
              amount,
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

class MenuCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const MenuCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 28, color: Colors.blue),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }


}