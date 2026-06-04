import 'package:dotenv/dotenv.dart';

void main() {
  final env = DotEnv();
  env.load(['../.env']);
  print('USER: ${env['DB_USER']}');
  print('PASS: ${env['DB_PASSWORD']}');
}
