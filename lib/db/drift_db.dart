import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'drift_db.g.dart';

class Payments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get loanId =>
      integer().references(Loans, #id, onDelete: KeyAction.cascade)();
  IntColumn get ownerId => integer()();
  TextColumn get ownerType => text()();
  RealColumn get amount => real()();
  DateTimeColumn get date => dateTime()();

  @override
  List<Set<Column>> get indexes => [
    {ownerId, ownerType},
    {loanId, date},
    {ownerType, date},
  ];
}

class Loans extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ownerId => integer()();
  TextColumn get ownerType => text()();
  RealColumn get totalAmount => real()();
  DateTimeColumn get dueDate => dateTime()();

  @override
  List<Set<Column>> get indexes => [
    {ownerId, ownerType},
    {dueDate},
  ];
}

class Members extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
}

class NonMembers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
}


@DriftDatabase(
  tables: [Payments, Loans, Members, NonMembers, Contributions, Admins],
)

class DriftDB extends _$DriftDB {
  DriftDB() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // example:
        // await m.addColumn(payments, payments.updatedAt);
      }
    },
  );
}

// 🔥 database file location
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'app.db'));

    return NativeDatabase(
      file,
      setup: (db) {
        db.execute('PRAGMA journal_mode = WAL;');
        db.execute('PRAGMA foreign_keys = ON;');
      },
    );
  });
}



class Contributions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get memberId => integer().references(Members, #id)();
  RealColumn get amount => real()();
  DateTimeColumn get date => dateTime()();
}


class Admins extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get username => text()();
  TextColumn get password => text()();
}




