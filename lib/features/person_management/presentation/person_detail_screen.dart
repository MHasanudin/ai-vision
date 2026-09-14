import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ai_vision/features/person_management/data/person_providers.dart';

class PersonDetailScreen extends ConsumerWidget {
  final int personId;

  const PersonDetailScreen({super.key, required this.personId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personAsync = ref.watch(personByIdProvider(personId));
    final embeddingsAsync = ref.watch(personEmbeddingsProvider(personId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Person Detail'),
      ),
      body: personAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error loading person: $error'),
        ),
        data: (person) {
          if (person == null) {
            return const Center(child: Text('Person not found'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Avatar and name
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      child: Text(
                        person.fullName.isNotEmpty
                            ? person.fullName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      person.fullName,
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      person.employeeId,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Person information
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.cake),
                      title: const Text('Date of Birth'),
                      subtitle: Text(
                        person.dateOfBirth == null
                            ? 'Not set'
                            : '${person.dateOfBirth!.day} ${_monthName(person.dateOfBirth!.month)} ${person.dateOfBirth!.year}',
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.badge),
                      title: const Text('Employee ID'),
                      subtitle: Text(person.employeeId),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.notes),
                      title: const Text('Notes'),
                      subtitle: Text(person.notes ?? 'No notes'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: const Text('Registered'),
                      subtitle: Text(
                        '${person.createdAt.day} ${_monthName(person.createdAt.month)} ${person.createdAt.year}',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Face embeddings section
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Face Embeddings',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () => context.go('/persons/${person.id}/capture'),
                            icon: const Icon(Icons.add_a_photo, size: 18),
                            label: const Text('Capture'),
                          ),
                        ],
                      ),
                    ),
                    embeddingsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (error, stack) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Error: $error'),
                      ),
                      data: (embeddings) {
                        if (embeddings.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'No face embeddings captured yet.\n'
                              'Tap "Capture" to register this person\'s face.',
                            ),
                          );
                        }
                        return Column(
                          children: embeddings.map((e) => ListTile(
                            leading: const Icon(Icons.face),
                            title: Text('Embedding #${e.id}'),
                            subtitle: Text(
                              'Captured: ${e.createdAt.day} ${_monthName(e.createdAt.month)} ${e.createdAt.year}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _deleteEmbedding(context, ref, e.id),
                              tooltip: 'Delete embedding',
                            ),
                          )).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Delete person button
              OutlinedButton.icon(
                onPressed: () => _deletePerson(context, ref, person.id),
                icon: const Icon(Icons.delete_forever),
                label: const Text('Delete Person'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteEmbedding(BuildContext context, WidgetRef ref, int embeddingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Embedding'),
        content: const Text('Are you sure you want to delete this face embedding?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final dao = ref.read(faceEmbeddingDaoProvider);
      await dao.deleteFaceEmbedding(embeddingId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Embedding deleted')),
        );
      }
    }
  }

  Future<void> _deletePerson(BuildContext context, WidgetRef ref, int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Person'),
        content: const Text(
          'This will permanently delete this person and all their face embeddings. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final dao = ref.read(personDaoProvider);
      await dao.deletePerson(id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Person deleted')),
        );
        Navigator.pop(context);
      }
    }
  }

  String _monthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return months[month - 1];
  }
}