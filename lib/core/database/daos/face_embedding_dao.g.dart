// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'face_embedding_dao.dart';

// ignore_for_file: type=lint
mixin _$FaceEmbeddingDaoMixin on DatabaseAccessor<AppDatabase> {
  $PersonsTable get persons => attachedDatabase.persons;
  $FaceEmbeddingsTable get faceEmbeddings => attachedDatabase.faceEmbeddings;
  FaceEmbeddingDaoManager get managers => FaceEmbeddingDaoManager(this);
}

class FaceEmbeddingDaoManager {
  final _$FaceEmbeddingDaoMixin _db;
  FaceEmbeddingDaoManager(this._db);
  $$PersonsTableTableManager get persons =>
      $$PersonsTableTableManager(_db.attachedDatabase, _db.persons);
  $$FaceEmbeddingsTableTableManager get faceEmbeddings =>
      $$FaceEmbeddingsTableTableManager(
          _db.attachedDatabase, _db.faceEmbeddings);
}
