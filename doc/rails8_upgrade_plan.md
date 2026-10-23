# House Bills: Rails 8.1 + SQLite on GCP

Plan for bringing House Bills back from Rails 4.2 / Ruby 2.2 / Heroku Postgres
(untouched since Oct 2017) to Rails 8.1 / Ruby 4.0 / SQLite on a single GCP
e2-micro VM, deployed with Kamal and backed up to Cloud Storage. All hosting
stays with Google. Expected cost is about $3.65/month, which is the VM's external IPv4 address.

Goals, in order:

1. **Feature parity** with the 2017 app, including permissions, the lock date, the audit
   trail, CSV export and charts.
2. **Every balance correct to the cent.** Each member's balance from the original dump
   must match exactly once it's in the new app.
3. **Familiar screens and workflows.** Nostalgia is part of the point, so pages and
   workflows should look and work the same. The views keep their Bootstrap 3 markup for
   the port; moving to Bootstrap 5 is a later, optional phase (Phase 12).
4. **One continuous dataset.** Load the old dump (2011 to about 2016), then the
   replacement spreadsheet (about 2016 to 2026).

---

## Decisions

| # | Decision | Status |
|---|---|---|
| D1 | **Login** | **Decided: Google sign-in only.** Use Devise with only the `:omniauthable` (Google OAuth), `:rememberable` and `:trackable` modules. No passwords, no confirmation emails, no password resets, so the app needs no email service. |
| D2 | **Styling** | **Decided: stay on Bootstrap 3 for the port.** Load the precompiled Bootstrap 3.4.1 CSS, JS and Glyphicons fonts from `vendor/` (3.4.1 is the final 3.x release and a drop-in replacement for the current 3.3.7, with XSS fixes). The views and their markup stay as they are, which keeps the port smaller and the screens identical. jQuery stays, because Bootstrap 3's navbar collapse and dropdowns need it. Porting to Bootstrap 5 is optional, after launch (Phase 12). |
| D3 | **Domain** for HTTPS and the Google sign-in redirect | **Deferred until Phase 7.** Two things depend on it: kamal-proxy needs a hostname to get a Let's Encrypt certificate, and **Google sign-in only accepts redirect URLs on a real domain** (or `localhost` in development). Development and testing can go ahead without it, but production sign-in can't work until it's chosen. |
| D4 | **Money storage** | **Decided: integer cents** (`amount_cents`). |
| D5 | Keep the precomputed `balance_entries` and `balance_events` tables? | **Decided: keep both for the port.** The amounts stored in `balance_entries` are the record of what each member was actually charged. Copy them unchanged and never recalculate them. Add `bin/rails ledger:verify` to catch the stored rows drifting away from the bills (Phase 3). Optionally, once the port is done, replace `balance_events` with a `UNION ALL` query over bills and member payments (Phase 11). |

---

## Phase 0: Preparation (about 1 evening)

- [x] Create a branch `rails8` so all of the existing git history is kept.
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

Generating a new Rails 8.1 skeleton and moving the app code into it is faster than upgrading
through every version from 4.2 to 8.1, given there are no meaningful tests.

- [x] Generate in the scratch directory:
      `rails _8.1_ new house_bills --database=sqlite3 --javascript=importmap --css=` (no CSS bundler)
- [x] Copy into the repo, replacing the old files: `Gemfile`, `bin/`, `config/` (the new
      files, then reapply `time_zone = 'Pacific Time (US & Canada)'` and the locales),
      `Dockerfile`, `.kamal/`, `config/deploy.yml`, `.ruby-version`, `public/` error pages.
- [x] Delete files that are no longer used: `.ruby-gemset`, `Procfile`, `config/unicorn.rb`,
      `config/newrelic.yml`, `config/initializers/mail.rb` (SendGrid), `vendor/plugins`,
      `script/`, `test/performance`, `lib/legacy_helper.rb`, `lib/tasks/legacy.rake`,
      `db/legacy.rb`, `db/migrate/*`.
- [x] Gem changes:

| Remove | Replace with |
|---|---|
| `unicorn`, `rails_12factor`, `therubyracer`, `figaro` | Puma + Thruster (Rails 8.1 defaults), Rails credentials |
| `pg` | `sqlite3` |
| `sass-rails`, `bootstrap-sass`, `autoprefixer-rails`, `uglifier`, `coffee-rails` | Propshaft; the precompiled Bootstrap 3.4.1 `dist/` files in `vendor/` (D2). No Sass is needed: `application.css.scss` only imports Bootstrap, and the rest is plain CSS |
| `jquery-rails`, `jquery-ui-rails` | jQuery 3.7 in `vendor/`, kept only for Bootstrap 3's JS; Stimulus + native browser features replace jQuery UI and `jquery_ujs` (Phase 4) |
| `csv_builder` | the `csv` gem (a bundled gem since Ruby 3.4, so it must be listed in the `Gemfile`) |
| `validates_timeliness`, `default_value_for` | Native date fields; Rails `attribute ..., default:` |
| `devise` 4.3, `cancancan` 2.0, `paper_trail` 8, `simple_form` 3.5 | Current major versions of each (all still maintained). Keep the existing Bootstrap 3 wrappers in `simple_form_bootstrap.rb` |
| `will_paginate` 3.1, `will_paginate-bootstrap` | Current `will_paginate`. Keep `will_paginate-bootstrap` (Bootstrap 3 markup) if it still loads; otherwise replace it with a small Bootstrap 3 `LinkRenderer` in `app/` |
| - | `omniauth-google-oauth2`, `omniauth-rails_csrf_protection` |

## Phase 2: Schema (about 1 evening)

Write one new migration, `db/migrate/…_create_house_bills.rb`, based on the old `db/schema.rb`, with these changes:

- [x] Remove `enable_extension "plpgsql"` / `"fuzzystrmatch"`. Neither is used.
- [x] `decimal :amount` → `integer :amount_cents, null: false, default: 0` on `bills`,
      `account_entries` and `balance_entries`.
- [x] Add foreign keys and indexes for every `*_id` column. Replace the payee index, which
      is currently unique on `name` across all accounts, with a unique index on `[account_id, name]`.
- [x] Keep the STI `type` columns (each holds the subclass name), `lock_version`, `creator_id`/`updater_id`,
      and the timestamps as they are.
- [x] Keep the `versions` table (PaperTrail) and the `roles` seed data.
- [x] `users`: add `provider` and `uid` (unique index on the pair). Drop the password,
      confirmation, password-reset, account-lock and `authentication_token` columns.
      Keep `name`, `email`, the sign-in tracking columns and the timestamps.
- [x] Add a `MoneyColumn` concern (`money_attribute :amount`). It exposes `amount` /
      `amount=` as `BigDecimal`, backed by `amount_cents`. Views, forms, and the
      reconstruction of old PaperTrail versions (their YAML contains `amount`) then keep working.

## Phase 3: Models (about 2–3 evenings)

Changes required by moving from Rails 4.2 to 8.1:

- [x] `ActiveRecord::Base` → `ApplicationRecord`.
- [x] **In Rails 5+, `belongs_to` is required by default.** Add `optional: true` to every
      association whose column can be null. Examples: `Bill#shareholder`,
      `AccountEntry#bill`/`#shareholder`, `BalanceEntry#bill`/`#account_entry`/`#shareholder`,
      `Shareholder#user`, `BalanceEvent#bill`/`#account_entry`.
- [x] `.uniq` → `.distinct`. Affects `BalanceEntry.unique_shareholders` and
      `ChartsController#balance_line_chart`.
- [x] Raw SQL passed to `order`, `pluck` or `select` must be wrapped in `Arel.sql(...)`. Affects
      `pluck("DISTINCT shareholder_id")` and the `extract(...)` ordering in `Bill` and charts.
- [x] `default_value_for` → `attribute :date, default: -> { Date.current }` etc.
- [x] Postgres → SQLite:
  - `ILIKE` → `LIKE` (`account_entry.rb:19`, `balance_event.rb:46,50`)
  - `extract(month|year from x)` → `CAST(strftime('%m'|'%Y', x) AS INTEGER)`
    (`bill.rb:24-28`, `charts_controller.rb:124-126`)
- [x] **Rewrite `Bill.calc_shares` using integer cents.** It currently mixes `Float` and
      `BigDecimal`. Keep the exact behaviour: the base portion is rounded up to the cent, and the remainder
      goes to the pot. Add unit tests that compare it with the old implementation on every
      bill in the dump.
- [x] **`bin/rails ledger:verify`** (D5). For each bill and member account entry,
      recalculate what its generated rows should be: the share, offset and pot entries,
      the `BillAccountEntry`, and the `balance_event`. Use the record plus the stored `share`
      ratios. Compare against the stored rows and report each difference with the bill id,
      member, stored amount, recalculated amount and the difference. Report only; never
      rewrite the stored rows.
  - `ACCOUNT=<id>` limits it to one account, and `FORMAT=json` gives machine-readable output
    so the weekly check can record the result. It exits 1 when there are unexpected differences.
  - Expected results: the old dump's bills may differ by a cent where the old float
    rounding differs from integer cents. Those are reviewed once and recorded in an
    allowlist (`config/ledger_known_differences.yml`). Anything new beyond that list counts as drift.
  - Shares with an explicit amount (added in the spreadsheet import) are checked against
    their stored amount, not against a recalculation.
- [x] Remove the `*_string` date getters and setters (`'%m-%d-%Y'`) in favour of `<input type="date">`.
      Done in the record forms and their permitted params too. Lists already showed dates
      as `yyyy-mm-dd`, so there's no display format to keep. The search forms' date
      fields still parse `mm-dd-yyyy` until Phase 4 replaces the datepicker.
- [x] PaperTrail: set `config.active_record.yaml_column_permitted_classes` (`BigDecimal`,
      `Date`, `Time`, `ActiveSupport::TimeWithZone`, `ActiveSupport::TimeZone`) so that 2011-era
      versions can still be read and reconstructed.
- [x] **Fix existing bugs found during review:**
  - `AccountEntry#cleared_balance`, `#prior_cleared_balance`, `#this_balance` and
    `#prior_balance` aren't limited to the current account.
  - `BillShareBalanceEntry.shareholder` uses `where(:shareholder_id == s.id)`, which
    compares two values in Ruby and passes `false` to `where`.
  - `Ability`: `can :manage, Payee` has no conditions, so any user can edit any account's payees.
  - `ChartQuery`/`BalanceEventQuery.grouped_shareholders` list members from every account.
  - Remove `bill_account_entries/show` and the six `shareholder_account_entries/*` `GET`
    routes in `config/routes.rb`. They're left over from code generators, and one of them is a GET `destroy`.
  - **`creator_id`/`updater_id` haven't been set since January 2015**, when the Rails 4.1 upgrade
    removed the `userstamp` gem. `Ability` still uses `creator_id` to let members edit their own
    entries, so ordinary members can't edit anything they've entered since then. Set both
    columns from the signed-in user again (e.g. `Current.user` plus a `before_save` concern),
    and backfill the legacy rows during the import (Phase 6).
- [x] Money (D4), found while writing the schema:
  - `include MoneyColumn` + `money_attribute :amount` in `Bill`, `AccountEntry` and `BalanceEntry`.
  - `ShareholderBill` and `ShareholderAccountEntry` copy `amount` into their offset entries
    with `self[attr]`, which reads the column directly and bypasses `MoneyColumn`. Copy
    `amount_cents` instead.
  - SQL sums (`sum(:amount)`, `SUM(amount)`, `sum("bills.amount")`, the `amount >= 0` scopes)
    must use `amount_cents`, and the Ruby side divides by 100.
- [x] The `BillShareBalanceEntry`, `BillOffsetBalanceEntry`, `PotBalanceEntry` and
      `AccountOffsetBalanceEntry` subclasses declare `belongs_to :balance_event`, but
      `balance_entries` has no `balance_event_id` column. Remove those associations.
- [x] More bugs found while porting the models:
  - `Ability` used `cannot :delete, Account`, but the destroy action checks `:destroy`, so
    admins who aren't owners could still delete an account (only the button was hidden).
  - `AccountEntry#cleared_balance`/`#prior_cleared_balance` were missing parentheses, so
    uncleared entries on the same date were counted in the cleared balance.
  - `ChartsController#balance_line_chart` called an undefined `query` and failed on every request.
    It and `bill_types_by_month_line_chart` aren't linked from any page; consider deleting them in Phase 4.
  - `Date.today` (the server's time zone, UTC on Heroku and on the VM) → `Date.current` (Pacific),
    for defaults, "open now"/"active now" and the default search ranges.
  - PaperTrail 10+ no longer records `whodunnit` automatically; `ApplicationController` now
    calls `set_paper_trail_whodunnit`, and sets `Current.user` for the userstamps.
  - `AccountEntryQuery`, `BalanceEventQuery` and `ChartQuery` moved from their controller files
    to `app/models/` so they autoload. `AccountEntryQuery.grouped_shareholders` was also scoped to the account.
- [ ] **Open question:** `Shareholder#admin?` checks for a role named `Administrator`, but the
      seeds create `User`, `Power User` and `Owner`. Check the dump's `roles` table: if it
      has no `Administrator`, then only owners have admin rights, and `Power User` may have been meant.
- [x] With foreign keys in place, destroying a member or bill type that still has entries now
      fails instead of leaving orphaned rows. Add `dependent: :restrict_with_error` to
      `Shareholder#bills`/`#account_entries`/`#balance_entries` and `BillType#bills`, and show
      the error on the page.

## Phase 4: Controllers, views, JS (about 2–3 evenings)

- [x] `before_filter` → `before_action` everywhere.
- [x] Routes: Rails no longer supports dynamic `:action` route segments
      (`get 'charts(/:action)' => 'charts#:action'`). Replace them with explicit chart routes.
- [x] CSV export (`balance_events`, `account_entries`): use `respond_to { |f| f.csv { send_data … } }`
      with a small exporter class built on `CSV.generate`. Keep the 250-row limit.
- [x] Delete links: `link_to … method: :delete` → `button_to` (Turbo), and
      `data: { confirm: }` → `data: { turbo_confirm: }`. This keeps the "Delete Account For Ever and Ever"
      confirmation.
- [x] simple_form: keep the existing Bootstrap 3 initializer (`simple_form_bootstrap.rb`).
      Don't run `rails g simple_form:install --bootstrap`, which now generates Bootstrap 5
      wrappers. Check the wrappers still load on current simple_form and fix any renamed options.
- [x] Bootstrap 3 assets (D2): put Bootstrap 3.4.1's `dist/` folder in `vendor/bootstrap/`
      with its `css/` and `fonts/` layout unchanged. Then the Glyphicons `../fonts/` URLs in
      `bootstrap.min.css` still resolve, and Propshaft rewrites them to digested paths.
      Load `bootstrap.min.css` before the app's stylesheet. Load jQuery and `bootstrap.min.js`
      as classic `<script>` tags in the layout, not as importmap modules, because Bootstrap 3's
      plugins expect a global `jQuery`. Its data-api handlers are attached to `document`, so the
      navbar collapse and dropdowns keep working across Turbo page changes.
- [x] Views: no markup port. The Bootstrap 3 classes, Glyphicons, navbar and
      `will_paginate` calls stay as they are. The only view changes are the Turbo, date-field
      and sign-in changes in this phase.
- [x] Rename `application.css.scss` to `application.css`. Remove the `@import "bootstrap…"`
      lines and the Sprockets `*= require` directives, keep the overrides as they are, and delete the
      jQuery UI theme images in `app/assets/stylesheets/images/`.
- [x] Rewrite `application.js` (about 90 lines of jQuery) as Stimulus controllers. Remove
      `jquery_ujs` and jQuery UI; jQuery itself stays only for Bootstrap 3:
  - `search-toggle`: show/hide the filter form and remember the choice in a cookie. This could use
    Bootstrap 3's `collapse` plugin plus a few lines to set the cookie.
  - Datepicker → native `<input type="date">`.
  - Payee autocomplete (jQuery UI) → `<datalist>` filled from the account's payees.
  - "Expand bill" (a blocking `$.ajax`) → a lazy-loaded `<turbo-frame>` that requests `show_shares`.
  - Charts: replace the retired `google.com/jsapi` with Google Charts'
    `gstatic.com/charts/loader.js`. Charts look exactly the same and the JSON endpoints don't change.
- [x] Sign-in (D1):
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
- [x] Notes from doing Phase 4:
  - CSV export keeps the existing `output=CSV` form button (no `.csv` URLs), with `send_data` and
    `BalanceEventsCsv`/`AccountEntriesCsv` built on `CSV.generate`. An empty result now exports just
    the header row instead of crashing.
  - Delete controls use `data-turbo-method`/`turbo_confirm` links where they were links (to keep the
    look), and `button_to` with `form: { data: { turbo_confirm: } }` where they were buttons. Redirects
    after a delete return 303, and failed form submissions render with 422 so Turbo shows the errors.
  - Removed the two chart actions no page linked to (`balance_line_chart`, `bill_types_by_month_line_chart`)
    and the dead `balance_events#chart` route.
  - Sign-in: `users.remember_token` was added to the schema migration (Devise's remember-me needs it
    without passwords). Member and user emails now match case-insensitively. Members are remembered for a year.
  - Local sign-in before the OAuth client exists: `DEV_GOOGLE_EMAIL=you@example.com bin/rails server`
    (development only, via OmniAuth test mode).
  - Bugs found and fixed:
    - `update_cleared` passed the whole form to `AccountEntry.update`, unscoped: any signed-in user
      could change any field (including the amount) of any account's entries by id. It now updates
      only `cleared`, only on this account's entries the user may update.
    - Exporting more than 250 events set the error but never loaded the page's rows, so the page crashed.
    - The ledger CSV called a nonexistent `AccountEntry#balance`, so ledger export always failed.
    - The account overview's tab script used a selector jQuery 3 rejects, so no tab worked.
    - The bill form's Delete button checked `:delete`, which the lock-date rule doesn't cover, so locked
      bills showed a button that then failed. The bill type Delete link had no permission check.
    - Chart drill-down links pass ISO dates, which the old `mm-dd-yyyy` parsing rejected.
  - Checked in a browser against the dev server: sign-in, activity page, search toggle, Expand,
    navbar dropdowns, chart, overview tabs (also after a Turbo visit), ledger, and entering a bill
    including a validation error.

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
  - convert `amount` to `amount_cents`. `balance_entries.amount` was nullable, so report
    any NULLs instead of silently storing 0
  - copy `versions` with `item_type` unchanged
  - turn off PaperTrail during the import
  - turn off foreign-key enforcement while copying, then run `PRAGMA foreign_key_check`
    and report any orphaned references (for example a `creator_id` pointing at a deleted user)
  - backfill missing `creator_id`/`updater_id` on 2015–2016 rows from the `whodunnit` of
    their PaperTrail `create`/`update` versions (see Phase 3)
  - check whether `account_entries.balance_offset_id` or `balance_entries.is_pot_entry`
    hold any data. The 2017 code never reads them; if they're empty, drop both columns
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
      applies in these regions), Debian 13, **30 GB "standard" persistent disk**. The console
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

## Phase 12 (optional, after launch): port to Bootstrap 5

About 2–3 evenings. Pages and workflows stay the same; only the markup and styling change.

- [ ] Replace the vendored Bootstrap 3 files with Bootstrap 5.3's CSS and JS bundle (which
      includes Popper), loaded through importmap, plus Bootstrap Icons. Remove jQuery.
- [ ] simple_form: regenerate the initializer with `rails g simple_form:install --bootstrap`,
      which produces Bootstrap 5 wrappers. Delete the old `simple_form_bootstrap.rb`.
- [ ] Port the views. There are about 45 Bootstrap 3-specific class names across
      roughly 1,100 lines of ERB:
  - `glyphicon-*` → Bootstrap Icons (`bi-*`)
  - `well` / `panel` → `card`
  - `pull-right` → `float-end`
  - `col-sm-offset-*` → `offset-sm-*`
  - `btn-default` → `btn-secondary` / `btn-outline-secondary`
  - `form-horizontal` / `control-label` → grid `row` + `col-form-label`
  - `data-toggle` / `data-target` → `data-bs-toggle` / `data-bs-target`
  - the navbar markup in `layouts/_menu.html.erb` (BS5 expects different collapse markup)
  - Pagination: switch to `pagy` and `pagy_bootstrap_nav`, or a Bootstrap 5 `will_paginate` renderer.
- [ ] Replace the CSS overrides in `application.css` (negative margins on
      `.search-toggle` and `.delete-button`, fixed widths) with BS5 utility classes where possible.
- [ ] Switch the `search-toggle` Stimulus controller to BS5's `collapse` component.
- [ ] Compare each page against screenshots taken before the port.

---

## Effort and cost

| | |
|---|---|
| Effort | About 12–16 evenings part-time, not counting the spreadsheet import or the optional phases (the Bootstrap 5 port in Phase 12 adds about 2–3) |
| Ongoing cost | About $3.65/month (IPv4 address); VM, disk, bucket and image storage fall within the free tier |
| Ongoing maintenance | Occasional `bundle update` + `kamal deploy`; Debian security updates install automatically |

## Risks

| Risk | Mitigation |
|---|---|
| Integer-cents `calc_shares` differs from the old float version on some old bills | Stored amounts are copied unchanged, so balances can't move. `ledger:verify` lists the differences; each is reviewed once and added to the allowlist |
| `balance_entries` drifts from the bills (a bug, a bulk change, a manual fix) | `ledger:verify` runs weekly and its result is shown in the admin footer |
| A member's old email doesn't match their Google account, so they appear as a new user | Check and update emails before launch (Phase 10); users are matched by `uid` once they've signed in |
| Old PaperTrail YAML can't be read on Ruby 4.0 | Allow the classes it uses (Phase 3); if some versions still can't be read, keep them as raw text |
| Not enough memory on the e2-micro | 1 Puma worker, jemalloc (Rails 8.1 Dockerfile default), swap; a larger VM (e2-small) costs about $12/month |
| Bootstrap 3 and its jQuery dependency have had no fixes since 2019 | 3.4.1 includes the last XSS fixes. The app only uses the collapse and dropdown plugins (no tooltips or popovers with user content), and the assets are served locally. Phase 12 removes both |
| Free-tier terms change | The Litestream copy and the monthly SQL dumps mean the app can move to any VM in under an hour |
