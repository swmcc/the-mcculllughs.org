# Apple Shortcut: Upload to McCulloughs

## Overview

The "Upload to McCulloughs" Shortcut lets you share photos and videos directly from your iPhone or iPad to your family gallery at https://the-mcculloughs.org. Add it to your share sheet, tap it, and your original photo uploads with all metadata intact — the server automatically generates WebP display variants and preserves EXIF data (camera model, GPS location, capture date, orientation) for archival and timeline browsing.

**Key workflow:**
1. Take a photo or select from your library
2. Tap Share → Upload to McCulloughs
3. Choose a gallery (or create a new one)
4. Done — see the notification with a link to the uploaded photo

## Create an API Key

An API key grants the Shortcut permission to upload photos on your behalf.

**Steps:**
1. Open https://the-mcculloughs.org/api_keys in a browser
2. Click **Create API Key**
3. Choose scope **`photos:create`** (least privilege — upload photos only)
4. Copy the key `sk_...` that appears **once** at creation
5. **Do not share this key.** It grants upload access to your account.
6. Store it securely in the Shortcut's text field (never in Notes or Messages)

**To rotate a key:**
1. Create a new API key at /api_keys
2. Copy it to your Shortcut's text field
3. Return to /api_keys and click **Revoke** on the old key
4. Old key will reject all requests within seconds

## Build the "Upload to McCulloughs" Shortcut

Open the Apple Shortcuts app and create a new Shortcut. Follow these exact steps.

### Step 1: Set Up Input
1. Add action **Ask for [Images and Files]**
   - Prompt: "Select photos or videos to upload"
   - Allow: Multiple selections

### Step 2: Fetch Your Galleries
1. Add action **Get Contents of URL**
   - URL: `https://the-mcculloughs.org/api/galleries`
   - Method: GET
   - Headers:
     - Key: `Authorization`
     - Value: `Bearer [your-api-key-here]` (replace with your `sk_...` key)
2. Add action **Get Dictionary Value**
   - Dictionary: Result from previous step
   - Key: `galleries`
   - Save to variable: `GalleriesList`

### Step 3: Choose a Gallery
1. Add action **Combine text**
   - Combine: `Galleries list` + text `➕ New gallery…`
   - Save to variable: `GalleriesWithNew`
2. Add action **Ask for [Galleries with New, Picker]**
   - Prompt: "Choose a gallery"
   - Save to variable: `SelectedGallery`

### Step 4: Create Gallery if Needed
1. Add action **If`**
   - Condition: `Selected Gallery` equals `➕ New gallery…`
   - Inside If:
     1. Add action **Ask for [Text]**
        - Prompt: "Gallery name"
        - Save to variable: `NewGalleryName`
     2. Set `SelectedGallery` to `NewGalleryName`

### Step 5: Upload Photos
1. Add action **Repeat with Each** over Shortcut Input
   - Inside loop:
     1. Add action **Get Contents of URL**
        - URL: `https://the-mcculloughs.org/api/uploads`
        - Method: POST
        - Request Body: Form
          - `file`: Set to Repeat Item (the photo/video being uploaded)
          - `gallery_name`: Set to `SelectedGallery`
        - Headers:
          - Key: `Authorization`
          - Value: `Bearer [your-api-key-here]`
     2. Add action **Get Dictionary Value**
        - Dictionary: Result from POST
        - Key: `upload` → `short_code`
        - Save to variable: `ShortCode`
     3. Add action **If**
        - Condition: `short_code` has value (not empty)
        - Inside (success):
          1. Add action **Show Result**
             - Text: `✅ Uploaded to [gallery]: https://the-mcculloughs.org/p/[short_code]`
        - Otherwise (error):
          1. Add action **Get Dictionary Value**
             - Dictionary: Result from POST
             - Key: `error`
          2. Add action **Show Result**
             - Text: `❌ Failed: [error]`

## Quick Upload Variant

For rapid uploads skipping the gallery picker:

1. Repeat Steps 1–2 above (input + fetch galleries)
2. **Skip Step 3 and 4** (no gallery picker)
3. In Step 5, replace `SelectedGallery` with the literal text `Shortcuts Inbox`

Photos land in an auto-created "Shortcuts Inbox" gallery. Add this as a separate Shortcut and pin it for one-tap uploads.

## Critical: Do Not Transcode

**Do not insert *Convert Image* or *Resize* actions anywhere in the Shortcut.**

Shortcuts sometimes auto-transcodes HEIC photos to JPEG depending on input configuration, corrupting the original file and destroying metadata. The server expects byte-identical originals to detect duplicates and preserve EXIF.

**Verify byte-fidelity before use:**
1. Upload one test photo using the Shortcut
2. On your Mac, note the original file's MD5:
   ```bash
   md5 original.heic
   ```
3. In Rails console on the server, check the stored blob's checksum:
   ```ruby
   upload = Upload.last
   stored_md5 = upload.file.blob.checksum
   ```
4. Compare: **they must be identical.** If not, Shortcuts is transcoding.
5. **Fix:** In Shortcuts app settings, try disabling "Auto-convert to JPEG" or confirm the Share Sheet input type is set to Files, not Images.
6. Record your working configuration in the Shortcut's comments so you don't lose it.

## curl Examples

### List your galleries
```bash
curl -H "Authorization: Bearer sk_..." https://the-mcculloughs.org/api/galleries
```

Response:
```json
{
  "galleries": [
    { "id": 7, "title": "Summer 1987", "uploads_count": 42 },
    { "id": 9, "title": "Holidays 2024", "uploads_count": 15 }
  ]
}
```

### Upload a photo to a named gallery
```bash
curl -H "Authorization: Bearer sk_..." \
  -F "file=@IMG_0001.heic" \
  -F "gallery_name=Summer 1987" \
  -F "title=Beach day" \
  https://the-mcculloughs.org/api/uploads
```

Response (success):
```json
{
  "success": true,
  "upload": {
    "id": 812,
    "short_code": "aB3xY9",
    "gallery": "Summer 1987",
    "url": "https://the-mcculloughs.org/p/aB3xY9"
  }
}
```

### Retry: upload the same file again
```bash
curl -H "Authorization: Bearer sk_..." \
  -F "file=@IMG_0001.heic" \
  -F "gallery_name=Summer 1987" \
  https://the-mcculloughs.org/api/uploads
```

Response (duplicate detected):
```json
{
  "success": true,
  "duplicate": true,
  "upload": {
    "id": 812,
    "short_code": "aB3xY9",
    "gallery": "Summer 1987",
    "url": "https://the-mcculloughs.org/p/aB3xY9"
  }
}
```

Safe to retry — same response every time.

## Verification Checklist

Use this checklist to confirm your Shortcut is working correctly.

### Metadata Preservation
- [ ] Export a test HEIC photo from your camera
- [ ] Run `exiftool -j original.heic` on your Mac and note:
  - Camera model (e.g., `"Model": "iPhone 15 Pro"`)
  - GPS coordinates (if available)
  - Capture datetime (e.g., `"DateTimeOriginal"`)
  - Image orientation (e.g., `"Orientation": 1`)
- [ ] Upload via the Shortcut to any gallery
- [ ] In Rails console, download the stored blob and compare:
  ```ruby
  upload = Upload.find(812)  # your upload ID
  File.open("stored.heic", "wb") { |f| f.write(upload.file.download) }
  ```
- [ ] Run `exiftool -j stored.heic` and verify the same fields exist (case-insensitively)
- [ ] Check MD5 match:
  ```bash
  md5 original.heic
  md5 stored.heic
  ```
  Must be identical (byte-for-byte)

### WebP Variants
- [ ] Upload a HEIC photo via the Shortcut
- [ ] Visit the photo's public page (e.g., https://the-mcculloughs.org/p/aB3xY9)
- [ ] Confirm the image renders (server generated WebP variants at 400×400, 1024, and 2048)
- [ ] If the image doesn't load:
  - Check server logs: `docker compose logs web`
  - Run `vips heifload` on the server — if it fails, libvips HEIF support is missing
  - Install: `apt-get install libheif1` (Ubuntu) or `brew install libheif` (macOS)

### API Key Revocation
- [ ] Revoke your test key at https://the-mcculloughs.org/api_keys
- [ ] Try to upload with the old key — should get `401 Unauthorized`

### Duplicate Detection
- [ ] Upload the same file twice into the same gallery
- [ ] Confirm the second attempt returns `"duplicate": true` (not an error)
- [ ] Check upload ID — should be the same both times

### Public Link Privacy (once metadata stripping ships)
- [ ] Upload a HEIC with GPS coordinates
- [ ] Visit the public link (e.g., https://the-mcculloughs.org/t/aB3xY9) in a browser
- [ ] Download the image and run `exiftool -j downloaded.webp`
- [ ] Confirm GPS coordinates and other sensitive metadata are **not** present
- [ ] Original EXIF (in `/p/` direct-link mode) should still contain it

## Troubleshooting

| Status | Likely Cause | Fix |
|--------|--------------|-----|
| **401 Unauthorized** | Missing API key, wrong key, or key revoked | Check your key at /api_keys; create a new one if unsure |
| **403 Forbidden** | Key lacks `photos:create` scope or gallery belongs to another user | Verify key scope is `photos:create`; don't upload to others' galleries |
| **422 Unprocessable Entity** | File type not supported (only HEIC/JPEG/PNG/video), file >500 MB, or corrupt | Check file size; confirm format; try re-exporting from Photos |
| **429 Too Many Requests** | Rate limit hit (60 uploads/min per key) | Wait a minute, then retry |
| **500 Internal Server Error** | Server crashed; usually libvips/HEIF issue | Notify the admin; check server logs for libheif errors |
| **Image doesn't load** | WebP variants failed to generate | Server may lack libheif; admin should run `apt-get install libheif1` |
| **Metadata missing** | Shortcut transcoded the file to JPEG | See "Critical: Do Not Transcode" section; verify byte-fidelity before use |
| **Shortcut shows spinner forever** | Network timeout or server unreachable | Check wifi; try again in a moment; verify https://the-mcculloughs.org is up |
