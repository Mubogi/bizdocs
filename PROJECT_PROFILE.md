# Project Profile — BizDocs

> Offline-first invoicing, receipts, quotations and letters for SMEs (Uganda-ready).

## 1. Business Overview
- **Owner / Brand:** Jordan Design Hub (JD Hub) — Mubogi Gastavas Jordan Tech Ecosystem
- **Contact:** jordandesignhub@gmail.com · WhatsApp +256 754 687 597
- **Category:** FinTech / SME tools
- **Status:** production (MVP)
- **Links:** <https://github.com/Mubogi/bizdocs> · APK via GitHub Actions releases

## 2. Problem & Target Market
- **Problem:** Ugandan SMEs need professional business documents without expensive data or connectivity.
- **Target users:** Small and medium businesses, shops, service providers.
- **Market context:** Offline-first; URA TIN fields; mobile-money payment tracking (MTN/Airtel); integer minor-unit money handling.

## 3. Value Proposition & Features
- Business profile with URA TIN, contacts, currency (UGX), default tax
- Customers, products/services with optional stock tracking
- Auto-numbered documents: invoices, receipts, quotations, letters
- Drawn signature pad — signed docs locked, hashed, audit-logged
- PDF generation (A4 or 80 mm thermal width); watermark removed on Pro
- Send queue (outbox) with retry, shared via WhatsApp/other channels
- Quotation → invoice → receipt flows; partial payment tracking
- Month-end lock (Pro) with monthly summary PDF
- Audit log of full document lifecycle

## 4. Business / Monetization Model
- **Pricing:** freemium → Pro unlock
- **Revenue streams:** Pro subscription (MVP code BIZPRO-2026, 12 months); planned Flutterwave/Paystack mobile-money subscriptions
- **Payment methods:** Pro unlock code now; Flutterwave/Paystack mobile-money planned

## 5. Tech Stack
| Layer | Tech |
|-------|------|
| Backend | n/a (local-first) |
| Frontend | Flutter (Dart) |
| Database | SQLite (sqflite), UUID keys for future cloud sync |
| Mobile/Desktop | Android APK primary |
| Deploy | GitHub Actions builds APK release on push to main |

## 6. Roadmap & Status
- **Current milestone:** Working offline-first MVP with APK CI pipeline
- **Next steps:** EFRIS/URA integration; cloud backup/sync (Supabase/Firebase); backend subscription validation; thermal printer (ESC/POS); roles & multi-business UI
- **Known gaps:** Pro verification is client-side MVP code, not server-validated

## 7. Metrics (optional)
- Users: n/a
- Last updated: 2026-08-26

---
*Template version: 1.0 — kept identical across all JD Hub projects. Update only the content, not the structure.*
