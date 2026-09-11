import 'package:drift/drift.dart';
import 'package:ai_vision/core/database/tables/persons.dart';

class FaceEmbeddings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get personId => integer().references(Persons, #id)();
  BlobColumn get embedding => blob().withLength(min: 1, max: 4096)(); // Adjust size as needed
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
}