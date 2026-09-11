import 'package:flutter/material.dart';

class FaceDetectionScreen extends StatelessWidget {
  const FaceDetectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Detection & Recognition'),
      ),
      body: const Center(
        child: Text(
          'Face Detection Screen\nComing Soon...',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}