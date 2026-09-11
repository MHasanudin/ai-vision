import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const ListTile(
            leading: Icon(Icons.vision),
            title: Text('Detection'),
            subtitle: Text('Object Confidence, Face Recognition Threshold, Inference FPS'),
          ),
          const ListTile(
            leading: Icon(Icons.camera_alt),
            title: Text('Camera'),
            subtitle: Text('Default Camera, Mirror Front Camera'),
          ),
          const ListTile(
            leading: Icon(Icons.brightness_6),
            title: Text('Appearance'),
            subtitle: Text('Dark Mode, Light Mode'),
          ),
          const ListTile(
            leading: Icon(Icons.storage),
            title: Text('Data'),
            subtitle: Text('Registered Persons, Clear Face Database, Reset App'),
          ),
          const ListTile(
            leading: Icon(Icons.privacy_tip),
            title: Text('Privacy'),
            subtitle: const Text(
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
}