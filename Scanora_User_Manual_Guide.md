# 📘 Scanora — Official User Manual & Installation Guide

**Version:** 1.0.0 (Android Release)  
**Developer:** Jawaan Santh  
**Package Size:** ~20.1 MB (`Scanora-v1.0.0.apk`)  
**Repository:** [github.com/jawaanquizziz/Scanora](https://github.com/jawaanquizziz/Scanora)

---

## 1. Welcome to Scanora

**Scanora** is a privacy-first AI document scanner, cryptographic PDF vault, and 100% offline AI document assistant. Every scan, filter, OCR text extraction, and AI conversation happens locally on your Android phone—your private documents never touch third-party servers.

---

## 2. How to Download & Install the App (First-Time Setup)

1. **Download the APK:**
   - Download **`Scanora-v1.0.0.apk`** (or **`Scanora-Release.apk`**) from this Google Drive folder onto your Android phone.
2. **Allow Installation (If Prompted):**
   - Tap the downloaded `.apk` file.
   - If Android displays *"For your security, your phone currently isn't allowed to install unknown apps from this source"*, tap **Settings** → toggle ON **"Allow from this source"** → press Back.
3. **Install & Launch:**
   - Tap **Install** and then tap **Open**.
   - If Android Play Protect shows an "Unrecognized app developer" prompt (normal for independent APKs outside the Play Store), tap **More details** → **Install anyway**.

---

## 3. Step-by-Step Feature Guide

### 📷 Step 1: Scanning Documents & Importing Images
1. On the **Home** screen, choose one of the two primary cards:
   - **Scan Document (Camera capture):** Opens the smart camera with automatic edge detection and perspective correction.
   - **Import Images (From gallery):** Select one or multiple document photos from your phone's gallery.
2. On the **Review Screen**, you can:
   - **Add Page (`+`):** Add more camera scans or gallery images into the same multi-page PDF.
   - **Crop & Rotate:** Fine-tune the 4-point perspective corners or rotate pages by 90°.
   - **Apply Filters (`Original`, `Enhance`, `Grayscale`, `B&W`):**
     - **Single Page:** Tap any filter pill at the bottom to preview it on the current page.
     - **Batch Filter ("Apply to all pages"):** Check **`☑ Apply filter to all N pages`** (or tap the **`Apply "<Filter>" to all`** pill) to enhance every page in your document in a single tap!

---

### 🔐 Step 2: Saving with Anti-Fraud Watermarks & AES-128 Password Lock
1. Tap **`✓ Save PDF`** in the top-right corner of the Review screen.
2. In the **Save Document** sheet, customize your document:
   - **Document Name:** Give your PDF a clean title.
   - **Destination Folder:** Save to Root or pick a custom folder / Biometric Vault folder.
   - **Page Size:** Choose **A4** or **US Letter**.
   - **Anti-Fraud Watermark:** Toggle ON to stamp diagonal text (`CONFIDENTIAL`, `FOR KYC ONLY`, `DO NOT COPY`, `DRAFT`, or type your own custom text like `FOR BANK KYC ONLY`) across every page so your ID scans cannot be misused.
   - **Lock with Password:** Toggle ON and enter a password to encrypt the PDF with **standard AES-128 encryption**. The PDF will require this password even when shared on WhatsApp, Email, or Google Drive!
   - **Backup to Google Drive:** Toggle ON to automatically upload the saved PDF to your personal Google Drive.
3. Tap **Save as PDF**, then tap **Open PDF**, **Share**, or **Done**.

---

### ☁️ Step 3: Connecting Google Drive Backup & Auto-Restore
1. Open the **Settings** tab (bottom-right of the navigation bar).
2. Under **Account & Cloud Backup**, tap **`Continue with Google`** and select your Gmail account.
3. **First-Time Google Permission Note:**
   - Because Scanora is an independent open-source app, Google may show an *"App isn't verified"* screen on your very first login.
   - Simply tap **Advanced** (small link at bottom-left) → tap **Go to Scanora (unsafe)** → check the box for **"See, edit, create, and delete only the specific Google Drive files you use with this app"** → tap **Continue**.
   - *(Privacy Note: Scanora only uses the `drive.file` permission, meaning it can ONLY access the `"Scanora Documents"` folder it creates and can NEVER see or read any other files in your Google Drive!)*
4. **Automatic Reinstall Restore:**
   - Once signed in, your Google profile photo and sync progress bar appear in Settings.
   - If you ever **uninstall and reinstall Scanora** (or install it on a new phone), simply sign in with the same Google Account and tap **Sync & Restore**—all your PDFs, folders, passwords, and watermarks will automatically download back into the app!

---

### 🧠 Step 4: Using the 100% Offline AI Document Assistant
1. Open the **AI Chat** tab from the bottom navigation bar (or tap the **AI Chat** icon on any document card).
2. **Download the Offline Model (One-Time Setup):**
   - The first time you enable the neural LLM mode, Scanora downloads the compact **SmolLM2-135M GGUF** model (~100 MB) to your device. After that, it works **100% offline** (even in Airplane Mode).
   - You can also use the instant **Rule-Based Extractive Mode** immediately with zero download.
3. **Attach & Ask:**
   - Select any scanned PDF and tap quick prompts like **Summarize**, **Action Items**, or **Dates & Amounts**, or ask any custom question.
   - Tap any **📖 Page Citation** pill below the AI's answer to jump directly to that page in the PDF!

---

### 👆 Step 5: Biometric App Lock & Vault Folders
1. **Lock the Entire App:**
   - Go to **Settings → Security & Anti-Fraud → Biometric App Lock** and toggle it ON. Scanora will require your Fingerprint, Face Unlock, or PIN whenever opened.
2. **Create a Biometric Vault Folder:**
   - Go to the **Folders** tab → tap **`+ New Folder`** → enable **Lock with Biometrics (Vault)**, or long-press any existing folder to lock/unlock it.
   - Any PDF inside a Vault folder requires biometric authentication before it can be opened, shared, or modified.

---

## 4. Frequently Asked Questions (FAQ)

- **Q: Are my scanned documents visible to anyone else?**  
  **A:** No. All scans are stored in your phone's private sandbox and, if you sign in, inside your own personal Google Drive (`"Scanora Documents"`). Even if two different Gmail accounts log in on the same phone, Scanora isolates each account's files (`ownerEmail`) so one account's documents never appear or sync into another account.
- **Q: What happens if I delete the app and reinstall it later?**  
  **A:** As long as your PDFs were synced to Google Drive, signing back in with your Google Account automatically restores all your PDFs, folders, watermarks, and passwords.
- **Q: Can I add or change a password/watermark on an already-saved PDF?**  
  **A:** Yes! Tap the `⋮` menu on any document card (or the shield icon inside the PDF viewer) and select **Security, Password & Watermark** to add, update, or remove a password or watermark at any time.

