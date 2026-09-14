import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ai_vision/features/person_management/data/person_providers.dart';

class PersonListScreen extends ConsumerWidget {
  const PersonListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personsAsync = ref.watch(allPersonsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registered Persons'),
      ),
      body: personsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error loading persons: $error'),
        ),
        data: (persons) {
          if (persons.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No persons registered yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tap + to register a new person',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: persons.length,
            itemBuilder: (context, index) {
              final person = persons[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(
                    person.fullName.isNotEmpty
                        ? person.fullName[0].toUpperCase()
                        : '?',
                  ),
                ),
                title: Text(person.fullName),
                subtitle: Text(
                  person.employeeId.isNotEmpty
                      ? person.employeeId
                      : (person.dateOfBirth?.toString().split(' ').first ?? ''),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/persons/${person.id}'),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/persons/create'),
        tooltip: 'Register New Person',
        child: const Icon(Icons.add),
      ),
    );
  }
}