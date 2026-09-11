import 'package:drift/drift.dart';

class Persons extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get fullName => text().withLength(min: 1, max: 100)();
  DateTimeColumn get dateOfBirth => dateTime().nullable()();
  TextColumn get employeeId => text().withLength(min: 1, max: 50)();
  TextColumn get notes => text().named('notes').nullable()();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt => dateTime().clientDefault(() => DateTime.now())();
}