import 'package:flutter_dotenv/flutter_dotenv.dart';

String get apiUrl => dotenv.env['API_URL'] ?? 'http://127.0.0.1:8181/api';
