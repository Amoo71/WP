# 🔥 Quick Start - Netflix WebView App ULTIMATE EDITION

## 🎯 NEW: Secret Settings Menu!

**5-Tap Gesture** → Opens ultimate settings panel with:
- 🌐 User-Agent Switcher (iPad/macOS/Android Chrome)
- 🔍 Zoom Controls (0.5x - 3.0x)
- 📱 Fullscreen Toggle
- 🎬 Video Fullscreen Mode
- 🔐 Both FairPlay AND Widevine DRM!

---

## 30 Seconds to Netflix! 🎬

### Step 1: Push to GitHub (10 seconds)
```bash
cd UPLOAD
git init
git add .
git commit -m "Netflix WebView by amo"
git remote add origin YOUR_GITHUB_REPO_URL
git push -u origin main
```

### Step 2: Download IPA (5 minutes)
1. Go to your GitHub repo
2. Click **Actions** tab
3. Wait for build to complete (~5 min)
4. Download **NetflixWebApp-IPA** artifact
5. Unzip → Get `NetflixWebApp.ipa`

### Step 3: Sideload (2 minutes)
**AltStore:**
- Open AltStore on iPhone
- Tap + → Select IPA → Install

**Sideloadly:**
- Connect iPhone
- Drag IPA to Sideloadly
- Click Start

**TrollStore:**
- Open TrollStore
- Install IPA

### Step 4: Launch & Login! (1 minute)
```
Open "Netflix by amo" app
    ↓
Branding shows: "💉 Netflix by amo"
    ↓
Prompt: "Inject session from JustPaste.it?"
    ↓
Tap "Yes"
    ↓
Pick your session
    ↓
LOGGED IN! 🎬
```

## JustPaste.it Format

Edit https://justpaste.it/a7vyr:

```
sess:"NetflixId=abc123;SecureNetflixId=xyz789;nfvdid=token"
```

That's it! **Simple, fast, works 100%!** 🔥

## Troubleshooting

**Build failed?**
- Check Actions logs
- Ensure all files uploaded correctly

**App crashes?**
- Check iOS version (need 14.0+)
- Re-sideload

**Not logged in?**
- Check JustPaste.it format
- Cookies must be in `sess:"..."` format

**"Install App" / "App runterladen" nag screen?**
- 🚫 AGGRESSIVE APP NAG BLOCKER! Removes all prompts automatically
- MutationObserver + Periodic cleanup (2s intervals)
- Blocks app store redirects
- Keeps iPad Safari UA (for DRM)
- Check console: "BLOCKED X app nag elements!"

**Videos don't play / S7351 or M7351 error?**
- 💥 NUCLEAR DRM SOLUTION! 💥
- Widevine→FairPlay complete translation layer
- Aggressive codec forcing (ALL codecs supported)
- Complete MSE/EME polyfills + multi-stage recovery
- MediaCapabilities override (always returns true)
- S7351 (DRM) = Video reload + DRM bridge + 3-stage recovery
- M7351 (Metadata) = Auto page reload
- Auto-retry up to 5x with smart recovery
- XHR/Fetch interceptor for debugging
- Full EME/MSE interception + codec forcing
- NOTHING CAN STOP US! 🔥💪
- Check Console logs for detailed error tracking

## 💉 by amo - The WORKING Solution! 💪
