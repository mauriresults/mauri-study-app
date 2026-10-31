import 'package:flutter/material.dart';
import 'src/student_app.dart';
export 'src/student_app.dart' show MauriStudyApp;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MauriStudyApp());
}
