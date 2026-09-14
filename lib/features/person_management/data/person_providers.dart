import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ai_vision/core/database/app_database.dart';
import 'package:ai_vision/core/database/daos/person_dao.dart';
import 'package:ai_vision/core/database/daos/face_embedding_dao.dart';

/// Provider for AppDatabase
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  
  ref.onDispose(() {
    db.close();
  });
  
  return db;
});

/// Provider for PersonDao
final personDaoProvider = Provider<PersonDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return PersonDao(db);
});

/// Provider for FaceEmbeddingDao
final faceEmbeddingDaoProvider = Provider<FaceEmbeddingDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return FaceEmbeddingDao(db);
});

/// Provider for watching all persons
final allPersonsProvider = StreamProvider<List<Person>>((ref) {
  final dao = ref.watch(personDaoProvider);
  return dao.watchAllPersons();
});

/// Provider for a single person by ID
final personByIdProvider = FutureProvider.family<Person?, int>((ref, id) async {
  final dao = ref.watch(personDaoProvider);
  try {
    return await dao.getPersonById(id);
  } catch (e) {
    return null;
  }
});

/// Provider for face embeddings of a person
final personEmbeddingsProvider = FutureProvider.family<List<FaceEmbedding>, int>((ref, personId) async {
  final dao = ref.watch(faceEmbeddingDaoProvider);
  return await dao.getEmbeddingsByPersonId(personId);
});