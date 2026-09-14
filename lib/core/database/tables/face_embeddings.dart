import 'package:drift/drift.dart';
import 'package:ai_vision/core/database/tables/persons.dart';

class FaceEmbeddings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get personId => integer().references(Persons, #id)();
  BlobColumn get embedding => blob()(); // Face embedding vector as bytes
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
}