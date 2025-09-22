import 'package:flutter/material.dart';
import 'src/app.dart';
import 'supabase_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Supabase
  await initSupabase();
  runApp(const AdminRoomApp());
}
