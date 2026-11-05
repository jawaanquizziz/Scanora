<div align="center">

<img src="docs/readme/banner.svg" alt="Scanora — Scan. Secure. Understand." width="100%"/>

<br/>

<a href="https://github.com/jawaanquizziz/Scanora">
  <img src="https://readme-typing-svg.demolab.com?font=Inter&weight=700&size=22&duration=3000&pause=800&color=F97316&center=true&vCenter=true&width=760&lines=Multi-page+document+scanner+with+1-tap+batch+filters;100%25+offline+on-device+AI+document+chat+(SmolLM2+GGUF);AES-128+password-locked+PDFs+%26+anti-fraud+KYC+watermarks;Biometric+fingerprint+%2F+face+vault+for+sensitive+records;Direct+backup+to+your+personal+Google+Drive" alt="Scanora Highlights"/>
</a>

<br/>

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.12-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Android](https://img.shields.io/badge/Android-5.0%2B-3DDC84?style=for-the-badge&logo=android&logoColor=white)](#-installation)
[![On-Device AI](https://img.shields.io/badge/On--Device%20LLM-SmolLM2%20GGUF-F97316?style=for-the-badge)](#-on-device-ai-document-assistant)
[![Google Drive](https://img.shields.io/badge/Google%20Drive-Cloud%20Sync-1A73E8?style=for-the-badge&logo=googledrive&logoColor=white)](#%EF%B8%8F-google-drive-cloud-backup)
[![APK Size](https://img.shields.io/badge/Release%20APK-20.1%20MB-16A34A?style=for-the-badge)](#-installation)
[![License: MIT](https://img.shields.io/badge/License-MIT-EAB308?style=for-the-badge)](LICENSE)

**[Overview](#-overview) • [Key Features](#-key-features) • [App Screens](#-app-screens) • [Google Drive Sync](#%EF%B8%8F-google-drive-cloud-backup) • [Architecture](#%EF%B8%8F-architecture) • [Tech Stack](#-tech-stack) • [Installation](#-installation)**

</div>

---

## 📖 Overview

**Scanora** is a privacy-first Android document scanner and offline AI document assistant built with **Flutter**.

Most mobile scanners lock clean exports, batch filters, and PDF encryption behind subscriptions, while cloud "Chat with PDF" tools upload sensitive personal files—such as government IDs, KYC forms, contracts, and bank statements—to external servers. **Scanora keeps the entire pipeline on your device**: camera edge detection, perspective cropping, batch image enhancement, OCR, AES-128 PDF password protection, anti-fraud watermarking, and local GGUF LLM inference all execute offline on the phone. When cloud backup is enabled, documents sync directly to a `"Scanora Documents"` folder inside **your own Google Drive**.

<div align="center">
  <img src="docs/readme/workflow.svg" alt="Capture → Enhance → Secure → Understand → Backup" width="100%"/>
</div>

---

## ✨ Key Features

<table>
<tr>
<td width="50%" valign="top">

### 📷 Multi-Page Scanning & Batch Filters
- **Automatic Edge Detection:** Powered by Google ML Kit Document Scanner with manual 4-point perspective crop.
- **Apply Filter to All Pages:** Preview **Original**, **Enhance**, **Grayscale**, or **B&W** on one page and apply it across all scanned pages in a single tap.
- **Standard PDF Export:** Generates crisp **A4** or **US Letter** PDFs with automatic cover thumbnails.

</td>
<td width="50%" valign="top">

### 🧠 100% Offline AI Document Assistant
- **Local GGUF Inference:** Runs **SmolLM2-135M Instruct (`Q4_K_M`)** on-device via `llama_cpp_dart` in a background isolate, paired with a fast rule-based NLP engine.
- **Hybrid Text Extraction:** Reads digital PDF text via Syncfusion PDF and falls back to on-device **ML Kit OCR** for camera scans.
- **Page-Level Citations:** Summarizes documents, extracts dates/amounts/action items, and links answers directly to source pages.

</td>
</tr>
<tr>
<td width="50%" valign="top">

### 🔐 Triple-Layer Document Security
- **AES-128 PDF Password Lock:** Standard cryptographic password protection (separate user and owner keys) that stays locked when shared over WhatsApp, Email, or Drive.
- **Anti-Fraud Diagonal Watermarking:** Stamp `CONFIDENTIAL`, `FOR KYC ONLY`, `DO NOT COPY`, `DRAFT`, or custom text across every page to prevent ID/KYC misuse.
- **Biometric App & Vault Lock:** Protect the app and individual Vault folders using fingerprint, face unlock, or device PIN (`local_auth`).

</td>
<td width="50%" valign="top">

### <img src="docs/readme/google_drive.svg" width="20" valign="middle"/> Personal Google Drive Backup
- **Google Account Integration:** Sign in with Google to display your connected Google profile picture, email, and live sync status.
- **Direct User-Owned Storage:** Uploads PDFs via **Google Drive REST API v3** into `"Scanora Documents"` in your own Google Drive—no third-party servers.
- **Auto-Sync & One-Tap Batch Sync:** Automatically back up newly saved scans or sync all pending documents at once.

</td>
</tr>
</table>

---

## 📱 App Screens

<div align="center">

| Home Dashboard | Multi-Page Review & Batch Filter | Save, Encrypt & Watermark |
|:---:|:---:|:---:|
| <img src="docs/screenshots/home.svg" width="250" alt="Home Screen"/> | <img src="docs/screenshots/review.svg" width="250" alt="Scanner Review Screen"/> | <img src="docs/screenshots/save.svg" width="250" alt="Save and Security Sheet"/> |
| **Offline AI Document Chat** | **Folders & Biometric Vaults** | **Settings & Google Drive Account** |
| <img src="docs/screenshots/chat.svg" width="250" alt="AI Chat Screen"/> | <img src="docs/screenshots/folders.svg" width="250" alt="Folders and Vaults Screen"/> | <img src="docs/screenshots/settings.svg" width="250" alt="Settings and Google Drive Screen"/> |

<br/>

### 🔄 End-to-End Workflow Preview

<img src="docs/screenshots/demo.svg" width="100%" alt="Scanora Workflow Demo"/>

</div>

---

## ☁️ Google Drive Cloud Backup

<img src="docs/readme/google_drive.svg" width="38" align="left" style="margin-right: 14px"/>

Scanora connects directly to **Google Drive REST API v3** using the narrow `drive.file` scope, meaning the app can only access the files it creates inside your **`"Scanora Documents"`** folder and cannot read any other personal files in your Drive.

- **Connected Account Profile:** Displays your Google profile picture, display name, email address, and a real-time counter of backed-up PDFs in **Settings** and the **Home** header.
- **Automatic & Manual Sync:** Toggle **Auto-Backup New Scans** in Settings or during PDF save, or tap **Sync Now** to upload all unsynced documents in a single batch.
- **Preserves Encryption & Watermarks:** Password-locked and watermarked PDFs are uploaded in their encrypted/stamped state.

---

## 🧠 On-Device AI Pipeline

```mermaid
flowchart LR
    A["📄 Scanned PDF"] --> B{"Has Digital Text?"}
    B -- Yes --> C["Syncfusion PDF Extractor"]
    B -- No --> D["Google ML Kit On-Device OCR"]
    C --> E["Document Chunking Service"]
    D --> E
    E --> F["Keyword & Context Retrieval"]
    F --> G["SmolLM2-135M GGUF (llama.cpp)<br/>+ Rule-Based Extractive NLP"]
    G --> H["💬 Answer + Clickable Page Citations"]
```

---

## 🏗️ Architecture

```mermaid
flowchart TB
    subgraph UI["Presentation Layer (Flutter / Material 3)"]
        Home["Home Screen"]
        Scanner["Scanner & Batch Filter Review"]
        Docs["My Scans & PDF Viewer"]
        Folders["Folders & Biometric Vaults"]
        Chat["Offline AI Document Chat"]
        Settings["Settings & Google Drive Profile"]
    end

    subgraph SVC["Core Services Layer"]
        PDF["PdfService (A4/Letter, AES-128, Watermark)"]
        IMG["ImageService (Crop, Rotate, Batch Filters)"]
        BIO["BiometricService (local_auth)"]
        DRV["GoogleDriveService (OAuth 2.0 + Drive v3)"]
        STO["StorageService (SharedPreferences + Sidecars)"]
        AI["OnDeviceAiService (OCR + RAG + GGUF Isolate)"]
    end

    subgraph NATIVE["On-Device Native Engines"]
        MLK["Google ML Kit (Document Scanner & OCR)"]
        LLM["llama_cpp_dart (SmolLM2-135M GGUF)"]
        AUTH["Android BiometricPrompt"]
    end

    CLOUD[("User's Personal Google Drive\n'Scanora Documents' Folder")]

    UI --> SVC
    IMG --> MLK
    AI --> MLK
    AI --> LLM
    BIO --> AUTH
    DRV --> CLOUD
```

<details>
<summary><b>📂 Repository Directory Structure</b></summary>

```text
Scanora/
├── android/                  # Gradle Kotlin DSL, Firebase google-services.json, AndroidManifest
├── docs/
│   ├── readme/               # Animated SVG banner, workflow diagram, Google Drive vector logo
│   └── screenshots/          # App screen renders (home, review, save, chat, folders, settings, demo)
├── lib/
│   ├── main.dart / app.dart  # Entry point & adaptive Material 3 theme setup
│   ├── core/
│   │   ├── theme/            # AppColors, AppTheme (Light & Dark)
│   │   ├── utils/            # Date formatting & file size/name utilities
│   │   └── widgets/          # GoogleDriveLogo, GoogleAccountAvatar, CustomDialogs, Thumbnails
│   ├── features/
│   │   ├── splash/           # Animated launch screen
│   │   ├── shell/            # MainNavigationShell + Biometric lock overlay
│   │   ├── home/             # Quick actions, Drive status banner, recent scans
│   │   ├── scanner/          # Capture, Crop, FilterScreen, PageReviewScreen (Apply to All), SaveDialog
│   │   ├── documents/        # Searchable/sortable PDF library & in-app PDF viewer
│   │   ├── folders/          # Color-coded folders & Biometric Vault locking
│   │   ├── chat/             # Hybrid OCR/PDF extraction, chunking, retrieval, SmolLM2 GGUF isolate
│   │   └── settings/         # Google Drive profile & sync, Biometric lock, Watermark defaults
│   ├── models/               # ScannedDocument, DocumentFolder, ScanPage, AppSettings
│   └── services/             # PdfService, ImageService, GoogleDriveService, BiometricService, StorageService
└── pubspec.yaml
```

</details>

---

## 🧰 Tech Stack

| Category | Technology | Purpose |
| :--- | :--- | :--- |
| **Mobile Framework** | **Flutter 3.x & Dart 3.12** | Cross-platform UI compiled to native ARM64 machine code |
| **On-Device LLM** | **`llama_cpp_dart` + `SmolLM2-135M-Instruct (Q4_K_M GGUF)`** | Offline LLM inference inside a background Dart isolate |
| **Computer Vision & OCR** | **`google_mlkit_document_scanner` & `google_mlkit_text_recognition`** | Edge detection, perspective correction, and offline text recognition |
| **PDF & Cryptography** | **`syncfusion_flutter_pdf`, `pdf`, `printing`** | Multi-page PDF generation, AES-128 password encryption, diagonal watermarks |
| **Image Processing** | **`image` (`^4.12.0`) & `image_picker`** | Batch filters (Enhance, Grayscale, B&W), cropping, rotation, thumbnails |
| **Biometric Security** | **`local_auth` (`^3.0.2`)** | Fingerprint, Face Unlock, and PIN protection for app & vault folders |
| **Cloud & Auth** | **`google_sign_in`, Firebase Auth, Google Drive REST API v3 (`http`)** | Google account profile & direct PDF backup to `"Scanora Documents"` |
| **Persistence** | **`shared_preferences` & `path_provider`** | Local document metadata, folder state, and chat history |

---

## ⚡ Installation

### Option 1 — Install the Prebuilt Release APK (~20 MB)

1. Download **`Scanora-Release.apk`** from the repository root or the [**Releases**](https://github.com/jawaanquizziz/Scanora/releases) tab.
2. Transfer it to your Android device and open it to install.

### Option 2 — Build from Source

```bash
# 1. Clone the repository
git clone https://github.com/jawaanquizziz/Scanora.git
cd Scanora

# 2. Install Flutter dependencies
flutter pub get

# 3. Run in debug mode on a connected device
flutter run

# 4. Build optimized split-ABI release APKs (~20 MB)
flutter build apk --release --split-per-abi
```

---

## 🆚 Comparison with Existing Solutions

| Capability | Traditional Scanner Apps | Cloud "Chat with PDF" Tools | **Scanora** |
| :--- | :---: | :---: | :---: |
| **Clean PDFs (No Brand Watermarks)** | ❌ Paid | — | ✅ **100% Free** |
| **Apply Filter to All Pages (Batch)** | 💰 Paid Pro | — | ✅ **Built-in (1-Tap)** |
| **AI Summarization & Document Q&A** | 💰 Cloud Subscription | ☁️ Uploads Private PDFs | ✅ **100% Offline On-Device** |
| **AES-128 PDF Password Encryption** | 💰 Paid Pro | ❌ | ✅ **Built-in** |
| **Anti-Fraud KYC Diagonal Watermarks** | 💰 Paid Pro | ❌ | ✅ **Presets + Custom Text** |
| **Biometric App & Folder Vault** | Limited | ❌ | ✅ **Fingerprint / Face / PIN** |
| **Cloud Backup Destination** | Vendor Cloud | Vendor Server | ✅ **User's Own Google Drive** |

---

## 🚀 Future Scope

- [ ] **Multi-Language & Handwritten OCR:** Add Devanagari (Hindi/Marathi), Tamil, Telugu, and handwriting recognition models.
- [ ] **Digital Signatures & Form Filling:** Draw or import cryptographic e-signatures directly onto PDF pages.
- [ ] **Multi-Document Folder RAG:** Query across an entire folder of invoices or medical reports simultaneously.
- [ ] **Smart Expense & Table Export:** Extract receipt tables into Excel/CSV spreadsheets automatically.
- [ ] **Cross-Platform Desktop & iOS Sync:** Expand builds to iOS, Windows, and macOS synced via Google Drive.

---

## 📄 License

Distributed under the **MIT License**. See [`LICENSE`](LICENSE) for full details.

---

<div align="center">

Built with Flutter by **[Jawaan Santh](https://github.com/jawaanquizziz)**

<img src="https://capsule-render.vercel.app/api?type=waving&color=0:EA580C,100:EF4444&height=100&section=footer" width="100%"/>

</div>
