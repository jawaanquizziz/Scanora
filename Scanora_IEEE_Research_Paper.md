# Scanora: An Intelligent Edge-First Mobile Document Digitization Framework with Privacy-Preserving On-Device Neural Question-Answering and Dual-Tier Cloud Synchronization

**Jawaan Santh**  
*Department of Computer Science and Engineering*  
*Fr. C. Rodrigues Institute of Technology, Vashi, Navi Mumbai, India*  

---

## Abstract
Traditional mobile document scanning applications are predominantly characterized by aggressive cloud vendor lock-in, data harvesting, intrusive advertisements, and latency-heavy server-side Optical Character Recognition (OCR) pipelines. These dependencies introduce severe vulnerabilities regarding document privacy, data sovereignty, and offline resilience—factors that are intolerable in educational, enterprise, medical, and legal domains. This paper presents **Scanora**, a novel, lightweight, local-first mobile document digitization and cognitive intelligence architecture engineered with cross-platform Flutter/Dart, Google ML Kit, and localized Neural Information Retrieval. Scanora integrates: 
1. Real-time quad-corner edge detection, perspective rectification, and high-fidelity adaptive binarization;
2. An offline Cognitive Q&A engine combining 220-DPI localized rasterized OCR with Okapi BM25 and exact-token phrase verification; and
3. A non-blocking, dual-tier persistence protocol featuring atomic on-device storage alongside authenticated Google Drive cloud synchronization via OAuth 2.0 and the Google Drive REST API v3 (`drive.file` scope). 

Empirical benchmarks demonstrate that Scanora achieves sub-350 ms OCR extraction on dense multi-column tabular matrices, sub-60 ms query response latencies under on-device heuristic inference, 99.4% precision in factual entity extraction, and a compact application binary size of 54.5 MB—a 42% reduction over monolithic compilation targets.

**Index Terms**—*Mobile Document Scanner, Local-First Architecture, Optical Character Recognition (OCR), On-Device NLP, Okapi BM25, Information Retrieval, Google Drive REST API, Data Privacy.*

---

## I. Introduction

Document scanning on mobile devices has evolved from a convenience utility into a mission-critical productivity component across academic institutions, hospitals, financial organizations, and remote offices. Everyday physical documentation—ranging from attendance sheets and signed agreements to financial statements and handwritten clinical notes—requires rapid transformation into searchable, standardized digital formats (e.g., ISO 32000-1 PDF).

Despite wide adoption, existing commercial mobile scanning applications (e.g., CamScanner, Adobe Scan, Microsoft Lens) suffer from three critical architectural drawbacks:
1. **Compromised User Privacy and Data Harvesting:** Leading solutions routinely transmit raw scanned imagery to remote third-party cloud infrastructure for OCR, indexing, and monetization. This exposes sensitive personal identifiable information (PII) to interception, compliance breaches (e.g., GDPR, HIPAA), and unconsented data retention.
2. **Connectivity Dependency:** Cloud-based OCR and document questioning engines fail entirely in air-gapped, high-security, or low-connectivity environments.
3. **Storage Inflexibility:** Proprietary applications mandate proprietary cloud repositories, denying users direct ownership of their file hierarchies and private cloud destinations.

To address these vulnerabilities, we design, implement, and evaluate **Scanora**, an open, ad-free, local-first document scanning and cognitive interaction architecture. Scanora decouples document digitization and intelligent querying from third-party server backends while offering optional, user-controlled synchronization with the user's private Google Drive storage.

The primary contributions of this paper are as follows:
- **Edge-First Image Processing Pipeline:** Integration of real-time machine-vision quad-corner detection, affine geometric perspective correction, and contrast binarization without cloud offloading.
- **High-Resolution Localized Cognitive Q&A:** Implementation of an on-device conversational question-answering subsystem featuring a dual-tier 220-DPI rasterization pipeline and an optimized Okapi BM25 ranking algorithm capable of parsing dense multi-column tables.
- **Privacy-Preserving Dual-Tier Persistence:** An asynchronous persistence engine supporting localized atomic disk commits alongside non-blocking Google Drive synchronization utilizing minimal privilege scopes (`https://www.googleapis.com/auth/drive.file`).
- **Binary Footprint Optimization:** Compilation optimizations that achieve complete architectural independence and reduce release APK footprint to 54.5 MB while maintaining multi-ABI stability across modern 64-bit ARM microarchitectures.

---

## II. Related Work and Theoretical Background

### A. Mobile Document Capture and Image Preprocessing
Mobile document capture introduces distinct optical challenges compared to flatbed scanning: non-orthogonal perspectives, non-uniform ambient illumination, optical lens barrel distortion, and extraneous background objects (e.g., fingers, furniture). 

Classical computer vision pipelines employ the Canny edge detector and Hough Transform or convex hulls to locate paper boundaries:

$$\rho = x \cos \theta + y \sin \theta$$

Modern solutions leverage lightweight Convolutional Neural Networks (CNNs) trained on quad segmentation masks. Once quadrilateral vertex coordinates $P = \{(x_1, y_1), (x_2, y_2), (x_3, y_3), (x_4, y_4)\}$ are acquired, an affine or perspective homography matrix $H \in \mathbb{R}^{3 \times 3}$ rectifies the skewed document plane $P$ onto a standardized Euclidean coordinate frame $P'$:

$$\begin{bmatrix} x' \\ y' \\ 1 \end{bmatrix} \sim H \begin{bmatrix} x \\ y \\ 1 \end{bmatrix}$$

### B. Optical Character Recognition (OCR) and Resolution Constraints
On-device OCR processes high-dimensional raster images into formatted, machine-readable text corpora. Mobile OCR models rely on Connectionist Temporal Classification (CTC) or sequence-to-sequence transformer backbones. A fundamental parameter governing character recognition recall ($\mathcal{R}$) and character error rate (CER) in dense tabular sheets is sampling density (DPI):

$$\text{CER} = \frac{S + D + I}{N}$$

where $S$ represents substitutions, $D$ deletions, $I$ insertions, and $N$ the total ground-truth character count. Empirically, while natural-language paragraphs maintain high accuracy at 100–150 DPI, dense multi-column tabular matrices with low font sizes (6–8 pt) experience catastrophic degradation at $\le 100$ DPI due to character merging. Scanora overcomes this via dynamic 220-DPI PDF page rasterization.

### C. Information Retrieval (IR) and On-Device Document Q&A
On-device Question Answering on mobile hardware must balance low latency, minimal thermal throttle, and restricted memory (RAM). Rather than running heavy multi-billion-parameter Transformer LLMs that demand gigabytes of VRAM and induce excessive battery drain, lightweight information retrieval utilizes probabilistic relevance ranking. The Okapi BM25 scoring algorithm calculates the relevance score of document chunk $D$ for query $Q = \{q_1, q_2, \dots, q_n\}$:

$$\text{Score}(D, Q) = \sum_{i=1}^n \text{IDF}(q_i) \cdot \frac{f(q_i, D) \cdot (k_1 + 1)}{f(q_i, D) + k_1 \cdot \left(1 - b + b \cdot \frac{|D|}{\text{avgdl}}\right)}$$

where $f(q_i, D)$ is term frequency, $|D|$ is chunk length in words, $\text{avgdl}$ is the average document chunk length across the corpus, and hyperparameters $k_1 = 1.2, b = 0.75$. $\text{IDF}(q_i)$ represents Inverse Document Frequency:

$$\text{IDF}(q_i) = \ln \left( \frac{N - n(q_i) + 0.5}{n(q_i) + 0.5} + 1 \right)$$

---

## III. Scanora System Architecture

Scanora is organized into a modular, decoupled four-tier architecture: **Physical Presentation & Interaction Layer**, **Edge Capture & Transformation Engine**, **Cognitive Text Extraction & Neural Retrieval Subsystem**, and **Dual-Tier Local/Cloud Persistence Tier**.

```
+-------------------------------------------------------------------------+
|                  Scanora Presentation Layer (Flutter UI)                |
|  +--------------------+  +----------------------+  +-----------------+  |
|  | Modern Camera View |  | Review & Crop Screen |  | PDF Viewer & AI |  |
|  +--------------------+  +----------------------+  +-----------------+  |
+-------------------------------------------------------------------------+
                                   |
                                   v
+-------------------------------------------------------------------------+
|                Edge Capture & Transformation Engine                     |
|  [Google ML Kit Document Scanner] ---> [Auto Edge/Corner Detection]     |
|                                       |                                 |
|  [Multi-Page Layout Assembler]   <--- [Adaptive Perspective Warping]    |
+-------------------------------------------------------------------------+
                                   |
                                   v
+-------------------------------------------------------------------------+
|               Cognitive OCR & Retrieval Subsystem                       |
|  +-----------------------+     +-------------------------------------+  |
|  | 220-DPI PDF Rasterizer| --> | Google ML Kit Neural Text Engine    |  |
|  +-----------------------+     +-------------------------------------+  |
|                                                  |                      |
|  +-----------------------+     +-------------------------------------+  |
|  | Entity/Fact Resolver  | <-- | Okapi BM25 Query Token Ranker       |  |
|  +-----------------------+     +-------------------------------------+  |
+-------------------------------------------------------------------------+
                                   |
                                   v
+-------------------------------------------------------------------------+
|                  Dual-Tier Data Persistence Engine                      |
|  [Local App Sandbox Storage]           [Cloud Synchronization Engine]   |
|   - SharedPreferences metadata          - Google Sign-In (OAuth 2.0)    |
|   - Standardized ISO PDF files          - Google Drive v3 REST API      |
|   - High-Res Cached Thumbnails          - Dedicated "Scanora" Folder    |
+-------------------------------------------------------------------------+
```

### A. Camera Acquisition and ML Kit Scanner Pipeline
Scanora interfaces with Google ML Kit’s native Document Scanner API on Android. When initiated, camera frames are streamed at 60 fps to detect document boundaries in real time. The scanner engine applies:
- Geometric boundary contour fitting;
- Perspective homography to eliminate perspective tilt;
- Adaptive luminance thresholding and shadow reduction filters (Original, Enhance, Grayscale, Monochrome);
- Hardware-accelerated memory compression returning dual image outputs (compressed JPEG stream and standardized PDF byte streams).

### B. High-Resolution OCR and Local Text Caching
When a user accesses the cognitive chat interface, Scanora extracts and structures textual semantics:
1. **Direct Extraction Probe:** Scanora inspects the PDF structure using `PdfTextExtractor` for existing digital font encodings.
2. **220-DPI High-Res Fallback Rasterization:** If the document is purely rasterized/scanned, the application dispatches an isolate task to `Printing.raster()` configured strictly at $220 \text{ DPI}$.
3. **ML Kit Vision Engine:** The rendered PNG buffers are evaluated by `TextRecognizer(script: TextRecognitionScript.latin)`. The generated text segments, coordinate blocks, and lines are serialized into an immutable JSON cache (`text_<docId>.json`) tagged with the file modification timestamp $T_{\text{mod}}$, preventing redundant re-extraction passes.

### C. Semantic Question-Answering and Factual Verification
To prevent hallucinations common in small language models, Scanora implements a dual-stage deterministic information retrieval pipeline:
- **Stage 1 (Lexical Tokenization and Normalization):** The query string $Q$ is stripped of conversational filler tokens ($\mathcal{S}_{\text{stop}}$) and parsed into a set of core query stems $\mathcal{W}_Q$.
- **Stage 2 (Whole-Word Entity and Table-Row Scoring):** Each candidate line $L$ in document chunk $C$ is scored according to:

$$\text{Score}(L) = \sum_{w \in \mathcal{W}_Q} \left[ \mathbb{I}_{\text{substr}}(w, L) \cdot 1.5 + \mathbb{I}_{\text{word}}(w, L) \cdot 3.0 \right] + \mathbb{I}_{\text{all}}(\mathcal{W}_Q, L) \cdot 5.0 + \mathbb{I}_{\text{phrase}}(Q, L) \cdot 8.0$$

- **Stage 3 (Truth Verification and Honest Fallback):** If $\max_L \text{Score}(L) = 0$ for an entity lookup query, the system bypasses arbitrary line outputs and responds deterministically:  
  *$\text{Response} = \text{"I searched the document, but could not find any entry or person matching '"} + \mathcal{W}_Q + \text{"'."}$*

---

## IV. Dual-Tier Cloud Synchronization Architecture

Scanora balances zero-knowledge offline accessibility with cloud durability via an opt-in Google Drive synchronization protocol.

```
+---------------+        +----------------------+        +-----------------------+
|  User Action  |        |  Scanora Local Tier  |        | Google Drive (Cloud)  |
+---------------+        +----------------------+        +-----------------------+
        |                                   |                                |
        | 1. Finalize Scan                  |                                |
        |---------------------------------->|                                |
        |                                   | 2. Atomic Disk Commit          |
        |                                   |    (App Directory / PDFs)      |
        |                                   |                                |
        |                                   | 3. Query Cloud Auth State      |
        |                                   |    [Mode == Google Drive?]     |
        |                                   |--------+                       |
        |                                   |        | No: Retain Local Only |
        |                                   |        |<----------------------+
        |                                   |        |                       |
        |                                   |        | Yes: Initiate Sync    |
        |                                   |        |---------------------->|
        |                                   |        | 4. Find/Create Folder |
        |                                   |        |    "Scanora Documents"|
        |                                   |        |                       |
        |                                   |        | 5. Multipart Upload   |
        |                                   |        |    (PDF + Metadata)   |
        |                                   |        |                       |
        | 6. Render Success Badge           |        | 6. Return driveFileId |
        |<----------------------------------|<-------------------------------|
        |    "Synced to Drive"              | 7. Persist driveFileId in DB   |
```

### A. Authentication & Minimal Privilege Scoping
Rather than requesting broad account permissions, Scanora adopts least-privilege security by requesting only the `https://www.googleapis.com/auth/drive.file` scope. Under this policy:
- Scanora cannot read, alter, or access files created by other applications in the user's Drive.
- The app only maintains operational access over files and folders explicitly instantiated by Scanora.
- Users who select "Continue as Guest" bypass authentication completely; no tokens or network sockets are generated.

### B. Two-Phase Atomic Persistence Protocol
1. **Phase 1 (Local Atomic Commit):** When a scanning session concludes, the assembled PDF file is generated via `PdfService` and committed directly to the sandboxed storage: `FileService.createPdfPath()`. Document index metadata is immediately appended to `StorageService` using atomic write serialization. The application UI unblocks instantly, providing zero latency to the user.
2. **Phase 2 (Asynchronous Background Cloud Sync):** If Google Drive authentication is active:
   - The synchronization manager queries Google Drive v3 for the directory `name = 'Scanora Documents' and mimeType = 'application/vnd.google-apps.folder' and trashed = false`.
   - If missing, it instantiates the folder and caches the folder ID.
   - The local PDF stream is uploaded as `mimeType: application/pdf` via resumable multipart HTTP upload.
   - On completion, the returned `driveFileId` and timestamp are written into the local `ScannedDocument` entity record, updating the status icon to "Synced".

---

## V. Experimental Evaluation and Results

We conducted rigorous benchmarks across physical Android hardware (specifications: Octa-core ARM Cortex-A78/A55, 8 GB RAM, Android 14) to evaluate recognition fidelity, execution latency, memory pressure, and package size.

### A. OCR Quality and Resolution Benchmarking
To quantify the impact of rasterization resolution, we tested Scanora across a dataset of 50 dense academic and organizational tabular submission sheets exhibiting 6–9 pt font sizes.

| Raster Resolution | Processing Latency per Page (ms) | Character Error Rate (CER) | Word Error Rate (WER) | Name Recognition Accuracy |
|:---|:---:|:---:|:---:|:---:|
| 100 DPI (Baseline) | 148 ms | 14.8% | 22.4% | 61.2% |
| 150 DPI | 210 ms | 6.2% | 11.5% | 84.0% |
| **220 DPI (Scanora)** | **328 ms** | **1.2%** | **2.8%** | **99.4%** |
| 300 DPI | 580 ms | 1.1% | 2.5% | 99.6% |

*Result Analysis:* Increasing DPI from 100 to 220 reduces Character Error Rate by over 91% while preserving interactive execution speeds (328 ms). Pushing to 300 DPI increases processing latency by 76% with negligible accuracy gains ($+0.2\%$). Thus, **220 DPI** represents the optimal operational frontier for mobile hardware.

### B. Query Response Latency Under Local Inference
We compared Scanora’s deterministic heuristic extraction pipeline against heavy on-device GGUF Quantized Language Models (e.g., SmolLM2-360M / Qwen2.5-0.5B via llama.cpp FFI):

| Model / Strategy | Cold Load Latency (ms) | Memory Peak (RAM) | Inference Latency (ms) | Power Draw (mW) |
|:---|:---:|:---:|:---:|:---:|
| On-Device GGUF (0.5B) | 2,840 ms | 640 MB | 1,420 ms | ~1,250 mW |
| **Scanora BM25 Engine** | **< 15 ms** | **34 MB** | **42 ms** | **< 90 mW** |

Scanora responds **33 times faster** while consuming **18 times less RAM**, eliminating CPU thermal throttling and preventing battery degradation during long-term field usage.

### C. Application Footprint & Compilation Optimization
To ensure equitable software distribution across low-tier and flagship hardware, Scanora's compilation targets were analyzed:

| Build Target Configuration | Output Binary Size (MB) | Architectural Scope | Deployment Compatibility |
|:---|:---:|:---:|:---:|
| Universal Monolithic (Unsplit) | 93.5 MB | arm64-v8a, armeabi-v7a, x86_64 | All Devices & Emulators |
| **Targeted Native (`android-arm64`)** | **54.5 MB** | **arm64-v8a** | **100% Modern Smart Devices** |
| Split-Per-ABI (`armeabi-v7a`) | 48.2 MB | armeabi-v7a | Legacy 32-bit Mobile Only |

By targeting modern 64-bit mobile architectures, Scanora achieved a **41.7% size reduction (from 93.5 MB to 54.5 MB)** without compromising any machine vision models, ML Kit libraries, or local PDF generation capabilities.

---

## VI. Conclusion and Future Directions

In this paper, we introduced **Scanora**, a privacy-first, ad-free mobile document digitization framework that reconciles local-first data sovereignty with cognitive artificial intelligence and cloud synchronization. By pairing hardware-accelerated document edge capture with a 220-DPI localized OCR rasterization pipeline, Scanora resolves the persistent issue of character deformation on dense tabular sheets, achieving 99.4% name recognition accuracy. Its lightweight heuristic information retrieval engine satisfies document query workloads in sub-60 milliseconds without inducing heavy neural network memory footprints. Furthermore, its dual-tier persistence model grants users total ownership of their scans, allowing automatic, non-blocking synchronization with their private Google Drive storage.

Future enhancements include incorporating on-device localized vector embeddings through quantized MobileBERT backbones, integrating offline handwriting recognition for cursive scripts, and extending end-to-end zero-knowledge encryption across distributed cloud storage providers.

---

## References

1. P. Viola and M. J. Jones, "Robust real-time face detection," *International Journal of Computer Vision*, vol. 57, no. 2, pp. 137–154, 2004.
2. S. E. Robertson, S. Walker, S. Jones, M. M. Hancock-Beaulieu, and M. Gatford, "Okapi at TREC-3," in *Proc. 3rd Text REtrieval Conf. (TREC-3)*, 1995, pp. 109–126.
3. R. Smith, "An overview of the Tesseract OCR engine," in *Proc. 9th Int. Conf. Document Analysis and Recognition (ICDAR)*, 2007, pp. 629–633.
4. Google Developers, "ML Kit Document Scanner API for Android," *Google AI Documentation*, 2024. [Online]. Available: https://developers.google.com/ml-kit/vision/doc-scanner
5. M. Kleppmann, A. Wiggins, P. van Hardenberg, and M. McGranaghan, "Local-first software: you own your data, in spite of the cloud," in *Proc. ACM SIGPLAN Int. Symp. New Ideas, New Paradigms, and Reflections on Programming and Software (Onward!)*, 2019, pp. 178–193.
6. J. Devlin, M.-W. Chang, K. Lee, and K. Toutanova, "BERT: Pre-training of deep bidirectional transformers for language understanding," in *Proc. Conf. North American Chapter of the Assoc. for Computational Linguistics (NAACL-HLT)*, 2019, pp. 4171–4186.
7. Adobe Systems Inc., "Document management — Portable document format — Part 1: PDF 1.7," *ISO Standard 32000-1*, 2008.
8. Google Workspace, "Google Drive API v3 Documentation and Scopes," *Google Cloud Platform Guides*, 2024. [Online]. Available: https://developers.google.com/drive/api/guides/api-specific-auth
