/// @file
/// @brief

import 'package:dotenv/dotenv.dart';
import 'package:postgres/postgres.dart';

Future<void> main() async {
  final env = DotEnv();
  env.load(['../.env']);

  print(
    'Connecting to ${env["DB_HOST"]}:${env["DB_PORT"]} '
    'as ${env["DB_USER"]}...',
  );

  try {
    final connection = await Connection.open(
      Endpoint(
        host: env['DB_HOST'] ?? 'localhost',
        port: int.parse(env['DB_PORT'] ?? '5432'),
        database: env['DB_NAME'] ?? 'pokegrading',
        username: env['DB_USER'],
        password: env['DB_PASSWORD'],
      ),
      settings: const ConnectionSettings(
        sslMode: SslMode.disable,
      ),
    );

    print('Connected successfully!');

    await connection.close();
  } catch (e) {
    print('Error: $e');
  }
}
