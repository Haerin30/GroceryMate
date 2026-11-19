# GroceryMate

An offline-first grocery shopping assistant built with Flutter. The app helps
people organise grocery lists, add products by search/barcode/manual entry,
track estimated costs and budgets, compare store prices, and review spending
history. No account or internet connection is needed for core features.

> Milestone 2 adds **Grocery List Management**: create, edit, delete, status
> changes, categories, filtering, and sorting with in-memory state. Local
> persistence and grocery items are planned for later milestones.

## Project details

- Display name: GroceryMate
- Package name: `grocery_scan` (unchanged technical identifier)
- Organization / application ID: `com.groceryscan` (unchanged technical identifier)
- Platforms: Android first, iOS folder included (iOS builds require macOS)
- Flutter: 3.47.4 (stable), Dart 3.13.3

## Folder structure

```text
lib/
├── main.dart                    # entry point
├── app/
│   ├── app.dart                 # MaterialApp: title, themes, routing
│   ├── router/                  # route names and drawer destinations
│   └── theme/                   # Material 3 colors and ThemeData
├── core/
│   ├── constants/               # app-wide constants
│   ├── database/                # reserved for Drift setup
│   ├── services/                # reserved for local services
│   ├── utils/
│   └── errors/
├── features/
│   └── grocery_lists/
│       ├── data/                # starter lists for the in-memory store
│       ├── domain/              # models, categories, filter/sort rules
│       ├── state/               # in-memory controller (CRUD + categories)
│       └── presentation/        # screen, card, and create/edit form
│   ├── products/                # future feature folders
│   ├── scanner/
│   ├── calculator/
│   ├── budget/
│   ├── statistics/
│   ├── shopping_history/
│   └── settings/
└── shared/
    ├── widgets/                 # reusable empty/coming-soon views
    └── models/
```

The structure is feature-first so each area can grow its own data, domain, state,
and presentation layers. The grocery list controller is a plain `ChangeNotifier`
(no extra packages); a repository-backed implementation can replace it when
Drift persistence is introduced.

## Running the app

```powershell
cd "C:\Users\Cris M. Toring\Documents\GroceryScan\grocery_scan"
flutter pub get
flutter run
```

List available devices with `flutter devices`, then target one with
`flutter run -d <device-id>`.

## Quality checks

```powershell
flutter analyze
flutter test
```

## Packages

Only the Flutter starter dependencies are present so far: `flutter`,
`cupertino_icons`, and the dev-only `flutter_test` / `flutter_lints`. Riverpod,
Drift, and barcode scanning packages will be added when those features are
implemented.
