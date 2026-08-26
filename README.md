# BizDocs

Offline-first document generator for small businesses — create and send **invoices, receipts, quotations, and letters** with drawn signatures, PDF output, and a send queue. Built for conditions where data is expensive, given Uganda-context features (TIN fields, mobile money payment tracking).

## Features

- **Business profile** with URA TIN, contacts, currency (UGX default), default tax %
- **Customers & **Products/services** incl. optional stock tracking
- **Documents**: Invoices, Receipts, Quotations, Letters (auto-numbered INV-0001, RCT-0001, ...)
- **Line items** with quantities, unit prices, per-line tax; auto totals
- **Drawn signature pad** → signed documents are **locked/immutable**, hashed, audit-logged
- **PDF generation** (A4 or 80 mm thermal-receipt width) with watermark removed on **Pro**
- **Send queue (outbox)**: PDFs queued and shared via WhatsApp/other channels with retry
- **Period flows**: quotation → invoice → receipt conversion; partial payment tracking (Cash, MTN, Airtel, Bank)
- **Month-end lock (Pro)**: freeze a month's documents + generate monthly summary PDF
- **Audit log** of document lifecycle events
- **Multi-business profiles** (schema-ready)

## Pro

Pro unlock gates watermark removal and the month-end lock. MVP code `BIZPRO-2026` (12 months) — replace with Flutterwave/Paystack mobile-money subscriptions + server-side verification for production.

## Build the APK

The repo builds automatically on every push to `main` via GitHub Actions and publishes a release with the APK attached:

```
Actions tab → Build APK & Release → (after completion) Releases → BizDocs APK
```

Local build:

```bash
flutter create --empty --org com.mubogi --project-name bizdocs --platforms=android .
flutter pub get
flutter build apk --release
```

## Architecture

- **Flutter** (Dart) — offline-first; Android APK primary, Play Store optional later
- **SQLite (sqflite)** with UUID keys & created/updated timestamps for future cloud sync
- **pdf / share_plus / signature / sqflite / uuid**
- Money stored as **integer minor units**. Document numbering per business/doc_type is transactionally sequenced.
- Data model (businesses, customers, products, templates, sequences, documents, items, payments, signatures, outbox, subscription, audit, settings) lives in `lib/db/database.dart`

## Roadmap (planned)

- EFRIS/URA integration path for VAT-registered businesses
- Cloud backup/sync (Supabase/Firebase) + web dashboard for B2B
- Backend subscription validation via Flutterwave/Paystack webhooks
- Direct thermal printer (ESC/POS over Bluetooth) instead of PDF share
- Roles (owner/cashier), multi-business UI, multi-language
