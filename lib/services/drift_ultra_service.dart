import '../db/drift_db.dart';
import 'package:drift/drift.dart';

class DriftUltraService {
  static final db = DriftDB();

  // =========================
  // 🔥 PAGINATION (CURSOR)
  // =========================

  static Future<List<Map<String, dynamic>>> getPayments({
    required String ownerType,
    int limit = 50,
    int? lastId,
  }) async {
    final res = await db.customSelect('''
      SELECT 
        p.id,
        p.amount,
        p.date,
        l.total_amount,
        COALESCE(m.name, nm.name) as name
      FROM payments p
      LEFT JOIN loans l ON l.id = p.loan_id
      LEFT JOIN members m 
        ON m.id = p.owner_id AND p.owner_type = 'member'
      LEFT JOIN non_members nm 
        ON nm.id = p.owner_id AND p.owner_type = 'non_member'
      WHERE p.owner_type = ?
      ${lastId != null ? "AND p.id < ?" : ""}
      ORDER BY p.id DESC
      LIMIT ?
    ''', variables: [
      Variable.withString(ownerType),
      if (lastId != null) Variable.withInt(lastId),
      Variable.withInt(limit),
    ]).get();

    return res.map((e) => e.data).toList();
  }

  // =========================
  // 🔥 FILTER (DYNAMIC)
  // =========================

  static Future<List<Map<String, dynamic>>> filterPayments({
    String query = "",
    DateTime? start,
    DateTime? end,
    int limit = 50,
    int? lastId,
  }) async {
    final conditions = <String>[];
    final vars = <Variable>[];

    if (query.isNotEmpty) {
      conditions.add("name LIKE ?");
      vars.add(Variable.withString('$query%'));
    }

    if (start != null) {
      conditions.add("p.date >= ?");
      vars.add(Variable.withDateTime(start));
    }

    if (end != null) {
      conditions.add("p.date <= ?");
      vars.add(Variable.withDateTime(end));
    }

    if (lastId != null) {
      conditions.add("p.id < ?");
      vars.add(Variable.withInt(lastId));
    }

    final where = conditions.isEmpty ? "" : "WHERE " + conditions.join(" AND ");

    final res = await db.customSelect('''
      SELECT p.*, 
             COALESCE(m.name, nm.name) as name
      FROM payments p
      LEFT JOIN members m ON m.id = p.owner_id
      LEFT JOIN non_members nm ON nm.id = p.owner_id
      $where
      ORDER BY p.id DESC
      LIMIT ?
    ''', variables: [
      ...vars,
      Variable.withInt(limit),
    ]).get();

    return res.map((e) => e.data).toList();
  }

  // =========================
  // 🔥 ULTRA ANALYTICS (1 QUERY)
  // =========================

  static Future<Map<String, dynamic>> dashboard() async {
    final res = await db.customSelect('''
      SELECT 
        (SELECT IFNULL(SUM(amount),0) FROM payments) as payments,
        (SELECT IFNULL(SUM(total_amount),0) FROM loans) as loans,
        (SELECT COUNT(*) FROM members) as members,
        (SELECT COUNT(*) FROM loans WHERE due_date < CURRENT_TIMESTAMP) as overdue
    ''').getSingle();

    return res.data;
  }

  // =========================
  // 🔥 RUNNING TOTAL (WINDOW FUNCTION)
  // =========================

  static Future<List<Map<String, dynamic>>> runningPayments(int loanId) async {
    final res = await db.customSelect('''
      SELECT 
        p.*,
        SUM(p.amount) OVER (
          PARTITION BY p.loan_id 
          ORDER BY p.date
        ) as running_total
      FROM payments p
      WHERE p.loan_id = ?
      ORDER BY p.date
    ''', variables: [
      Variable.withInt(loanId),
    ]).get();

    return res.map((e) => e.data).toList();
  }

  // =========================
  // 🔥 COUNT (FOR PAGINATION UI)
  // =========================

  static Future<int> countPayments(String ownerType) async {
    final res = await db.customSelect('''
      SELECT COUNT(*) as total
      FROM payments
      WHERE owner_type = ?
    ''', variables: [
      Variable.withString(ownerType),
    ]).getSingle();

    return res.data['total'];
  }

  // =========================
  // 🔥 REALTIME STREAM
  // =========================

  static Stream<Map<String, dynamic>> dashboardStream() {
    return db.customSelect('SELECT 1').watch().asyncMap((_) => dashboard());
  }
}