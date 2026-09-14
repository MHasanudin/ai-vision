import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:ai_vision/core/database/tables/persons.dart';
import 'package:ai_vision/core/database/tables/face_embeddings.dart';
import 'package:ai_vision/core/database/daos/person_dao.dart';
import 'package:ai_vision/core/database/daos/face_embedding_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Persons, FaceEmbeddings], daos: [PersonDao, FaceEmbeddingDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // You can also break the database into multiple databases by using multiple
  // instances of AppDatabase.
}

LazyDatabase _openConnection() {
  // the LazyDatabase util lets us find the right location for the file async.
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'ai_vision.db'));
    return NativeDatabase(file);
  });
}