# Genius — pocket companion (iOS)

A personal iOS app, built on Windows (no Mac required) via cloud CI and sideloaded
to an iPhone. This README covers the build + install loop.

## How this works

1. **Code lives here on GitHub.** Claude writes it and pushes for you.
2. **GitHub Actions** compiles it on a macOS runner and produces an **unsigned `.ipa`**
   (see `.github/workflows/ios.yml`). You never need a Mac.
3. **You install the `.ipa`** onto the iPhone from Windows with **Sideloadly** + a
   **free Apple ID**. Free-ID signatures last **7 days**, so re-run Sideloadly weekly.

## Getting the build (after each push)

1. Open the repo on GitHub → **Actions** tab → click the latest run.
2. Wait for it to go green, then download the **`Genius-unsigned-ipa`** artifact (bottom of the run page).
3. Unzip it — inside is `Genius-unsigned.ipa`.

## Installing on the iPhone (Windows)

1. Install **Sideloadly** from https://sideloadly.io (Windows).
2. Plug the iPhone in via USB (trust the computer on the phone).
3. In Sideloadly: drag in `Genius-unsigned.ipa`, enter your **Apple ID**, click **Start**.
   (Use a free Apple ID; an app-specific password may be requested.)
4. On the iPhone: **Settings → General → VPN & Device Management** → tap your Apple ID →
   **Trust**. The app will now launch.
5. **Weekly:** repeat steps 2–3 to refresh the 7-day signature.

> Optional upgrades: **AltStore/SideStore** auto-refresh the signature in the background;
> a **$99/yr Apple Developer account** removes the weekly refresh and the 3-app limit.

## Project layout

- `project.yml` — XcodeGen spec (defines the app; the `.xcodeproj` is generated in CI).
- `Sources/` — Swift source.
- `.github/workflows/ios.yml` — the cloud build.

## Milestones

- [x] **M0** — empty app builds, installs, runs.
- [ ] **M1** — type a question → short on-device answer.
- [ ] **M2** — live microphone transcription.
- [ ] **M3** — transcribe → answer → duck music + speak (TTS) + notification.
- [ ] Later — background listening, 30s–5min recall slider, web search, triggers, auto mode.
