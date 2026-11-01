# anythink_flutter_sample

I put this together for the Flutter Engineer contract. It is a small notes app against a free Anythink project, and the client under it is the shape I would start an official package from.

The app signs a user in, keeps the session, and lists and creates `notes`. The UI is a sign-in and register form, a notes list with pull-to-refresh and another page of results, and an add-note form. Cubits talk to two repository interfaces. `lib/src/anythink` is the part that knows the HTTP API.

## Run

```sh
flutter pub get
flutter analyze
flutter test
flutter run \
  --dart-define=BASE_URL=https://api.uk01-lon.anythink.cloud \
  --dart-define=PROJECT_ID=19515783
```

Those two values are the defaults, so `flutter run` without the defines hits the same project. Web, iOS, Android and Linux are in the tree.

`flutter analyze` is clean and `flutter test` covers refresh rotation, single-flight refresh, the 401 retry, error mapping and the JSON models. The HTTP in those tests is mocked.

## What worked

The project-scoped paths in the current guides match the live API.

- `POST /org/19515783/auth/v1/token`, `/auth/v1/refresh`, `/auth/v1/register`, `/auth/v1/logout`
- `GET /org/19515783/entities/notes/items` and `POST` to the same path
- `GET /org/19515783/users/me`

I called these without a valid session. Sign-in with a bad password is `401`. A notes call with no credential is `401` problem-details (`title: Unauthorized`, plus `traceId`). Validation failures are problem-details with a PascalCase `errors` map (`Password`, `Email`, `FirstName`). `PATCH` on a note is `405` with an empty body. `GET /org/19515783/notes` is `404` with an empty body, so the record route really is under `/entities/`.

A register body that passes the password rules (8 characters, upper, lower, digit, symbol) is answered with `400` and the text `Organisation does not allow registrations`. A weak password never gets that far: the API returns the validation problem-details first.

Org routes advertise `X-RateLimit-Limit: 2000`. There is also an `x-ratelimit-routetype` header (`org` on these routes, `general` on the stray `/notes` path, where the limit was 5000). The reset value is an HTTP date.

## What got in the way

Self-registration is off, so this sample has not signed a real user in and has not read or created a note on the live API.

I tried to turn registrations on in the dashboard: Settings › Users, Allow registrations, a default role for new users, Save. Save fails with HTTP 400, `Organisation name is required`, even though the organisation name is set. That is why the register call above still says registrations are not allowed. I could not get past it, so I have not seen `Registration successful`, a token response, a refresh rotation, `GET /users/me`, or a notes page from this project.

Web sign-in does not work from a browser, and a package cannot hide that. `OPTIONS` on `/auth/v1/token` and `/entities/notes/items` returns `204` and echoes `Access-Control-Allow-Origin` for the requesting origin (`http://127.0.0.1:43123`, `http://127.0.0.1:143123`, and `http://localhost:43123`). The actual `POST /auth/v1/token` (`401` and `400`) and `GET /entities/notes/items` (`401`) responses carry no CORS headers at all. Chrome then fails the fetch before Dart can read the status, which is why the web app shows a network error instead of `Invalid email or password`. iOS, Android and desktop do not apply CORS, so the same client works there. I would want Anythink to put `Access-Control-Allow-Origin` on the real response, not only on the preflight.

A few response shapes will bite a client that assumes one error document.

- With `Accept: */*` or `application/json, text/plain, */*`, the bad-password body is plain text: `Invalid email or password`. With `Accept: application/json` only, the same call is `application/json` and the body is a JSON string, including the quotes. Refresh (`Invalid refresh token`) and the registrations-disabled response do the same switch. The client sends the mixed `Accept` and the mapper accepts both.
- Missing-credential `401`s are problem-details. The sign-in `401` is not.
- `POST /auth/v1/logout` with a token I made up returned `200` and an empty body. I have not logged out a real session.
- `POST /auth/v1/confirm-email` for an unknown address returned `400` `User not found`. The sign-in guide only lists `Invalid confirmation token`.
- `GET /entities/notes/public/items` returned `404` `Entity 'notes' not found`. The entity exists; it is not public. The wording matches the unknown-entity error.
- `GET /org/1/entities/notes/items` returned `403` `{ "error", "message", "tenant_id" }`, a third shape, and that response had no rate-limit headers.
- The sign-in guide's "call the API as the user" example is `GET /org/{project_id}/orders`. That path is not the records API. The REST reference is the one that matches what I called.
- `https://docs.anythink.cloud/building-my-app/users-and-security/roles-and-permissions` still says register returns tokens, shows a password that would fail the current rules, and describes refresh as returning a new access token. The current sign-in guide is the one I implemented: register is plain text, refresh returns a new pair, and the refresh token is single use. I have not confirmed the rotation against a live token.
- `pageSize=0` with a bad bearer is still `401`. Auth is checked before the page-size rule, so I have not seen the documented `400`.

The `429` body in the mapper is the example from the REST reference. I did not trip the rate limit.

## What an official Anythink Flutter package should hide

The app should not know any of the following.

**Session.** Write the access token, the refresh token and the absolute expiry into a `TokenStore`. Ship a `flutter_secure_storage` implementation (Keychain, encrypted preferences). On web that plugin keeps an encrypted value in local storage, which is not a keychain, so the store stays an interface. Treat the access token as opaque and trust `expires_in` (the guides say 1800 seconds). Refresh a minute early. Refresh tokens are single use: one in-flight refresh for the whole client, persist the new pair before anyone else reads it, and if another call already refreshed while a request was in flight, retry with that result instead of rotating again. A `401` refreshes once and the original request is sent once more. A rejected refresh drops the local session.

**URLs.** Callers pass `baseUrl` and `projectId`. The package owns `/org/{projectId}/auth/v1/...` and `/org/{projectId}/entities/{entity}/items`.

**Errors.** One exception type for the shapes above: problem-details, a JSON string, plain text, an empty body, and `{error, message}`. Field errors stay attached, under the PascalCase names the API sends. Keep `traceId` for support. On web, translate the browser's `Failed to fetch` into the CORS gap above. The package still cannot recover a body the browser has discarded.

**Records.** `entity<T>(name, fromJson:)` returns a repository. List speaks camelCase query parameters (`page`, `pageSize`, `sortBy`, `sortDirection`) and parses the snake_case page (`items`, `page_size`, `has_next_page`, `total_items`). Create posts the field map and parses the record. `Note` is the sample of that, not a type the package should ship.

**The rest of auth, when the product surface is in the same session.** I would not make an app call these itself: native Apple and Google (`POST /auth/v1/native/apple` and `/auth/v1/native/google`, documented on the mobile guide, not called here), Apple IAP verify and `GET /integrations/anythinkpay/subscriptions/me/entitlement`, and `POST /push/devices`. Magic link is a system email template (`{{ MagicLinkUrl }}`) and an older roles page describes it, but the current sign-in guide has no request path. I would not invent one in the package until that contract is written down.

```dart
final anythink = AnythinkClient(
  baseUrl: 'https://api.uk01-lon.anythink.cloud',
  projectId: '19515783',
);

await anythink.auth.register(
  firstName: 'Ada',
  lastName: 'Lovelace',
  email: 'ada@example.com',
  password: password,
);

final user = await anythink.auth.signIn(
  email: 'ada@example.com',
  password: password,
);

final notes = anythink.entity<Note>('notes', fromJson: Note.fromJson);
final page = await notes.list(
  page: 1,
  pageSize: 20,
  sortBy: 'id',
  sortDirection: 'desc',
);
await notes.create({'title': 'Field', 'body': 'Written from the app.'});

await anythink.auth.signOut();
```

`register` does not sign the user in. `signIn` stores the session and then reads `GET /users/me`. That last call, and every successful notes call, is untested against this project for the reason above.
