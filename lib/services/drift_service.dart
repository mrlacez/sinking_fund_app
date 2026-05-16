import '../db/drift_db.dart';
import 'package:drift/drift.dart';
import 'package:intl/intl.dart';

class DriftService {
  static final db = DriftDB();

  // ================= MEMBERS =================
  static Future<List<Map<String, dynamic>>> getMembers({
    int limit = 50,
    int? lastId,
  }) async {
    final res = await db.customSelect('''
    SELECT *
    FROM members
    ${lastId != null ? "WHERE id < ?" : ""}
    ORDER BY id DESC
    LIMIT ?
  ''', variables: [
      if (lastId != null) Variable.withInt(lastId),
      Variable.withInt(limit),
    ]).get();

    return res.map((e) => e.data).toList();
  }



  static Future<void> deleteMember(int id) async {
    await (db.delete(db.members)..where((m) => m.id.equals(id))).go();
  }

  // ================= LOANS =================

  static Future<List<Map<String, dynamic>>> getLoans({
    required bool isMember,
    int limit = 50,
    int? lastId,
  }) async {

    final type = isMember ? "member" : "non_member";

    final res = await db.customSelect(
      '''
    SELECT 
  l.id,

  l.owner_id,
  l.owner_type,

  l.total_amount,
  l.due_date,

  CASE
    WHEN l.owner_type = 'member'
      THEN m.name
    ELSE nm.name
  END as name,

  IFNULL(SUM(p.amount),0) as paid,

  (
    l.total_amount
    - IFNULL(SUM(p.amount),0)
  ) as remaining,

  CASE
    WHEN datetime(l.due_date)
      < datetime('now')
    THEN 1
    ELSE 0
  END as is_overdue

    FROM loans l

    LEFT JOIN payments p
      ON p.loan_id = l.id

    LEFT JOIN members m
      ON m.id = l.owner_id
      AND l.owner_type = 'member'

    LEFT JOIN non_members nm
      ON nm.id = l.owner_id
      AND l.owner_type = 'non_member'

    WHERE l.owner_type = ?

    ${lastId != null ? "AND l.id < ?" : ""}

    GROUP BY l.id

    ORDER BY l.id DESC

    LIMIT ?
    ''',
      variables: [
        Variable.withString(type),

        if (lastId != null)
          Variable.withInt(lastId),

        Variable.withInt(limit),
      ],
      readsFrom: {
        db.loans,
        db.payments,
        db.members,
        db.nonMembers,
      },
    ).get();

    return res.map((e) => e.data).toList();
  }

  // ================= PAYMENTS =================

  static Future<List<Map<String, dynamic>>> getPayments({
    required bool isMember,
    int limit = 50,
    int? lastId,
  }) async {
    final type = isMember ? "member" : "non_member";

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
      Variable.withString(type),
      if (lastId != null) Variable.withInt(lastId),
      Variable.withInt(limit),
    ]).get();

    return res.map((e) => e.data).toList();
  }

  // ================= FILTER =================

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

  // ================= ULTRA ANALYTICS =================

  static Future<Map<String, dynamic>> dashboard() async {

    final res = await db.customSelect(
        '''
    SELECT

      (
        SELECT IFNULL(SUM(amount),0)
        FROM contributions
      ) as funds,

      (
        SELECT IFNULL(SUM(total_amount),0)
        FROM loans
      ) as loans,

      (
        SELECT IFNULL(SUM(amount),0)
        FROM payments
      ) as payments,

      (
        SELECT COUNT(*)
        FROM members
      ) as members
    '''
    ).getSingle();

    final monthly = await monthlyTrend();

    return {
      ...res.data,
      "monthly": monthly,
    };
  }

  static Stream<Map<String, dynamic>> dashboardStream() {

    return db.customSelect(
      '''
    SELECT
      IFNULL((SELECT SUM(amount) FROM contributions),0) as funds,

      IFNULL((SELECT SUM(total_amount) FROM loans),0) as loans,

      IFNULL((SELECT SUM(amount) FROM payments),0) as payments
    ''',
      readsFrom: {
        db.contributions,
        db.loans,
        db.payments,
      },
    ).watch().asyncMap((rows) async {

      final row = rows.first.data;

      final monthly = await monthlyTrend();

      return {
        "funds": row['funds'] ?? 0,
        "loans": row['loans'] ?? 0,
        "payments": row['payments'] ?? 0,
        "monthly": monthly,
      };
    });
  }


  static Future<List<Map<String, dynamic>>> paymentsWithRunning({
    required int loanId,
  }) async {
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

  static Future<int> countPayments(bool isMember) async {
    final type = isMember ? "member" : "non_member";

    final res = await db.customSelect('''
    SELECT COUNT(*) as total
    FROM payments
    WHERE owner_type = ?
  ''', variables: [
      Variable.withString(type),
    ]).getSingle();

    return (res.data['total'] as num?)?.toInt() ?? 0;
  }


  static Future<List<Map<String, dynamic>>> monthlyPayments() async {
    final res = await db.customSelect('''
    SELECT 
      strftime('%Y-%m', date / 1000, 'unixepoch') as month,
      SUM(amount) as total
    FROM payments
    GROUP BY month
    ORDER BY month DESC
  ''').get();

    return res.map((e) => e.data).toList();
  }


  // 🔥 NON MEMBERS PAGINATION
  static Future<List<Map<String, dynamic>>> getNonMembers({
    int limit = 50,
    int? lastId,
  }) async {
    final res = await db.customSelect('''
    SELECT *
    FROM non_members
    ${lastId != null ? "WHERE id < ?" : ""}
    ORDER BY id DESC
    LIMIT ?
  ''', variables: [
      if (lastId != null) Variable.withInt(lastId),
      Variable.withInt(limit),
    ]).get();

    return res.map((e) => e.data).toList();
  }

// 🔥 DELETE
  static Future<void> deleteNonMember(int id) async {
    await db.customStatement(
      'DELETE FROM non_members WHERE id = ?',
      [id],
    );
  }


  // 🔥 MONTHLY TREND
  static Future<List<Map<String, dynamic>>> monthlyTrend() async {

    final res = await db.customSelect(
      '''
    SELECT 
      strftime('%Y-%m', datetime(date)) as month,
      SUM(amount) as total
    FROM contributions
    GROUP BY month
    ORDER BY month DESC
    ''',
      readsFrom: {
        db.contributions,
      },
    ).get();

    return res.map((e) => e.data).toList();
  }

// 🔥 TOP CONTRIBUTORS
  static Future<List<Map<String, dynamic>>> topContributors() async {
    final res = await db.customSelect('''
    SELECT m.name, SUM(c.amount) as total
    FROM contributions c
    JOIN members m ON m.id = c.member_id
    GROUP BY m.id
    ORDER BY total DESC
    LIMIT 5 OFFSET 0
  ''').get();

    return res.map((e) => e.data).toList();
  }

// 🔥 STATS
  static Future<Map<String, dynamic>> contributionStats() async {
    final res = await db.customSelect('''
    SELECT 
      IFNULL(SUM(amount),0) as total,
      COUNT(*) as count,
      IFNULL(AVG(amount),0) as avg
    FROM contributions
  ''').getSingle();

    return res.data;
  }


  // 🔥 CONTRIBUTIONS PAGINATION
  static Future<List<Map<String, dynamic>>> getContributions({
    int limit = 50,
    int? lastId,
  }) async {

    final res = await db.customSelect(
      '''
    SELECT

      c.id,
      c.amount,
      c.date,
      c.member_id,

      m.name,

      strftime(
        '%Y-%m',
        datetime(c.date, 'localtime')
      ) as month_key

    FROM contributions c

    LEFT JOIN members m
      ON m.id = c.member_id

    WHERE c.date IS NOT NULL

      ${lastId != null ? "AND c.id < ?" : ""}

    ORDER BY c.id DESC

    LIMIT ?
    ''',

      variables: [

        if (lastId != null)
          Variable.withInt(lastId),

        Variable.withInt(limit),
      ],

      readsFrom: {
        db.contributions,
        db.members,
      },

    ).get();

    return res.map((e) => e.data).toList();
  }

// 🔥 MEMBERS LIST (FOR DROPDOWN)
  static Future<List<Map<String, dynamic>>> getMembersList() async {
    final res = await db.customSelect('''
    SELECT id, name FROM members ORDER BY name
  ''').get();

    return res.map((e) => e.data).toList();
  }

  static Future<List<Map<String, dynamic>>> getNonMembersList() async {

    final res = await db.customSelect(
        '''
    SELECT id, name
    FROM non_members
    ORDER BY name
    '''
    ).get();

    return res.map((e) => e.data).toList();
  }


  // 🔥 REPORT STATS (ULTRA QUERY)
  static Future<Map<String, dynamic>> getReportStats() async {
    final res = await db.customSelect('''
  SELECT 
    (SELECT IFNULL(SUM(amount),0) FROM contributions) as funds,

    (SELECT IFNULL(SUM(total_amount),0) FROM loans) as loans,

    (SELECT IFNULL(SUM(amount),0) FROM payments) as paid
''').getSingle();

    final data = res.data;

    final funds = (data['funds'] as num?)?.toDouble() ?? 0;
    final loans = (data['loans'] as num?)?.toDouble() ?? 0;
    final paid = (data['paid'] as num?)?.toDouble() ?? 0;

    return {
      "funds": funds,
      "loans": loans,
      "paid": paid,
      "remaining": loans - paid,
    };
  }


  // 🔐 SIMPLE ADMIN LOGIN
  static Future<bool> validateAdmin(
      String username,
      String password,
      ) async {
    final res = await db.customSelect('''
    SELECT 1 FROM admins
    WHERE username = ? AND password = ?
    LIMIT 1
  ''', variables: [
      Variable.withString(username),
      Variable.withString(password),
    ]).get();

    return res.isNotEmpty;
  }





  static Future<void> changePassword(String password) async {
    await db.customStatement('''
    INSERT INTO admins (username, password)
    SELECT 'admin', ?
    WHERE NOT EXISTS (SELECT 1 FROM admins)
  ''', [password]);

    await db.customStatement('''
    UPDATE admins SET password = ?
  ''', [password]);
  }


  static Future<bool> memberExists(
      String name, {
        int? excludeId,
      }) async {
    final res = await db.customSelect('''
    SELECT 1 FROM members
    WHERE LOWER(name) = LOWER(?)
    ${excludeId != null ? "AND id != ?" : ""}
    LIMIT 1
  ''', variables: [
      Variable.withString(name),
      if (excludeId != null) Variable.withInt(excludeId),
    ]).get();

    return res.isNotEmpty;
  }


  static Future<void> saveMember({
    int? id,
    required String name,
  }) async {
    if (id == null) {
      /// INSERT
      await db.into(db.members).insert(
        MembersCompanion.insert(name: name),
      );
    } else {
      /// UPDATE
      await (db.update(db.members)
        ..where((tbl) => tbl.id.equals(id)))
          .write(MembersCompanion(
        name: Value(name),
      ));
    }
  }


  static Future<bool> nonMemberExists(
      String name, {
        int? excludeId,
      }) async {
    final res = await db.customSelect('''
    SELECT 1 FROM non_members
    WHERE LOWER(name) = LOWER(?)
    ${excludeId != null ? "AND id != ?" : ""}
    LIMIT 1
  ''', variables: [
      Variable.withString(name),
      if (excludeId != null) Variable.withInt(excludeId),
    ]).get();

    return res.isNotEmpty;
  }


  static Future<void> saveNonMember({
    int? id,
    required String name,
  }) async {
    if (id == null) {
      await db.customStatement(
        'INSERT INTO non_members (name) VALUES (?)',
        [name],
      );
    } else {
      await db.customStatement(
        'UPDATE non_members SET name = ? WHERE id = ?',
        [name, id],
      );
    }
  }

  static Future<Map<String, dynamic>> loanStats(bool isMember) async {
    final type = isMember ? "member" : "non_member";

    final res = await db.customSelect('''
    SELECT 
      IFNULL(SUM(l.total_amount), 0) as total,
      COUNT(*) as count,
      SUM(
  CASE
    WHEN datetime(l.due_date) < datetime('now')
    THEN 1
    ELSE 0
  END
) as overdue
    FROM loans l
    WHERE l.owner_type = ?
  ''', variables: [
      Variable.withString(type),
    ]).getSingle();

    return res.data;
  }


  static Future<List<Map<String, dynamic>>> getPaymentsWithRunning({
    required int loanId,
  }) async {
    final res = await db.customSelect('''
    SELECT 
      p.*,
      SUM(p.amount) OVER (
        PARTITION BY p.loan_id 
        ORDER BY p.date
      ) as cumulative_paid
    FROM payments p
    WHERE p.loan_id = ?
    ORDER BY p.date
  ''', variables: [
      Variable.withInt(loanId),
    ]).get();

    return res.map((e) => e.data).toList();
  }


  static Future<double> getTotalPaid(int loanId) async {
    final res = await db.customSelect('''
    SELECT IFNULL(SUM(amount),0) as total
    FROM payments
    WHERE loan_id = ?
  ''', variables: [
      Variable.withInt(loanId),
    ]).getSingle();

    return (res.data['total'] as num).toDouble();
  }


  static Future<String> getOwnerName({
    required int ownerId,
    required String ownerType,
  }) async {

    try {

      final table =
      ownerType == "member"
          ? "members"
          : "non_members";

      final res = await db.customSelect(
        '''
      SELECT name
      FROM $table
      WHERE id = ?
      LIMIT 1
      ''',
        variables: [
          Variable.withInt(ownerId),
        ],
      ).getSingleOrNull();

      return res?.data['name']?.toString() ?? "Unknown";

    } catch (_) {
      return "Unknown";
    }
  }


  static Future<void> addPayment({
    required double amount,
    required int loanId,
    required int ownerId,
    required String ownerType,
  }) async {
    await db.customStatement('''
    INSERT INTO payments (loan_id, owner_id, owner_type, amount, date)
    VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)
  ''', [
      loanId,
      ownerId,
      ownerType,
      amount,
    ]);
  }

  static Future<int> addLoan({
    required double amount,
    required int ownerId,
    required String ownerType,
    required DateTime dueDate,
  }) async {

    return await db.customInsert(
      '''
    INSERT INTO loans (
      owner_id,
      owner_type,
      total_amount,
      due_date
    )
    VALUES (?, ?, ?, ?)
    ''',
      variables: [
        Variable.withInt(ownerId),
        Variable.withString(ownerType),
        Variable.withReal(amount),
        Variable.withDateTime(dueDate),
      ],
    );
  }



  static String formatMonth(String? key) {
    if (key == null) return "Unknown";

    try {
      final date = DateTime.parse("$key-01");
      return DateFormat.yMMMM().format(date); // April 2026
    } catch (_) {
      return key;
    }
  }
}