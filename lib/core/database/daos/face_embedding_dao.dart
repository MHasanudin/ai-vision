import 'package:drift/drift.dart';
import 'package:ai_vision/core/database/app_database.dart';
import 'package:ai_vision/core/database/tables/face_embeddings.dart';

part 'face_embedding_dao.g.dart';

@DriftAccessor(tables: [FaceEmbeddings])
class FaceEmbeddingDao extends DatabaseAccessor<AppDatabase> with _$FaceEmbeddingDaoMixin {
  FaceEmbeddingDao(super.db);

  Future<List<FaceEmbedding>> getAllFaceEmbeddings() => select(faceEmbeddings).get();

  Stream<List<FaceEmbedding>> watchAllFaceEmbeddings() => select(faceEmbeddings).watch();

  Future<FaceEmbedding> getFaceEmbeddingById(int id) => (select(faceEmbeddings)..where((f) => f.id.equals(id))).getSingle();

  Future<int> insertFaceEmbedding(Insertable<FaceEmbedding> embedding) => into(faceEmbeddings).insert(embedding);

  Future<bool> updateFaceEmbedding(FaceEmbedding embedding) => update(faceEmbeddings).replace(embedding);

  Future<int> deleteFaceEmbedding(int id) async {
    return (delete(faceEmbeddings)..where((f) => f.id.equals(id))).go();
  }

  // Get embeddings for a specific person
  Future<List<FaceEmbedding>> getEmbeddingsByPersonId(int personId) =>
      (select(faceEmbeddings)..where((f) => f.personId.equals(personId))).get();

  Future<int> deleteAllFaceEmbeddings() => delete(faceEmbeddings).go();
}