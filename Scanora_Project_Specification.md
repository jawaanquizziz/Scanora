# Scanora --- Flutter Document Scanner App

## Product Specification & Implementation Guide

**Tagline:** Scan. Save. Organize.\
**Platform:** Android-first mobile app\
**Framework:** Flutter\
**Language:** Dart\
**Product direction:** Inspired by the fast, camera-first workflow of
the discontinued Microsoft Lens app, with Scanora's own branding and UI.

------------------------------------------------------------------------

## 1. Project Goal

Build **Scanora**, a polished, practical document-scanning app that lets
users scan paper documents, clean up the images, combine pages into
PDFs, and find saved files later.

The experience should feel familiar to people who used Microsoft Lens:
open the camera quickly, capture a page, adjust its corners, apply a
document filter, add more pages, and save. Do not copy Microsoft's logo,
name, exact screen designs, or proprietary assets. Use the workflow as
inspiration and create an original Scanora interface.

### Product principles

-   **Ad-free:** no advertising SDKs or ad placements.
-   **Local-first:** scans and PDFs are saved on the device by default.
-   **Offline-friendly:** core scanning, editing, saving, browsing, and
    viewing must work without an account or internet connection.
-   **Camera-first:** scanning is the primary action; avoid unnecessary
    onboarding and extra taps.
-   **Reliable:** never silently discard an unsaved scan; handle
    permissions, empty states, and errors clearly.
-   **Simple:** use clear labels, familiar icons, readable type, and
    accessible touch targets.

## 2. Core User Journey

1.  Open Scanora.
2.  Reach the Home screen with a prominent **Scan** action.
3.  Open the camera and choose **Document**, **Whiteboard**, or **ID
    Card** mode if supported.
4.  Capture a page, or import an image from the gallery.
5.  Adjust the crop corners and rotate the page.
6.  Apply a filter such as Original, Enhance, Grayscale, or Black &
    White.
7.  Add, reorder, rotate, or delete pages in a multi-page scan.
8.  Preview the result and name the document.
9.  Save as a PDF locally, optionally choosing a folder.
10. Find the saved file in Documents, search, open it, rename it,
    favourite it, or share it.

Keep the path from opening the app to starting a scan short and obvious.

## 3. Screens to Build

### A. Splash Screen

-   Show the Scanora icon and wordmark.
-   Use a brief, clean transition into the app.
-   Do not leave the user waiting on an unnecessary animation.

### B. Home

-   App title: **Scanora**
-   Main actions: **Scan Document** and **Import Image**
-   Show recent documents with thumbnail, filename, date, and page
    count.
-   Provide access to Documents, Folders, and Settings.
-   Include a visible empty state for first-time users.

### C. Camera / Scan

-   Camera preview fills most of the screen.
-   Large shutter button near the bottom.
-   Controls for flash, gallery import, and closing the camera.
-   Document-edge detection and automatic capture may be added if the
    selected scanning package supports them reliably.
-   Provide a manual capture fallback when auto-detection is
    unavailable.
-   Prevent capture when camera permission is denied; explain how to
    enable it.

### D. Crop and Adjust

-   Show the captured page with adjustable crop corners.
-   Include crop, rotate, reset, and retake actions.
-   Keep the original image so the user can undo adjustments.
-   Avoid destructive edits until the user confirms.

### E. Filters

-   Preview options such as Original, Enhance, Grayscale, and Black &
    White.
-   Make the selected filter obvious.
-   Use small previews and simple labels.
-   Do not claim OCR or automatic cleanup exists unless it is
    implemented.

### F. Multi-page Review

-   Display page thumbnails in capture order.
-   Add page, reorder pages, rotate, retake, and delete actions.
-   Clearly show the current page and total page count.
-   Ask for confirmation before deleting a page when appropriate.

### G. Save / Export

-   Editable filename, defaulting to a useful name such as
    `Scan_YYYY-MM-DD_HH-mm`.
-   Choose a destination folder.
-   PDF is the primary output format.
-   Show progress while generating a PDF.
-   Confirm successful save and provide **Open PDF** and **Scan
    Another** actions.
-   Handle insufficient storage and write failures without losing the
    working scan.

### H. Documents

-   Search by filename.
-   Filters: All, PDFs, Images, and Favourites, where applicable.
-   Sort by most recent, name, or modified date.
-   Show filename, thumbnail, date, and page count.
-   Include clear empty and no-results states.

### I. PDF Viewer

-   Open saved PDFs locally.
-   Support page navigation and zoom.
-   Provide Share, Rename, Favourite, Move to Folder, and Delete
    actions.
-   Show an understandable error if a file cannot be opened.

### J. Folders

-   Create, rename, and delete folders.
-   Move documents between folders.
-   Include sensible default folders only if they help; do not clutter
    the first-run experience.
-   Deleting a folder must not silently delete its documents.

### K. Settings

-   Theme: System, Light, Dark.
-   Default save location within app-managed local storage.
-   Default PDF page size, such as A4.
-   About Scanora, privacy information, and app version.
-   Do not add sign-in, cloud sync, analytics, or ads to the initial
    version.

## 4. Visual Design System

Aim for a professional, native-feeling utility app---not a flashy
marketing mockup.

### Colours

-   Primary blue: `#176BFF`
-   Navy: `#101828`
-   App background: `#F6F8FC`
-   Surface: `#FFFFFF`
-   Secondary text: `#667085`
-   Success: `#16B981`
-   Error: `#EF4444`

### UI rules

-   Use Material 3 components where appropriate, customized to match
    Scanora.
-   Use a consistent spacing scale (8, 12, 16, 24, 32).
-   Use restrained corner radii and subtle elevation.
-   Keep icons simple and consistent; use one icon family.
-   Prefer flat colours and modest gradients over glow effects,
    glassmorphism, excessive shadows, or decorative blobs.
-   Keep camera controls high-contrast and easy to reach.
-   Ensure buttons and crop handles are comfortably touchable.
-   Support small Android screens and system text scaling.
-   Include dark mode, but prioritize the light theme for the first
    polished pass.
-   The app icon should work at small sizes and should not contain the
    word "Scanora".

### Navigation

Use a simple bottom navigation bar: - **Home** - **Documents** -
**Folders** - **Settings**

The camera should be reachable with one prominent action from Home. Do
not hide core scanning behind menus.

## 5. Suggested Flutter Architecture

Keep the code modular and easy for a student team to understand.

``` text
lib/
  main.dart
  app.dart
  core/
    theme/
      app_theme.dart
    utils/
      file_names.dart
    widgets/
      empty_state.dart
      error_message.dart
      loading_indicator.dart
  models/
    scanned_document.dart
    scan_page.dart
    document_folder.dart
  features/
    home/
      home_screen.dart
    scanner/
      scanner_screen.dart
      crop_screen.dart
      filters_screen.dart
      page_review_screen.dart
    documents/
      documents_screen.dart
      pdf_viewer_screen.dart
      document_actions.dart
    folders/
      folders_screen.dart
    settings/
      settings_screen.dart
  services/
    camera_service.dart
    pdf_service.dart
    local_storage_service.dart
    file_service.dart
```

Adjust the structure to the existing project rather than overwriting
working files blindly.

## 6. Technology and Packages

Use stable, compatible Flutter packages and check their current
maintenance status before adding them.

Potential package choices: - Camera capture: `camera` or a maintained
document-scanning package. - Gallery selection: `image_picker`. - Image
processing: `image` and/or a maintained cropper package. - PDF
generation: `pdf`. - PDF preview: `pdfx` or another maintained PDF
viewer compatible with the target Android version. - Local paths:
`path_provider`. - Database/metadata: `sqflite` or another suitable
local database. - Preferences: `shared_preferences`. - Sharing:
`share_plus`. - File operations: `path` and Dart `dart:io` where
appropriate.

Do not install every package automatically. Select the smallest set that
meets the requirements, verify version compatibility, and document any
native Android setup. A camera package alone may not provide reliable
document-edge detection; use a maintained scanning SDK/package if
needed, with manual capture as a fallback.

## 7. Local Data and File Handling

-   Store PDF files and scan images in app-managed local storage.
-   Store document metadata separately: ID, filename, local path,
    created/modified timestamps, page count, favourite status, and
    optional folder ID.
-   Use stable IDs instead of using filenames as unique identifiers.
-   Sanitize filenames and handle duplicate names.
-   Update metadata only after file operations succeed.
-   Make rename and move operations safe and recoverable.
-   Ask before permanent deletion.
-   Avoid storing full-resolution image bytes in the database; store
    file paths and metadata.
-   Keep temporary scan images separate from saved documents and clean
    up temporary files after successful save or cancellation.
-   Clearly distinguish app-private storage from user-visible exports.
    If users need PDFs in Downloads or another shared location, use
    Android's supported file-saving flow.
-   Do not upload documents to a server.

## 8. Privacy and Permissions

-   Request camera permission only when the user starts scanning.
-   Request photo/media access only when importing from the gallery,
    using platform pickers where possible.
-   Explain why a permission is needed.
-   Handle denial and permanent denial gracefully.
-   Keep scans on-device by default.
-   Do not include advertising, mandatory accounts, cloud upload, or
    unnecessary permissions.
-   Never promise that files are encrypted unless encryption is
    implemented and tested.

## 9. Accessibility and Usability

-   Use readable text and strong contrast.
-   Give icon-only buttons semantic labels and tooltips where
    appropriate.
-   Do not communicate status by colour alone.
-   Support Android back navigation predictably.
-   Warn users before leaving a scan that has not been saved.
-   Provide loading, success, error, empty, and permission-denied
    states.
-   Make the most important actions visually prominent without crowding
    the screen.

## 10. Implementation Plan

### Phase 1 --- App foundation

-   Inspect the existing Scanora folder and current Flutter setup.
-   Preserve working code and dependencies.
-   Set up theme, navigation, reusable widgets, and screen placeholders.
-   Build Home, Documents, Folders, and Settings.

### Phase 2 --- Scanning

-   Implement camera permission and live preview.
-   Capture images and import from gallery.
-   Add crop, rotate, filters, and retake.
-   Add multi-page capture and page reordering.

### Phase 3 --- PDF and local library

-   Generate multi-page PDFs.
-   Save files locally and persist metadata.
-   Build document list, search, folders, favourites, and PDF viewer.
-   Add rename, move, share, and delete.

### Phase 4 --- Quality

-   Test permission denial, no camera, empty library, duplicate
    filenames, low storage, failed PDF generation, and interrupted
    scans.
-   Test on a real Android device as well as an emulator where possible.
-   Fix layout overflow and verify dark mode.
-   Test that core functions work in airplane mode.

## 11. Definition of Done

The first release is ready when: - The user can capture or import
pages. - The user can crop, rotate, and apply a filter. - Multiple pages
can be combined into one valid PDF. - The PDF is saved locally and
remains available after restarting the app. - The document appears in
the library and can be opened and shared. - Search, folders, favourites,
rename, and delete work as implemented. - No ads, mandatory sign-in, or
cloud dependency are present. - Permission errors and failed saves are
handled clearly. - The interface is consistent, responsive, and usable
on common Android screen sizes.

## 12. Instructions for an AI Coding Assistant

Work inside the existing `Scanora` project folder. First inspect the
project structure, `pubspec.yaml`, current Flutter version, and existing
code. Then propose a short implementation plan and make changes
incrementally.

Do not replace the project with a static mockup. Build working Flutter
screens and connect each visible control to real functionality. Do not
fabricate completed features, leave dead buttons, or use fake document
data as if it were saved user data. Use sample data only for development
previews and provide proper empty states in the real app.

Keep the UI inspired by Microsoft Lens's practical camera-first
workflow, but use original Scanora branding, layouts, icons, and
styling. Prioritize a reliable scanning-to-PDF flow before adding
optional features. After each phase, run formatting, static analysis,
and relevant tests; report what works, what remains, and any setup
commands required.
