import 'package:flutter/material.dart';

class ObjectDetectionScreen extends StatelessWidget {
  const ObjectDetectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Object Detection'),
      ),
      body: const Center(
        child: Text(
          'Object Detection Screen\nComing Soon...',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}