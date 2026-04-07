import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StudentRegistration extends ConsumerStatefulWidget {
  const StudentRegistration({super.key});

  @override
  ConsumerState<StudentRegistration> createState() =>
      _StudentRegistrationState();
}

class _StudentRegistrationState extends ConsumerState<StudentRegistration> {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Student Registration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'Student registration is not supported on web. Please run this app on Android, iOS, or desktop to use biometric attendance.',
            ),
          ],
        ),
      ),
    );
  }
}
