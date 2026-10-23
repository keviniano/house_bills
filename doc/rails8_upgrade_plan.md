# House Bills: Rails 8 + SQLite on GCP

Plan for bringing House Bills back from Rails 4.2 / Ruby 2.2 / Heroku Postgres
(untouched since Oct 2017) to Rails 8 / Ruby 3.4 / SQLite on a single GCP
e2-micro VM, deployed with Kamal and backed up to Cloud Storage. All hosting
stays with Google. Expected cost is about $3.65/month, which is the VM's external IPv4 address.

Goals, in order:

1. **Feature parity** with the 2017 app, including permissions, the lock date, the audit
   trail, CSV export and charts.
2. **Every balance correct to the cent.** Each member's balance from the original dump
   must match exactly once it's in the new app.
3. **Familiar screens and workflows.** Nostalgia is part of the point, so pages and
   workflows should work the same, even though the styling moves to Bootstrap 5.
4. **One continuous dataset.** Load the old dump (2011 to about 2016), then the
   replacement spreadsheet (about 2016 to 2026).

---

## Decisions

| # | Decision | Status |
|---|---|---|
| D1 | **Login** | **Decided: Google sign-in only.** Use Devise with only the `:omniauthable` (Google OAuth), `:rememberable` and `:trackable` modules. No passwords, no confirmation emails, no password resets, so the app needs no email service. |
| D2 | **Styling** | **Decided: Bootstrap 5.** Port all views. Pages and workflows stay the same; only the markup and styling change (see Phase 4). |
| D3 | **Domain** for HTTPS and the Google sign-in redirect | **Deferred until Phase 7.** Two things depend on it: kamal-proxy needs a hostname to get a Let's Encrypt certificate, and **Google sign-in only accepts redirect URLs on a real domain** (or `localhost` in development). Development and testing can go ahead without it, but production sign-in can't work until it's chosen. |
| D4 | **Money storage** | **Decided: integer cents** (`amount_cents`). |
| D5 | Keep the precomputed `balance_entries` and `balance_events` tables? | **Decided: keep both for the port.** The amounts stored in `balance_entries` are the record of what each member was actually charged. Copy them unchanged and never recalculate them. Add `bin/rails ledger:verify` to catch the stored rows drifting away from the bills (Phase 3). Optionally, once the port is done, replace `balance_events` with a `UNION ALL` query over bills and member payments (Phase 11). |

---

## Phase 0: Preparation (about 1 evening)

- [ ] Create a branch `rails8` so all of the existing git history is kept.
- [ ] Restore the pre-decommission dump into a local Postgres 17 (`pg_restore --no-owner`).
- [ ] **Record the reference figures** straight from the dump with SQL, so the old app
      doesn't need to run:
  - each member's balance: `SUM(balance_entries.amount)` grouped by `shareholder_id`
  - the account balance and the cleared balance per account
  - row counts for every table
  - the pot balance per account

  Save these in `test/fixtures/golden/` so the import and the tests can compare against them.
- [ ] *(Optional, for nostalgia and reference)* Run the old app once in Docker
      (`ruby:2.2` image + the dump) to capture screenshots and a few CSV exports. These
      give a visual target and some extra reference files. Skip this if `therubyracer`
      or the `pg` gem won't compile.

## Phase 1: New skeleton in the same repo (about 1 evening)

Generating a new Rails 8 skeleton and moving the app code into it is faster than upgrading
through every version from 4.2 to 8.0, given there are no meaningful tests.

- [ ] Generate in the scratch directory:
      `rails new house_bills --database=sqlite3 --javascript=importmap --css=` (no CSS bundler)
- [ ] Copy into the repo, replacing the old files: `Gemfile`, `bin/`, `config/` (the new
      files, then reapply `time_zone = 'Pacific Time (US & Canada)'` and the locales),
      `Dockerfile`, `.kamal/`, `config/deploy.yml`, `.ruby-version`, `public/` error pages.
- [ ] Delete files that are no longer used: `.ruby-gemset`, `Procfile`, `config/unicorn.rb`,
      `config/newrelic.yml`, `config/initializers/mail.rb` (SendGrid), `vendor/plugins`,
      `script/`, `test/performance`, `lib/legacy_helper.rb`, `lib/tasks/legacy.rake`,
      `db/legacy.rb`, `db/migrate/*`.
- [ ] Gem changes:

| Remove | Replace with |
|---|---|
| `unicorn`, `rails_12factor`, `therubyracer`, `figaro` | Puma + Thruster (Rails 8 defaults), Rails credentials |
| `pg` | `sqlite3` |
| `sass-rails`, `bootstrap-sass`, `autoprefixer-rails`, `uglifier`, `coffee-rails` | Propshaft; Bootstrap 5.3 CSS and its JS bundle (which includes Popper) loaded from `vendor/` through importmap; Bootstrap Icons |
| `jquery-rails`, `jquery-ui-rails` | Stimulus + native browser features (Phase 4) |
| `csv_builder` | Ruby's standard `csv` library |
| `validates_timeliness`, `default_value_for` | Native date fields; Rails `attribute ..., default:` |
| `devise` 4.3, `cancancan` 2.0, `paper_trail` 8, `simple_form` 3.5 | Current major versions of each (all still maintained) |
| `will_paginate`, `will_paginate-bootstrap` | `pagy` (it includes Bootstrap 5 pagination markup) |
| - | `omniauth-google-oauth2`, `omniauth-rails_csrf_protection` |

## Phase 2: Schema (about 1 evening)

Write one new migration, `db/migrate/…_create_house_bills.rb`, based on the old `db/schema.rb`, with these changes:

- [ ] Remove `enable_extension "plpgsql"` / `"fuzzystrmatch"`. Neither is used.
- [ ] `decimal :amount` → `integer :amount_cents, null: false, default: 0` on `bills`,
      `account_entries` and `balance_entries`.
- [ ] Add foreign keys and indexes for every `*_id` column. Replace the payee index, which
      is currently unique on `name` across all accounts, with a unique index on `[account_id, name]`.
- [ ] Keep the STI `type` columns (each holds the subclass name), `lock_version`, `creator_id`/`updater_id`,
      and the timestamps as they are.
- [ ] Keep the `versions` table (PaperTrail) and the `roles` seed data.
- [ ] `users`: add `provider` and `uid` (unique index on the pair). Drop the password,
      confirmation, password-reset, account-lock and `authentication_token` columns.
      Keep `name`, `email`, the sign-in tracking columns and the timestamps.
- [ ] Add a `MoneyColumn` concern (`money_attribute :amount`). It exposes `amount` /
      `amount=` as `BigDecimal`, backed by `amount_cents`. Views, forms, and the
      reconstruction of old PaperTrail versions (their YAML contains `amount`) then keep working.

## Phase 3: Models (about 2–3 evenings)

Changes required by moving from Rails 4.2 to 8:

- [ ] `ActiveRecord::Base` → `ApplicationRecord`.
- [ ] **In Rails 5+, `belongs_to` is required by default.** Add `optional: true` to every
      association whose column can be null. Examples: `Bill#shareholder`,
      `AccountEntry#bill`/`#shareholder`, `BalanceEntry#bill`/`#account_entry`/`#shareholder`,
      `Shareholder#user`, `BalanceEvent#bill`/`#account_entry`.
- [ ] `.uniq` → `.distinct`. Affects `BalanceEntry.unique_shareholders` and
      `ChartsController#balance_line_chart`.
- [ ] Raw SQL passed to `order`, `pluck` or `select` must be wrapped in `Arel.sql(...)`. Affects
      `pluck("DISTINCT shareholder_id")` and the `extract(...)` ordering in `Bill` and charts.
- [ ] `default_value_for` → `attribute :date, default: -> { Date.current }` etc.
- [ ] Postgres → SQLite:
  - `ILIKE` → `LIKE` (`account_entry.rb:19`, `balance_event.rb:46,50`)
  - `extract(month|year from x)` → `CAST(strftime('%m'|'%Y', x) AS INTEGER)`
    (`bill.rb:24-28`, `charts_controller.rb:124-126`)
- [ ] **Rewrite `Bill.calc_shares` using integer cents.** It currently mixes `Float` and
      `BigDecimal`. Keep the exact behaviour: the base portion is rounded up to the cent, and the remainder
      goes to the pot. Add unit tests that compare it with the old implementation on every
      bill in the dump.
- [ ] **`bin/rails ledger:verify`** (D5). For each bill and member account entry,
      recalculate what its generated rows should be: the share, offset and pot entries,
      the `BillAccountEntry`, and the `balance_event`. Use the record plus the stored `share`
      ratios. Compare against the stored rows and report each difference with the bill id,
      member, stored amount, recalculated amount and the difference. Report only; never
      rewrite the stored rows.
  - Option `--account=<id>`, and machine-readable output (JSON) so the weekly check can
    record the result.
  - Expected results: the old dump's bills may differ by a cent where the old float
    rounding differs from integer cents. Those are reviewed once and recorded in an
    allowlist (`config/ledger_known_differences.yml`). Anything new beyond that list counts as drift.
  - Shares with an explicit amount (added in the spreadsheet import) are checked against
    their stored amount, not against a recalculation.
- [ ] Remove the `*_string` date getters and setters (`'%m-%d-%Y'`) in favour of `<input type="date">`.
      Keep the mm-dd-yyyy display format through `I18n`.
- [ ] PaperTrail: set `config.active_record.yaml_column_permitted_classes` (`BigDecimal`,
      `Date`, `Time`, `ActiveSupport::TimeWithZone`, `ActiveSupport::TimeZone`) so that 2011-era
      versions can still be read and reconstructed.
- [ ] **Fix existing bugs found during review:**
  - `AccountEntry#cleared_balance`, `#prior_cleared_balance`, `#this_balance` and
    `#prior_balance` aren't limited to the current account.
  - `BillShareBalanceEntry.shareholder` uses `where(:shareholder_id == s.id)`, which
    compares two values in Ruby and passes `false` to `where`.
  - `Ability`: `can :manage, Payee` has no conditions, so any user can edit any account's payees.
  - `ChartQuery`/`BalanceEventQuery.grouped_shareholders` list members from every account.
  - Remove `bill_account_entries/show` and the six `shareholder_account_entries/*` `GET`
    routes in `config/routes.rb`. They're left over from code generators, and one of them is a GET `destroy`.

## Phase 4: Controllers, views, JS (about 3–4 evenings)

- [ ] `before_filter` → `before_action` everywhere.
- [ ] Routes: Rails no longer supports dynamic `:action` route segments
      (`get 'charts(/:action)' => 'charts#:action'`). Replace them with explicit chart routes.
- [ ] CSV export (`balance_events`, `account_entries`): use `respond_to { |f| f.csv { send_data … } }`
      with a small exporter class built on `CSV.generate`. Keep the 250-row limit.
- [ ] Delete links: `link_to … method: :delete` → `button_to` (Turbo), and
      `data: { confirm: }` → `data: { turbo_confirm: }`. This keeps the "Delete Account For Ever and Ever"
      confirmation.
- [ ] simple_form: regenerate the initializer with `rails g simple_form:install --bootstrap`,
      which now produces Bootstrap 5 wrappers. Delete the old `simple_form_bootstrap.rb`.
- [ ] Port the views to Bootstrap 5. There are about 45 Bootstrap 3-specific class names across
      roughly 1,100 lines of ERB:
  - `glyphicon-*` → Bootstrap Icons (`bi-*`)
  - `well` / `panel` → `card`
  - `pull-right` → `float-end`
  - `col-sm-offset-*` → `offset-sm-*`
  - `btn-default` → `btn-secondary` / `btn-outline-secondary`
  - `form-horizontal` / `control-label` → grid `row` + `col-form-label`
  - the navbar markup in `layouts/_menu.html.erb` (BS5 expects different collapse markup)
  - Pagination through `pagy_bootstrap_nav`.
- [ ] Replace the CSS overrides in `application.css.scss` (negative margins on
      `.search-toggle` and `.delete-button`, fixed widths) with BS5 utility classes where
      possible, and move what's left to plain `application.css`.
- [ ] Rewrite `application.js` (about 90 lines of jQuery) as Stimulus controllers:
  - `search-toggle`: show/hide the filter form and remember the choice in a cookie. This could use BS5's
    `collapse` component plus a few lines to set the cookie.
  - Datepicker → native `<input type="date">`.
  - Payee autocomplete (jQuery UI) → `<datalist>` filled from the account's payees.
  - "Expand bill" (a blocking `$.ajax`) → a lazy-loaded `<turbo-frame>` that requests `show_shares`.
  - Charts: replace the retired `google.com/jsapi` with Google Charts'
    `gstatic.com/charts/loader.js`. Charts look exactly the same and the JSON endpoints don't change.
- [ ] Sign-in (D1):
  - Delete `app/views/devise/*` and replace it with one sign-in page holding a
    "Sign in with Google" button. It must be a `button_to` POST, because
    `omniauth-rails_csrf_protection` rejects GET requests.
  - Add `Users::OmniauthCallbacksController#google_oauth2`:
    - find the user by `provider`/`uid`, or else by verified email
    - create the user if no match
    - store the Google `name`
  - **Only allow invited people in.** Create a `User` only if their Google email matches
    a `Shareholder.email` on some account. Otherwise refuse with a "not invited" message.
    The existing `User#attach_shareholders` callback already links members by email,
    so an invitation is just adding a member with their email address.
  - Remove `configure_permitted_parameters` from `ApplicationController` (there's no sign-up form any more).

## Phase 5: Tests (alongside Phases 3–4)

The current test suite is essentially empty. Add the minimum needed to be confident in the result:

- [ ] Model tests: `calc_shares`, edge cases of `Bill`/`ShareholderBill`/`AccountBill` (shares,
      offset entries, pot), `Shareholder` open/active/closed by date, `locked?`.
- [ ] `Ability` tests: owner/admin/user × own/other entries × locked/unlocked.
- [ ] **Golden test:** import the dump and check that every member's balance, the account balance
      and the pot match `test/fixtures/golden/` to the cent.
- [ ] Browser (system) tests: sign in → add a bill → check balances on the ledger page → export CSV.

## Phase 6: Data import (about 2 evenings; spreadsheet work is separate)

- [ ] `bin/rails import:legacy_dump[postgres://localhost/house_bills_2016]`, safe to re-run:
  - copy tables in dependency order, keeping the original IDs
  - convert `amount` to `amount_cents`
  - copy `versions` with `item_type` unchanged
  - turn off PaperTrail during the import
- [ ] Run the golden test against the imported database.
- [ ] Run `ledger:verify` against the import. Review each difference, then save the
      reviewed ones to `config/ledger_known_differences.yml`.
- [ ] Find the date where the dump ends and the spreadsheet begins. Record each member's
      final balance in the dump, ready for reconciling with the spreadsheet.
- [ ] Spreadsheet import: a separate plan, to be written once the spreadsheet's structure is known.
      It's a separate task because its share-ratio mapping, opening-balance adjustments and second
      balance check are independent of this upgrade. Notes for that plan:
  - Where the spreadsheet's per-person amounts can't be produced by an integer share ratio,
    store them as **explicit share amounts**: a nullable `balance_entries.fixed_amount_cents`
    (or a boolean flag) that tells `Bill#update_balance_entries` not to recalculate that share.
  - Decide whether the bill form should also let people enter explicit amounts going forward,
    or whether explicit amounts are only for imported rows.
- [ ] Set `accounts.lock_records_before` to the switch-over date.

## Phase 7: GCP infrastructure (about 1 evening)

- [ ] Create a GCP project. Set a **budget alert at $1**.
- [ ] Create the VM: **e2-micro, `us-central1`** (or `us-east1`/`us-west1`; the free tier only
      applies in these regions), Debian 12, **30 GB "standard" persistent disk**. The console
      defaults to "balanced", which isn't free. Reserve a static external IPv4 address
      (about $3.65/month).
- [ ] Firewall: allow 22, 80 and 443. Use OS Login or SSH keys, and turn on unattended-upgrades.
- [ ] Add 2 GB of swap. The VM has 1 GB of RAM and Rails + Docker sits close to that.
- [ ] Artifact Registry repo in the same region to hold the Docker image (0.5 GB free).
- [ ] Cloud Storage bucket `house-bills-backups` in the same region:
  - versioning on, soft delete on
  - lifecycle rule: delete `daily/` objects after 30 days
- [ ] Give the VM's service account `roles/storage.objectAdmin` on that bucket only, and
      `roles/artifactregistry.reader` on the image repo.
- [ ] Resolve **D3**, then add a DNS A record pointing at the static IP.
- [ ] Google sign-in setup (in the same GCP project):
  - OAuth consent screen: External, scopes `openid email profile` only. These basic scopes
    don't need Google's app verification, so the app can be set to "In production".
  - Create an OAuth client of type "Web application" with these redirect URLs:
    `http://localhost:3000/users/auth/google_oauth2/callback` and
    `https://<domain>/users/auth/google_oauth2/callback`.
  - Put the client ID and secret in Rails credentials.

## Phase 8: Deployment (about 1 evening)

- [ ] `config/deploy.yml` (Kamal 2):
  - one server, registry = Artifact Registry
  - `proxy: ssl: true, host: <domain>`
  - volume `house_bills_storage:/rails/storage`
  - env: `WEB_CONCURRENCY=1`, `RAILS_MAX_THREADS=3`, `SOLID_QUEUE_IN_PUMA=true`
- [ ] Build the image locally (x86, same as the VM). **Don't build on the e2-micro.** It doesn't have the memory.
- [ ] Container entrypoint:
      `litestream restore -if-db-not-exists -if-replica-exists …` → `bin/rails db:prepare` →
      `litestream replicate -exec "./bin/thrust ./bin/rails server"`.
- [ ] Back up only `production.sqlite3`. The cache and queue databases can be thrown away.
- [ ] `kamal setup`. Then upload the imported database: either copy it into the volume before
      the first boot, or seed the Litestream copy in the bucket and let the restore step pull it.

## Phase 9: Backups and checks (about 1 evening)

Uses the backup layers agreed earlier:

| Layer | Mechanism | Retention |
|---|---|---|
| Record-level undo | PaperTrail | Forever |
| Continuous | Litestream → `gs://…/litestream/` | 7 days |
| Daily | Cron job on the VM: `sqlite3 .backup` + `integrity_check` → `daily/` | 30 days |
| Monthly | `.dump` (plain SQL, gzipped) → `monthly/` | Forever |
| Off-site | `gcloud storage rsync` of `monthly/` to a home machine | Forever |
| Original sources | The original Postgres dump and spreadsheet CSV → `genesis/` | Forever |

- [ ] Weekly test restore: restore from Litestream into a temporary file, run
      `integrity_check`, and compare row counts and balances with the live database.
      Then run `ledger:verify` on it. Record the result in `backup_checks`.
- [ ] Footer visible only to admins: "Last backup · Last verified restore · Ledger: N unexpected differences".
- [ ] Practise once: delete the VM, recreate it, run `kamal setup`, and confirm the data comes back.

## Phase 10: Launch

- [ ] Before launch, check each existing user's email address and member email
      against the Google account that person will actually sign in with. Many 2011-era
      addresses may not be Google accounts, so an admin should update those emails.
      Otherwise the person signs in as a new user and isn't linked to their history.
- [ ] Invite household members: they sign in with Google.
- [ ] Add new members with correct `opened_on` dates.
- [ ] Keep the spreadsheet available read-only until the spreadsheet import is done and checked.

## Phase 11 (optional, after launch): replace `balance_events` with a query

- [ ] Replace the `balance_events` table with a `UNION ALL` of `bills` and
      `account_entries WHERE type = 'ShareholderAccountEntry'`. This can be a SQLite view
      with a read-only `BalanceEvent` model, so the controllers barely change.
- [ ] Port its scopes (text search, bill type, paid by, shared by, changed between dates)
      to that view. The `x_bills`/`x_account_entries` joins become ordinary columns.
- [ ] Remove the callbacks that maintain `balance_events` from `Bill` and `ShareholderAccountEntry`.
- [ ] Check that the ledger, CSV export and pagination give the same results before and after.
      About 1–2 evenings of work.

---

## Effort and cost

| | |
|---|---|
| Effort | About 14–19 evenings part-time, not counting the spreadsheet import (the Bootstrap 5 port adds about 2–3) |
| Ongoing cost | About $3.65/month (IPv4 address); VM, disk, bucket and image storage fall within the free tier |
| Ongoing maintenance | Occasional `bundle update` + `kamal deploy`; Debian security updates install automatically |

## Risks

| Risk | Mitigation |
|---|---|
| Integer-cents `calc_shares` differs from the old float version on some old bills | Stored amounts are copied unchanged, so balances can't move. `ledger:verify` lists the differences; each is reviewed once and added to the allowlist |
| `balance_entries` drifts from the bills (a bug, a bulk change, a manual fix) | `ledger:verify` runs weekly and its result is shown in the admin footer |
| A member's old email doesn't match their Google account, so they appear as a new user | Check and update emails before launch (Phase 10); users are matched by `uid` once they've signed in |
| Old PaperTrail YAML can't be read on Ruby 3.4 | Allow the classes it uses (Phase 3); if some versions still can't be read, keep them as raw text |
| Not enough memory on the e2-micro | 1 Puma worker, jemalloc (Rails 8 Dockerfile default), swap; a larger VM (e2-small) costs about $12/month |
| Free-tier terms change | The Litestream copy and the monthly SQL dumps mean the app can move to any VM in under an hour |
