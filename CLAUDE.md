# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Development server (Rails + Tailwind watcher)
bin/dev

# Rails server only
bin/rails server -p 3000

# Console
bin/rails console

# Run tests
bin/rails test
bin/rails test test/models/receipt_test.rb  # single file

# Database
bin/rails db:migrate
bin/rails db:schema:load  # faster for fresh setup

# Linting
bin/rubocop
bin/brakeman  # security audit
```

## Architecture

**PayNow** is a Rails 8 app that lets informal Mexican businesses receive bank transfers (CLABE/SPEI) via QR codes. Customers scan a QR, copy the CLABE, transfer funds from their bank app, then upload their receipt on the same page. The app verifies receipts automatically using Claude Vision.

### Routing model (3 namespaces)

| Namespace | Auth | Purpose |
|---|---|---|
| `/admin/` | Super admin only | Global CRUD of Organizations and Users |
| `/dashboard/` | Business owner only | Self-service: businesses, receipts, clients, incomes |
| `/:slug` on subdomain | None | Public payment landing page (QR destination) |

The public payment flow uses **subdomain routing**: `organization.lvh.me/p/business-slug` in development. `Public::PaymentsController` resolves the organization from `request.subdomain`, then the business from `params[:slug]`.

### Data model

```
Organization (subdomain)
  └── has_many :users
  └── has_many :businesses (through users)

User (role: super_admin | business_owner)
  └── belongs_to :organization (required for business_owner, nil for super_admin)
  └── has_many :businesses

Business (name, clabe, holder_name, whatsapp, slug)
  └── belongs_to :user
  └── has_many :receipts

Receipt (verification_status, amount_cents, transfer_date, bank_name, reference_number, payer_name, payer_phone)
  └── belongs_to :business
  └── has_one_attached :file (Active Storage)
```

`amount_cents` stores money as integer (÷100 for display). `Receipt#amount` / `Receipt#amount=` handle conversion. `Receipt.total_amount_cents` sums only `verified` receipts.

### Receipt verification flow

1. Client uploads receipt → `Receipt` created with `verification_status: pending`
2. `after_create_commit` enqueues `ReceiptVerificationJob`
3. Job downloads the attached file, converts PDF→PNG via MiniMagick if needed, encodes to base64
4. Calls Claude API (`claude-haiku-4-5-20251001`) with a vision prompt, expects JSON: `{ is_transfer, transfer_date, amount, bank_name, reference_number, notes }`
5. Validates: must be a transfer AND `transfer_date == Date.current` (unless `force: true` on reprocess)
6. Updates `verification_status` → `verified | rejected | unreadable`
7. Broadcasts Turbo Stream updates to dashboard (receipt card + accounting totals)
8. Notifies payer via WhatsApp (`payer_phone`) and business owner (`business.whatsapp`) through `WhatsappReplyJob`

### WhatsApp integration (Twilio)

- **Inbound**: `POST /webhooks/twilio` → `Webhooks::TwilioController#receive`
  - Resolves business from message body (slug or name)
  - Downloads the attached media with HTTP Basic Auth (Twilio credentials)
  - Creates a `Receipt` and replies with confirmation
- **Outbound**: `WhatsappReplyJob` wraps Twilio SDK; called from `ReceiptVerificationJob` after status is determined
- Phone normalization: Mexican numbers without country code get `52` prepended; `whatsapp:` prefix added

### Real-time updates (Turbo Streams)

Two broadcast channels per business:
- `"business_#{business_id}_receipts"` — updates receipt list and accounting partial on `business#show`
- `"user_#{user_id}_notifications"` — toast notifications visible across all dashboard pages

The `ReceiptVerificationJob` also broadcasts an accounting update to `"business_#{business_id}_receipts"` targeting `"accounting_#{business.id}"` after verification completes.

### Authentication

Built with Rails 8 Authentication Generator. `Current.session` / `Current.user` via `Authentication` concern included in `ApplicationController`. Role check (`super_admin?` / `business_owner?`) gates each namespace through base controllers:
- `Admin::BaseController` — requires `super_admin?`
- `Dashboard::BaseController` — requires `business_owner?`

`Public::PaymentsController` and `Webhooks::TwilioController` both inherit from `ActionController::Base` (skip authentication entirely).

### Background jobs

Uses **Solid Queue** (DB-backed). Jobs: `ReceiptVerificationJob`, `WhatsappReplyJob`. Queue name: `:default`. A recurring job clears finished Solid Queue records hourly in production (`config/recurring.yml`).

### Excel export

`Dashboard::IncomesController#index` responds to `.xlsx` via `caxlsx_rails`. Template at `app/views/dashboard/incomes/index.xlsx.axlsx`. Income views are filtered by period (`today | this_week | this_month | this_year`) and only count `verified` receipts.

### Environment variables required

```
ANTHROPIC_API_KEY       # Claude vision API
TWILIO_ACCOUNT_SID      # Twilio credentials
TWILIO_AUTH_TOKEN
TWILIO_WHATSAPP_NUMBER  # format: "whatsapp:+1415..."
```
