import 'package:drift/drift.dart';
import 'package:ai_vision/core/database/app_database.dart';
import 'package:ai_vision/core/database/tables/persons.dart';

part 'person_dao.g.dart';

@DriftAccessor(tables: [Persons])
class PersonDao extends DatabaseAccessor<AppDatabase> with _$PersonDaoMixin {
  PersonDao(super.db);

  Future<List<Person>> getAllPersons() => select(persons).get();

  Stream<List<Person>> watchAllPersons() => select(persons).watch();

  Future<Person> getPersonById(int id) => (select(persons)..where((p) => p.id.equals(id))).getSingle();

  Future<int> insertPerson(Person person) => into(persons).insert(person);

  Future<bool> updatePerson(Person person) => update(persons).replace(person);

  Future<int> deletePerson(int id) async {
    return (delete(persons)..where((p) => p.id.equals(id))).go();
  }

  Future<int> deleteAllPersons() => delete(persons).go();
}