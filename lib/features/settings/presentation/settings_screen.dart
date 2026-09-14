import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerWidget {
  final void Function(bool) onThemeChanged;

  const SettingsScreen({super.key, required this.onThemeChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Detection Section
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Detection',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          _buildSliderTile(
            context,
            title: 'Object Confidence Threshold',
            subtitle: 'Minimum confidence to show detection',
            value: 0.5,
            min: 0.1,
            max: 1.0,
            divisions: 9,
            onChanged: (value) {},
          ),
          _buildSliderTile(
            context,
            title: 'Face Recognition Threshold',
            subtitle: 'Minimum similarity for face match',
            value: 0.7,
            min: 0.5,
            max: 1.0,
            divisions: 5,
            onChanged: (value) {},
          ),
          _buildSliderTile(
            context,
            title: 'Inference FPS',
            subtitle: 'Target inference frames per second',
            value: 15,
            min: 5,
            max: 30,
            divisions: 5,
            onChanged: (value) {},
          ),

          // Camera Section
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Camera',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          _buildSwitchTile(
            context,
            title: 'Mirror Front Camera',
            subtitle: 'Mirror preview for front camera',
            value: true,
            onChanged: (value) {},
          ),
          _buildDropdownTile(
            context,
            title: 'Default Camera',
            subtitle: 'Select default camera on startup',
            value: 'rear',
            items: const ['front', 'rear'],
            onChanged: (value) {},
          ),

          // Appearance Section
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Appearance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          _buildSwitchTile(
            context,
            title: 'Dark Mode',
            subtitle: 'Use dark theme',
            value: false,
            onChanged: onThemeChanged,
          ),

          // Data Section
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Data',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Registered Persons'),
            subtitle: const Text('View and manage registered persons'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Clear Face Database'),
            subtitle: const Text('Delete all face embeddings and person data'),
            textColor: Colors.red,
            onTap: () => _showClearDatabaseDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.restore, color: Colors.orange),
            title: const Text('Reset App'),
            subtitle: const Text('Reset all settings to defaults'),
            textColor: Colors.orange,
            onTap: () => _showResetAppDialog(context),
          ),

          // Privacy Section
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Privacy',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const ListTile(
            leading: Icon(Icons.privacy_tip),
            title: Text('Privacy Information'),
            subtitle: Text(
              '✓ AI processing happens on this device\n'
              '✓ No camera images are uploaded\n'
              '✓ Face data is stored locally\n'
              '✓ Internet connection is not required',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required void Function(double) onChanged,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: value.toStringAsFixed(1),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required void Function(bool) onChanged,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildDropdownTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: DropdownButton<String>(
        value: value,
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  void _showClearDatabaseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Face Database'),
        content: const Text(
          'This will permanently delete all registered persons and their face embeddings. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement database clearing
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Database cleared')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showResetAppDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset App'),
        content: const Text(
          'This will reset all settings to their default values. Your registered persons will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement settings reset
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings reset to defaults')),
              );
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}