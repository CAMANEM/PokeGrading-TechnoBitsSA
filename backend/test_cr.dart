import 'package:dotenv/dotenv.dart';

void main() {
  final env = DotEnv();
  env.load(['../.env']);

  final pass = env['DB_PASSWORD']!;

  print('Password length: ${pass.length}');
  print("Password ends with \\r? ${pass.endsWith('\r')}");
  print('Password code units: ${pass.codeUnits}');
}
