# MDSPro Owner — Flutter Mobile App

Owner dashboard app for MDSPro ShopMaster. Gives shop owners instant access to sales, stock, and reports from their phone.

## Screens

| Screen | Description |
|---|---|
| Splash | Animated brand intro, auto-checks auth |
| Login | Email + password, same credentials as web |
| Dashboard | Today's sales, revenue, net profit, quick actions, weekly bar chart, recent sales |
| Sales | Sales history with Today / Week / Month / All filters + search |
| Stock | All products + Low Stock tab with progress bars |
| Reports | P&L card, KPI grid, daily line chart, revenue vs expenses donut |
| Profile | Owner info, settings, sign out |

## Setup

### 1. Install Flutter SDK
Download from https://flutter.dev/docs/get-started/install

### 2. Set your server URL
Edit `lib/services/api_service.dart` line 7:
```dart
static const String baseUrl = 'https://mdspro.co.tz';
```

### 3. Upload backend endpoints
Upload the `ajax/mobile/` folder to your ShopMaster server:
- `ajax/mobile/auth.php`
- `ajax/mobile/dashboard.php`
- `ajax/mobile/sales.php`
- `ajax/mobile/stock.php`
- `ajax/mobile/branches.php`

### 4. Run the app
```bash
flutter pub get
flutter run
```

### 5. Build APK (Android)
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### 6. Build iOS
```bash
flutter build ios --release
# Then archive in Xcode
```

## API Authentication
The app uses PHP session cookies — same session as the web app. Login creates a session, and all subsequent requests carry the `PHPSESSID` cookie. Only `owner` and `manager` roles can log in via mobile.

## Colors
- Primary (deep forest green): `#0F2D1A`
- Accent (amber): `#F4A261`
- Navy (premium cards): `#12182E`
- Gold: `#C49430`

## Dependencies
- `fl_chart` — bar, line, pie charts
- `shimmer` — loading skeletons
- `http` — API calls
- `shared_preferences` — session cookie + user cache
- `intl` — currency/date formatting
- `iconsax` — additional icons
