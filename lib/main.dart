import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'app/data/anythink_auth_repository.dart';
import 'app/data/anythink_notes_repository.dart';
import 'src/anythink/anythink.dart';

/// API origin. Override with `--dart-define=BASE_URL=...`.
const baseUrl = String.fromEnvironment(
  'BASE_URL',
  defaultValue: 'https://api.uk01-lon.anythink.cloud',
);

/// Organisation id. Override with `--dart-define=PROJECT_ID=...`.
const projectId = String.fromEnvironment(
  'PROJECT_ID',
  defaultValue: '19515783',
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final client = AnythinkClient(
    baseUrl: baseUrl,
    projectId: projectId,
    tokenStore: SecureTokenStore(),
  );
  runApp(
    AnythinkSampleApp(
      authRepository: AnythinkAuthRepository(client),
      notesRepository: AnythinkNotesRepository(client),
      projectLabel: 'Project $projectId · $baseUrl',
    ),
  );
}
