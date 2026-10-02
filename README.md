# Bowie

An iOS and Android app for people who share the care of a pet.

You sign in once with Supabase. After that, the phone unlocks the app with Face ID, Touch ID, a fingerprint, or the device passcode. Pets and tutor invitations are saved on the device first, then synced while the app is open and online.

This is the shell: accounts, pets, and who is invited to care for a pet. Routine tracking is not in here yet.

## Run

```bash
cp dart_defines.example.json dart_defines.json
flutter run --dart-define-from-file=dart_defines.json
```

The launch config named Bowie passes that file for you. The same command runs on an iPhone, an Android phone, or an emulator; pick the device with `-d`.

## Android release builds

To share a build with testers (Play Console internal testing, or an APK), sign it with your own upload key:

```bash
keytool -genkey -v -keystore ~/bowie-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then create `android/key.properties` (it stays out of git):

```
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=/absolute/path/to/bowie-upload.jks
```

Build with `flutter build appbundle --dart-define-from-file=dart_defines.json` for the Play Console, or `flutter build apk` for a file you send directly. Without `key.properties`, release builds are signed with the debug key and are only good for local testing. Keep the `.jks` file and its passwords backed up: the Play Store needs the same key for every update.

## Supabase

1. Create a project and turn on email auth. For a first run, you can turn off "Confirm email" so sign-up returns a session immediately.
2. Open the SQL editor and run `supabase/migrations/20260930120000_pets_and_tutors.sql`.
3. Put the project URL and anon key in `dart_defines.json`. That file stays local.

The session is stored in the iOS Keychain, or in Keystore-encrypted storage on Android. Pet and tutor rows live in SQLite on the phone. Writes go into a small outbox and are pushed when the app can reach Supabase: pets first, then tutor rows. A change still waiting in that outbox is kept on the phone until it is pushed. After that, what the server returns is what the phone shows.

## Layout

`lib/app` wires the theme, router, and providers. `lib/features/auth` is Supabase sign-in plus the device unlock. `lib/features/pets` is the pet, the tutor list, the local database, and sync. `lib/core` is config, errors, the secure session store, and connectivity.

Add each new area as another folder under `lib/features`. What to build, and in what order, is in `docs/produto/` (Portuguese).

## App icon and splash

Both come from `design/brand/app-icon` and are configured in `pubspec.yaml`. After changing an image, run `dart run flutter_launcher_icons` and `dart run flutter_native_splash:create`, then check that the generators did not change unrelated lines in `ios/Runner.xcodeproj/project.pbxproj` or `ios/Runner/Info.plist`.

## Tests

```bash
flutter test
```

## Docs

How the app works, in Portuguese: [`docs/`](docs/README.md).
