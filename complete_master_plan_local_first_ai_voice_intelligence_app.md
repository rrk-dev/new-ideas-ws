# Local-First AI Voice Intelligence App (`OmniScribe` / `VaultVoice`)
## Comprehensive Business, Architectural & Technical Master Plan

---

## 1. Executive Summary & Vision Statement

### Vision Statement
To empower privacy-conscious professionals, developers, consultants, and enterprise power-users with an offline-first, local-AI audio processing engine that transforms unstructured ambient audio into structured, actionable, and local Markdown documentation without ever sending byte zero of data to a cloud server.

### Value Proposition
Unlike cloud-dependent transcription tools (e.g., Otter.ai, Fireflies.ai) that charge heavy monthly subscriptions to store user data on third-party servers, **VaultVoice** turns modern mobile hardware (NPU/GPU) into a private intelligence vault. It records, transcribes, categorizes, and routes structured Markdown files directly into local directories or vaults (e.g., Obsidian, Logseq, local filesystems) using quantized on-device AI.

---

## 2. Market Analysis & Strategic Positioning

### 2.1 Macro Market Dynamics
1. **The Edge AI Realignment:** Modern mobile chips (Apple A17 Pro/A18/M-series and Snapdragon 8 Gen 3/4) possess dedicated Neural Processing Units (NPUs) capable of running quantized 3B–8B parameter models locally at 20+ tokens/second.
2. **Data Sovereignty & Privacy Mandates:** Regulated fields (Legal, Medical, Finance, Defense) and privacy-focused power users have zero tolerance for cloud voice-recording tools due to HIPAA, GDPR, and enterprise NDA constraints.
3. **The "Local-First" & Markdown Movement:** Millions of knowledge workers use local-first tools (Obsidian, PKM vaults, Git-backed folders) and demand software that outputs standard, plain-text formats rather than locking data in proprietary databases.

### 2.2 Competitive Matrix

| Feature / Criteria | Cloud Competitors (Otter, Fireflies) | OS Built-in (Apple Intelligence) | **VaultVoice (Our Solution)** |
| :--- | :--- | :--- | :--- |
| **Privacy & Security** | Low (Data processed/stored in cloud) | Medium (Private Cloud Compute fallback) | **Maximum (100% Offline / Local)** |
| **Data Ownership** | Proprietary Cloud Silo | Native Notes / Basic Apps | **Direct Local Directory / Markdown** |
| **Custom Structuring** | Generic summaries | Basic auto-summaries | **Domain Extraction Profiles (Warranties, Sprint Notes, Legal)** |
| **Monetization Model** | High Monthly SaaS ($10–$30/mo) | Free (OS Locked) | **Fair One-time / Pro License + Enterprise Seats** |
| **Cross-Platform** | Web / Mobile (Cloud dependent) | iOS / macOS Only | **iOS & Android Parity (Local Flutter Engine)** |

---

## 3. Core Feature Specifications & User Experience

### 3.1 Feature Architecture Overview
1. **Background Audio Capture & Streaming:** Low-latency recording with pause, resume, auto-gain control, and dynamic silence detection.
2. **On-Device Whisper STT:** Local audio-to-text processing running quantized Whisper models (e.g., Whisper.cpp / ExecuTorch).
3. **Local LLM Engine & Context Routing:** Dynamic prompt execution using quantized models (e.g., Llama 3.2 3B Q4 / Gemma 2B) running via llama.cpp mobile bindings.
4. **Local Directory & Vault Exporter:** Configurable target paths (e.g., `/Obsidian/Vault/Work/`, `/Documents/Warranties/`) with custom file templates (`YYYY-MM-DD-Meeting-Topic.md`).
5. **Domain Extraction Profiles (Skills):**
   * **Meeting Action Items:** Extracts attendees, key decisions, assigned tasks with checkboxes, and open questions.
   * **Warranty & Receipt Logger:** Extracts product name, purchase date, serial number, warranty period, and support contacts.
   * **Engineering / Brainstorming:** Extracts architectural concepts, API designs, trade-offs, and immediate TODOs.

---

## 4. Software Architecture & Technology Stack

### 4.1 Cross-Platform Mobile Stack
* **Framework:** **Flutter** (Dart) for unified single-codebase iOS & Android performance.
* **State Management:** **Riverpod** for robust, testable state management.
* **Local Database:** **Isar** or **SQLite** (for indexing metadata, task status, and profile rules).
* **Audio Engine:** `record` package with native bindings for high-fidelity WAV/m4a encoding.

### 4.2 On-Device AI Engine Layer

```
+-----------------------------------------------------------------------+
|                             FLUTTER UI                                |
+-----------------------------------------------------------------------+
                                    |
                            (FFI / C++ Bridge)
                                    |
        +---------------------------+---------------------------+
        |                                                       |
        v                                                       v
+-------------------------------+               +-------------------------------+
|       WHISPER.CPP / ONNX      |               |      LLAMA.CPP / EXECUTORCH   |
|   (Audio -> Raw Transcript)   |               |   (Transcript -> Markdown)    |
+-------------------------------+               +-------------------------------+
        |                                                       |
        +---------------------------+---------------------------+
                                    |
                                    v
                  +-----------------------------------+
                  |   LOCAL FILE ROUTER & VAULT WRITER|
                  |     (Outputs .md to File System)  |
                  +-----------------------------------+
```

* **Speech-to-Text (STT):** `whisper.cpp` compiled as a native shared library (`.so` for Android, `.framework` for iOS). Uses `whisper-small.en` or `whisper-base.en` (quantized Q4/Q8).
* **Language Model (LLM Inference):** `llama.cpp` mobile bindings or **ExecuTorch / MLC-LLM**. Runs GGUF quantized models:
  * **Primary Model:** Llama-3.2-3B-Instruct (Q4_K_M) or Gemma-2B-IT.
* **Hardware Acceleration:**
  * **iOS:** Metal / CoreML backend integration.
  * **Android:** Vulkan / OpenCL / NPU delegates via Android NNAPI.

---

## 5. Step-by-Step Implementation Roadmap

### Phase 1: Foundation & Audio Pipeline (Weeks 1–3)
- [ ] Initialize Flutter repository with strict code style guidelines.
- [ ] Implement robust local audio recording service (`.wav` audio format, 16kHz mono).
- [ ] Integrate file picker permissions to access external storage directories (Scoped Storage on Android, Document Picker / Security Scoped Bookmarks on iOS).

### Phase 2: On-Device STT & LLM Integration (Weeks 4–7)
- [ ] Compile `whisper.cpp` C++ bindings for iOS (Metal) and Android (Vulkan/NDK).
- [ ] Create dynamic model downloader to fetch quantized Whisper and Llama models on first launch (avoiding bloated app store binary sizes).
- [ ] Benchmark transcription speed and battery impact; optimize chunking for audio streams over 15 minutes.
- [ ] Integrate `llama.cpp` FFI interface to execute local context prompts on completed transcripts.

### Phase 3: Dynamic Extraction Profiles & Markdown Generator (Weeks 8–10)
- [ ] Implement system prompt builder for specific domain skills (Meetings, Warranties, Brainstorms).
- [ ] Build customizable Markdown template engine using Handlebars/Mustache.
- [ ] Implement file system synchronization writing directly to user-selected folders.

### Phase 4: UX Polish, Testing & Launch (Weeks 11–12)
- [ ] Conduct performance stress tests on budget devices (e.g., iPhone 11, Snapdragon 7-series).
- [ ] Implement background processing guardrails (handling iOS background task limitations).
- [ ] Prepare app store media assets, privacy policies, and release build pipelines.

---

## 6. Marketing Plan, Positioning & Pitch

### 6.1 Positioning Strategy
* **Tagline:** *"Your Voice. Your Hardware. Your Vault."*
* **Core Value Prop:** The 100% offline AI voice assistant that turns conversations into structured Markdown files directly in your local folders.
* **Primary Target Audiences:**
  1. **PKM / Obsidian Power Users:** Developers, researchers, and writers who manage personal knowledge bases locally.
  2. **Corporate & Tech Consultants:** Professionals under strict NDAs who cannot upload meeting recordings to the cloud.
  3. **Legal & Healthcare Practitioners:** Field professionals requiring offline-first compliance.

### 6.2 Elevator Pitch (30 Seconds)
> "Cloud meeting bots like Otter record your private conversations and upload them to third-party servers while charging you $20 every single month. **VaultVoice** changes the game. It uses your phone's built-in GPU to transcribe and extract action items, warranty notes, and meeting summaries completely offline. It automatically formats and drops ready-to-use Markdown files straight into your Obsidian vault or local project folders. Zero subscriptions, zero cloud uploads, 100% privacy."

---

## 7. Pricing Model & Monetization Strategy

To align with the local-first ethos while securing long-term revenue:

1. **Free Tier (Community Edition):**
   * Core recording and local transcription using small/tiny Whisper models.
   * Standard meeting summary export.
2. **Pro License (One-Time Purchase or Low Annual License - $29.99/year or $49.99 Lifetime):**
   * Access to high-accuracy Whisper models and 3B+ parameter local LLM extraction.
   * Custom Markdown template engine.
   * Unlimited domain extraction profiles (Warranties, Sprint Planning, Legal).
   * Multiple local folder routing rules.
3. **Enterprise / B2B Seats ($10/user/month):**
   * Pre-configured enterprise extraction templates.
   * Centralized local license management without cloud analytics tracking.