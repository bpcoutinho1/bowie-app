# Bowie

An iPhone app for people who share the care of a pet.

You sign in once with Supabase. After that, the phone unlocks the app with Face ID, Touch ID, or the device passcode. Pets and tutor invitations are saved on the device first, then synced while the app is open and online.

This is the shell: accounts, pets, and who is invited to care for a pet. Routine tracking is not in here yet.

## Run

```bash
cp dart_defines.example.json dart_defines.json
flutter run --dart-define-from-file=dart_defines.json
```

The launch config named Bowie passes that file for you.

## Supabase

1. Create a project and turn on email auth. For a first run, you can turn off "Confirm email" so sign-up returns a session immediately.
2. Open the SQL editor and run `supabase/migrations/20260930120000_pets_and_tutors.sql`.
3. Put the project URL and anon key in `dart_defines.json`. That file stays local.

The session is stored in the iOS Keychain. Pet and tutor rows live in SQLite on the phone. Writes go into a small outbox and are pushed when the app can reach Supabase: pets first, then tutor rows. A change still waiting in that outbox is kept on the phone until it is pushed. After that, what the server returns is what the phone shows.

## Layout

`lib/app` wires the theme, router, and providers. `lib/features/auth` is Supabase sign-in plus the device unlock. `lib/features/pets` is the pet, the tutor list, the local database, and sync. `lib/core` is config, errors, the Keychain session store, and connectivity.

Add each new area as another folder under `lib/features`. What to build, and in what order, is in `docs/produto/` (Portuguese).

## Tests

```bash
flutter test
```

## Docs

How the app works, in Portuguese: [`docs/`](docs/README.md).
