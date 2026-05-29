# Genius — Project Notes & Dev Log

A personal iOS "genius companion": it listens to the conversation around you, and on
demand (or automatically) feeds you a short, smart answer — spoken into your headphones
and/or shown as a notification. On-device model + free web search. First-time iOS project,
built entirely from a **Windows PC** with **no usable Mac**.

---

## 1. The concept

- Continuously transcribes nearby speech on-device.
- **Manual mode:** you trigger it (button / headphone play-pause / Action Button / Back-Tap);
  it recalls the last *N* seconds of conversation (slider: 30 s–5 min), answers briefly, and:
  - **headphones connected** → speaks the answer (TTS) **and** posts a notification,
  - **no headphones** → notification only.
- **Auto mode (basic):** when it hears a question (sentence ending in "?"), it answers on its own.
- Answers are short and direct — designed to make you sound like a genius.
- Background music is **ducked (quieted), never paused**, while it speaks.
- Minimal styling.

---

## 2. Constraints we discovered (and how we worked around them)

| Reality | Impact | Resolution |
|---|---|---|
| Dev machine is **Windows** | Can't compile iOS apps locally (needs macOS/Xcode) | Build in the **cloud** via GitHub Actions |
| The Mac is a **2019 model on macOS Catalina** | Maxes at Xcode 12 (iOS 14 SDK); can't target iOS 26; user won't update it | **Don't use the Mac at all** — cloud CI uses Xcode 26 |
| Phone is **iPhone Air on iOS 26** | Very capable (A19 Pro, Apple Intelligence) | Lets us use Apple's built-in on-device model + iOS 26 SDK |
| Want it **free to run** | No paid APIs, no $99 dev account (yet) | Free Apple ID signing + free CI + free/keyless web search |
| Personal use only | No App Store review to satisfy | Free to use background mic, etc. |

> **Legal note:** recording people without consent can be illegal in some places. This is a
> personal/sideloaded app; be mindful of where and on whom you use it.

---

## 3. Build & deploy pipeline (no Mac required)

```
 Windows PC                     GitHub                   GitHub Actions (rented macOS)        iPhone Air
 ─────────                      ──────                   ────────────────────────────        ──────────
 Claude writes Swift  ─push→    72ak/genius     ─CI→     Xcode 26 builds UNSIGNED .ipa   ─→   Sideloadly signs
 (via gh CLI)                   (public repo)            (uploaded as an artifact)            with FREE Apple ID
                                                                                              → install → Trust
```

- **Repo:** https://github.com/72ak/genius (public → free macOS CI minutes).
- **CI:** `.github/workflows/ios.yml` — selects latest Xcode, runs `xcodegen generate`,
  archives **unsigned**, packages an `.ipa`, uploads it as the `Genius-unsigned-ipa` artifact.
- **Project generation:** `project.yml` (XcodeGen) → the `.xcodeproj` is generated in CI, never committed.
- **Signing/install:** **Sideloadly** (Windows) signs the unsigned `.ipa` with a **free Apple ID**
  and installs over USB. Free-ID signatures **expire after 7 days** → re-run Sideloadly weekly.
  - One-time on the phone: **Developer Mode** on (Settings ▸ Privacy & Security), and **Trust**
    the developer profile (Settings ▸ General ▸ VPN & Device Management).
  - Optional upgrades: AltStore/SideStore auto-refresh; a $99/yr Apple Developer account removes
    the weekly refresh and the 3-app limit.

### To ship a new build
Claude pushes to `main` → CI builds automatically → download the artifact (already automated to
`./ipa-out/…`) → Sideload it. (Build takes ~30–45 s.)

---

## 4. Architecture (Swift / SwiftUI, iOS 26)

All source in `Sources/`. The "brain" is swappable behind a protocol.

| File | Role |
|---|---|
| `GeniusApp.swift` | App entry; foreground-notification delegate. |
| `ContentView.swift` | Minimal UI: live/accumulating transcript, recall slider, toggles, "Answer now", latest answer. |
| `AppModel.swift` | Orchestrator (singleton). Permissions, listen→recall→search→answer→speak/notify, route changes, triggers. |
| `Transcriber.swift` | Continuous on-device transcription (`SFSpeechRecognizer`). Restarts instantly when a phrase finalizes (so it never stops listening after a pause), plus a 45 s safety recycle; exposes live + accumulated transcript. |
| `TranscriptBuffer.swift` | Timestamped rolling buffer (~6 min); serves "last N seconds" for recall. |
| `AnswerProvider.swift` | `AnswerProvider` protocol + persona instructions + unavailable fallback. |
| `FoundationModelsProvider.swift` | Brain = Apple's on-device model (`FoundationModels`, iOS 26), guarded by `#if canImport`. |
| `LocalQwenProvider.swift` | Local open-weight Qwen target: `Qwen/Qwen3.6-27B`. Scaffold only until an iOS inference runtime + quantized model file are added. |
| `WebSearch.swift` | Free, keyless lookups: DuckDuckGo Instant Answers + Wikipedia **full-text** search; pulls a query from the transcript. Fetched facts are shown on screen (🔎). |
| `AudioSessionManager.swift` | `.playAndRecord` + `.mixWithOthers` (music keeps playing), `.duckOthers` only while speaking; forces **built-in mic** for room pickup; A2DP output to AirPods. |
| `AudioOutput.swift` | TTS (`AVSpeechSynthesizer`); ducks others while talking; a new answer immediately interrupts one that's still playing. |
| `Notifier.swift` | Local notification with the answer. |
| `RemoteControl.swift` | Headphone/lock-screen play-pause → trigger (claims Now-Playing). |
| `AskGeniusIntent.swift` | App Intent + App Shortcut for Action Button / Back-Tap / Siri. |

### Key design choices
- **On-device model first** (no API key, low latency, private), pluggable so Apple Foundation
  Models can be replaced by a local open-weight model.
- **Local Qwen target:** latest open-weight target is `Qwen/Qwen3.6-27B` (Apache-2.0). It is not
  active yet because the app still needs an iOS inference runtime and a quantized model bundle.
- **Manual retrieval** for web search (search → inject facts into the prompt) instead of the model's
  tool-calling API — more reliable.
- **Built-in mic, not AirPods mic** — AirPods mic is tuned for the wearer up close; the phone mic
  (with auto-gain) picks up the room/distant speakers better. TTS still plays in the AirPods.
- **Persona prompt** returns **bullet points only** (1–4), bans filler ("Well", "Great question",
  "I think", "Let me…"), and leads with the answer/key fact.

---

## 5. Features implemented

- [x] Continuous on-device transcription (accumulating, timestamped); **restarts instantly after a pause** so it never goes deaf.
- [x] Recall window slider (30 s–5 min).
- [x] On-device "genius" answers via Apple's Foundation Models — **bullet points only**, no filler.
- [x] Local Qwen mode scaffolded for `Qwen/Qwen3.6-27B` (runtime/model bundle still pending).
- [x] Free web search (Wikipedia full-text + DuckDuckGo) feeding the model; toggleable; **fetched facts shown on screen** (🔎) for transparency.
- [x] TTS to headphones when connected; notification always; music ducked not paused.
- [x] A new answer **interrupts/replaces** one that's still playing.
- [x] Triggers: in-app button, headphone play/pause, Action Button / Back-Tap / Siri (App Intent).
- [x] Basic auto mode (answers on a heard "?").
- [x] Built-in-mic routing for better distance pickup.

---

## 6. How to test on the phone

1. Sideload the latest `.ipa` from `./ipa-out/…`. Launch, **allow mic + speech + notifications**.
   - If "model isn't ready": Settings ▸ Apple Intelligence & Siri ▸ turn on.
2. **Bind a trigger (one-time):** launch the app once so the shortcut is indexed, then:
   - **Action Button:** Settings ▸ Action Button ▸ Shortcut ▸ *Ask Genius*.
   - **Back-Tap:** Settings ▸ Accessibility ▸ Touch ▸ Back Tap ▸ Double Tap ▸ *Ask Genius*.
3. Check: transcript **accumulates** (doesn't reset each sentence); ask a factual question and
   tap/trigger → short answer + notification; with AirPods, you hear it and music ducks; distant
   speech (phone on table) is picked up.

---

## 7. Known limitations / tradeoffs

- **Headphone button** only reaches the app when it owns "Now Playing", so while enabled it takes
  the play/pause button from your music (music keeps playing; pause it from the music app). Action
  Button / Back-Tap avoid this entirely.
- **Distance pickup** is best with the phone out on a table; in a pocket it's muffled. There's no
  true "sensitivity" dial in iOS speech recognition.
- **Background listening** uses the audio background mode; long-running reliability isn't fully
  verified yet.
- **Small on-device model** — strong for reasoning/short answers, weaker on niche/recent facts;
  web search fills some gaps. DuckDuckGo/Wikipedia won't do live scores/breaking news.
- **Local Qwen is not runnable yet** — `Qwen3.6-27B` is much larger than Apple's built-in model.
  Running it on iPhone needs a quantized build plus a native runtime such as llama.cpp/MLC.
- **Weekly re-sign** with a free Apple ID; 3-app sideload limit.
- **CI maintenance:** GitHub is deprecating Node 20 actions (forced Node 24 on 2026-06-02, removed
  2026-09-16). Bump `actions/checkout` and `actions/upload-artifact` before then.

---

## 8. Possible next steps

- Smarter **auto mode**: silence/pause detection (VAD), better question detection.
- **Avoid transcribing its own TTS** (pause recognition while speaking).
- Wire a native runtime for **local Qwen** (likely llama.cpp or MLC), choose a GGUF/MLC
  quantization, and decide whether the model is bundled or imported on-device.
- Stronger search via a **Brave/Tavily** key (still free tier) when desired.
- Verify/strengthen **background listening**; consider a Live Activity for quick triggering.
- Nicer TTS voice; per-answer "copy/share".

---

## 9. Quick reference

- **Repo:** `72ak/genius` (public)
- **Build artifact:** GitHub Actions → `Genius-unsigned-ipa` → auto-downloaded to `./ipa-out/`
- **Install:** Sideloadly + free Apple ID (re-sign weekly)
- **Targets:** iOS 26, iPhone Air; built with Xcode 26 in CI
- **Bundle ID:** `com.akash.genius`
