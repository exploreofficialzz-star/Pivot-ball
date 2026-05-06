# GitHub Secrets Setup — Pivot Ball

All secrets live at:  
**GitHub → Your Repo → Settings → Secrets and variables → Actions → New repository secret**

Or use the `gh` CLI (fastest):
```bash
gh secret set SECRET_NAME --body "VALUE" --repo YOUR_ORG/YOUR_REPO
```

---

## 1. Android Signing (4 secrets)

These sign the release APK/AAB so it can be published to the Play Store.

### Step 1 — Generate a keystore (skip if you already have one)
```bash
keytool -genkey -v \
  -keystore pivotball-release.jks \
  -alias pivotball \
  -keyalg RSA -keysize 2048 \
  -validity 10000
```
> ⚠️ Keep `pivotball-release.jks` safe — losing it means you can never update your Play Store listing.

### Step 2 — Base64-encode the keystore
```bash
# macOS
base64 -i pivotball-release.jks | pbcopy   # copies to clipboard

# Linux
base64 pivotball-release.jks | tr -d '\n'
```

### Step 3 — Set the 4 secrets
| Secret Name | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Base64 output from Step 2 |
| `ANDROID_KEY_ALIAS` | `pivotball` (or whatever alias you used) |
| `ANDROID_KEY_PASSWORD` | The key password you chose |
| `ANDROID_STORE_PASSWORD` | The store password you chose |

```bash
gh secret set ANDROID_KEYSTORE_BASE64   --body "$(base64 -i pivotball-release.jks | tr -d '\n')"
gh secret set ANDROID_KEY_ALIAS         --body "pivotball"
gh secret set ANDROID_KEY_PASSWORD      --body "YOUR_KEY_PASSWORD"
gh secret set ANDROID_STORE_PASSWORD    --body "YOUR_STORE_PASSWORD"
```

---

## 2. AdMob Production IDs (8 secrets)

Replace the Google test IDs with your real AdMob IDs from  
**AdMob Console → Apps → Your App → Ad units**

| Secret Name | Where to find it |
|---|---|
| `ADMOB_APP_ID_ANDROID` | AdMob → Apps → App settings → App ID (e.g. `ca-app-pub-XXXXXXXX~YYYYYYYYY`) |
| `ADMOB_APP_ID_IOS` | Same, for the iOS app |
| `ADMOB_BANNER_ANDROID` | Ad Units → Banner → Android unit ID |
| `ADMOB_BANNER_IOS` | Ad Units → Banner → iOS unit ID |
| `ADMOB_INTERSTITIAL_ANDROID` | Ad Units → Interstitial → Android unit ID |
| `ADMOB_INTERSTITIAL_IOS` | Ad Units → Interstitial → iOS unit ID |
| `ADMOB_REWARDED_ANDROID` | Ad Units → Rewarded → Android unit ID |
| `ADMOB_REWARDED_IOS` | Ad Units → Rewarded → iOS unit ID |

```bash
gh secret set ADMOB_APP_ID_ANDROID          --body "ca-app-pub-XXXXXXXX~YYYYYYYYY"
gh secret set ADMOB_APP_ID_IOS              --body "ca-app-pub-XXXXXXXX~YYYYYYYYY"
gh secret set ADMOB_BANNER_ANDROID          --body "ca-app-pub-XXXXXXXX/YYYYYYYYY"
gh secret set ADMOB_BANNER_IOS              --body "ca-app-pub-XXXXXXXX/YYYYYYYYY"
gh secret set ADMOB_INTERSTITIAL_ANDROID    --body "ca-app-pub-XXXXXXXX/YYYYYYYYY"
gh secret set ADMOB_INTERSTITIAL_IOS        --body "ca-app-pub-XXXXXXXX/YYYYYYYYY"
gh secret set ADMOB_REWARDED_ANDROID        --body "ca-app-pub-XXXXXXXX/YYYYYYYYY"
gh secret set ADMOB_REWARDED_IOS            --body "ca-app-pub-XXXXXXXX/YYYYYYYYY"
```

---

## 3. Auto-provided (no action needed)

| Secret | Source |
|---|---|
| `GITHUB_TOKEN` | Automatically injected by GitHub Actions — nothing to set |

---

## Summary — All 12 Secrets

| # | Secret Name | Category |
|---|---|---|
| 1 | `ANDROID_KEYSTORE_BASE64` | Android Signing |
| 2 | `ANDROID_KEY_ALIAS` | Android Signing |
| 3 | `ANDROID_KEY_PASSWORD` | Android Signing |
| 4 | `ANDROID_STORE_PASSWORD` | Android Signing |
| 5 | `ADMOB_APP_ID_ANDROID` | AdMob |
| 6 | `ADMOB_APP_ID_IOS` | AdMob |
| 7 | `ADMOB_BANNER_ANDROID` | AdMob |
| 8 | `ADMOB_BANNER_IOS` | AdMob |
| 9 | `ADMOB_INTERSTITIAL_ANDROID` | AdMob |
| 10 | `ADMOB_INTERSTITIAL_IOS` | AdMob |
| 11 | `ADMOB_REWARDED_ANDROID` | AdMob |
| 12 | `ADMOB_REWARDED_IOS` | AdMob |

---

## How the secrets flow into the build

```
GitHub Secret
    │
    ▼
build.yml (--dart-define=ADMOB_BANNER_ANDROID=${{ secrets.ADMOB_BANNER_ANDROID }})
    │
    ▼
ad_manager.dart (String.fromEnvironment('ADMOB_BANNER_ANDROID'))
    │
    ▼
Runtime ad unit ID used in-app
```

For the AdMob App ID (Android only):
```
Secret: ADMOB_APP_ID_ANDROID
    │
    ▼
build.gradle.kts (manifestPlaceholders["admobAppId"])
    │
    ▼
AndroidManifest.xml (android:value="${admobAppId}")
```

---

## Triggering a Release

Tag your commit to auto-publish APK + AAB + IPA to GitHub Releases:
```bash
git tag v1.0.0
git push origin v1.0.0
```
