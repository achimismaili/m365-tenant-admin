# T2 — pilot preconditions and redacted ground-truth index

**Classification: REDACTED — safe to commit.** This file is the public counterpart of a secured raw
artefact. It carries document identifiers, cryptographic hashes, document types and the *semantics*
of every expected field — never a value. No tenant identifier, site or library URL, subscription or
resource-group ID, file path, vendor name, monetary amount or document date appears anywhere below.

| | |
|---|---|
| Produced | 2026-08-30T20:01:48Z |
| Annotator | AI-agent-assisted, 2026-08-30T20:01:48Z, **human-review-pending** |
| Method | offline, read-only inspection of an already-local document set |
| Mutations performed | **none** — no source file was copied, moved, renamed or modified |
| Tenant access performed | **none** — no SharePoint, Graph or live tenant was contacted |
| Raw counterpart | `docs/evidence/raw/t2-target-and-ground-truth.md` (git-ignored, secured) |
| SHA-256 of the raw counterpart at freeze time | `cc369e23b55e81bac6d124e7dbeb6c685cf209770a1091f32ab28ff3dafbbb12` |

---

## 1. Live pilot target — not yet determined

**Live pilot target (tenant/site/subscription) not yet determined — pending human operator input.
Admin role/Azure Owner access not confirmed in this offline pass.**

This todo ran entirely offline and deliberately contacted nothing. Every value the live todos need is
therefore recorded as unknown rather than guessed:

| Value required before T6 can run | State |
|---|---|
| Tenant-admin URL | NOT DETERMINED |
| Azure subscription ID | NOT DETERMINED |
| Azure resource group | NOT DETERMINED |
| Billing region (stores tenant ID and usage metadata including site names — disclose to the owner) | NOT DETERMINED |
| Pilot site URL | NOT DETERMINED |
| Dedicated pilot library name (a **new** library, created by T6; never a production library) | NOT DETERMINED |

| Access precondition | State |
|---|---|
| SharePoint Administrator or Global Administrator | **NOT CONFIRMED** |
| Azure **Owner** or **Contributor** on the billing subscription and resource group | **NOT CONFIRMED** |
| Content-center / model-creation permission | **NOT CONFIRMED** |
| Syntex-eligible licence verified in the target tenant | **NOT CONFIRMED** |

No credential, device-login session or cloud context was available to this pass, and none was
attempted. **T6 is blocked on human operator input.** The raw counterpart carries the same table as a
fill-in handoff form.

### Spend context for whoever unblocks it

The frozen sample totals **119 PDF pages across 37 documents**. Order-of-magnitude cost per full pass
of the sample, before any re-run: roughly one to six US dollars depending on which capability tier is
exercised — prebuilt processing being the cheapest per page and structured/freeform the dearest.
Confirm the current published per-page rates at run time (the client runbook owns that citation) and
set the T6 ceiling from them. Uploads, subsequent updates and failed pages are all billed, and each
applied model is metered separately, so re-running an experiment re-bills its pages.

---

## 2. Sample sizing verdict

### `sample: DECISIVE`

Every declared threshold is met, without padding and without reclassifying a document to make a count
work. Two documents were in fact moved *out* of the class their filename implied, after their content
was read (see §4).

| Class | Contract | Achieved | Verdict |
|---|---|---:|---|
| **INV** — invoices spanning distinct vendor/layout families | ≥ 10 across distinct families | **14 documents / 12 distinct layout families** | MET |
| **BES** — property-tax and municipal assessment notices | ≥ 5 | **8** | MET |
| **SET** — utility settlements | ≥ 5 | **6** | MET |
| **NON** — non-invoice correspondence | ≥ 5 | **9** | MET |
| Total held-out sample | — | **37 documents · 119 PDF pages** | |

### What "decisive" does and does not license

`DECISIVE` here is defined strictly by the count contract, which is met. It does **not** mean the
result will generalise without qualification. A downstream verdict must state these bounds:

- Single owner, single region, two municipal issuers and one waste authority. Assessment-notice
  layouts differ between German federal states; this sample covers one.
- All documents are German. No conclusion about any other language is supportable.
- N = 37. In a six-document class, one document is 17 percentage points.
- Scanned documents come from one scanner family, so OCR quality is homogeneous and probably better
  than a mixed-source corpus would be.

### Train/holdout separation

Every one of the 37 documents is **held out** and must never be used to train a custom model. The
wider source set supplies a disjoint training pool that clears the 5–10 documents per class that a
custom-classification experiment needs, in every class, without touching the holdout set. Counts are
recorded in the raw counterpart.

---

## 3. Redacted index

Column meanings:

- **doc-id** — the stable pseudonym used by every later todo. Never substitute a filename.
- **sha256** — of the source file. Safe to commit; proves the scored document is the frozen one.
- **fam** — layout-family pseudonym. Two documents sharing a letter share an issuer and template.
- **pg** — PDF pages. **lg** — logical documents contained in the file.
- **expected-field semantics** — the exact meaning of each field the ground truth pins, with no
  values. `∅` marks fields the document genuinely does not carry, where any extraction is a false
  positive.

### Class INV — invoices (14)

| doc-id | sha256 | fam | document type | pg | lg | expected-field semantics |
|---|---|---|---|---:|---:|---|
| sample-001 | `07bddcf511f25d387f107d695c9e749931258d609ab8ef5434071c23d6ed537b` | A | insurance premium invoice (property) | 4 | 3 | issuer · document-date · total-amount-gross · insurance-tax-amount · coverage-period · customer-name · insured-property · ∅ invoice-number (policy number only) · ∅ due-date |
| sample-002 | `b07b30102c67f71e88da9f6ca654614c23a2d34c6afa813b8b46730c13455d2b` | A | insurance premium invoice (building) | 2 | 1 | issuer · document-date · total-amount-annual · insurance-tax-amount · installment-amount ×2 · installment-due-dates ×2 · coverage-period · insured-property · ∅ invoice-number · ∅ single due-date |
| sample-003 | `d1ed5c85517cf7db8fe91cada783d9172a2336aa4610848d0e2c65a6e68263ef` | B | chimney-sweep services invoice | 3 | 2 | vendor · invoice-number · customer-number · document-date · service-date · net-amount · tax-amount · total-amount · billed-property · ∅ due-date (direct-debit date only) |
| sample-004 | `d09969e5bae24e66466ad1645088951a1ccf87deab63ec87ff61bfff66f52b29` | C | chimney-sweep services invoice | 4 | 2 | vendor · invoice-number · customer-number · document-date · service-date · net-amount · tax-amount · total-amount · billed-property · ∅ due-date |
| sample-005 | `96fc92991f50d3d1015e152050defa7f0348e2f4a4a7cab1d5280c738104fde8` | D | utility-metering service invoice | 2 | 1 | vendor · invoice-number · customer-number · document-date · service-date · net-amount · tax-amount · total-amount · **due-date (explicit)** · property reference |
| sample-006 | `b953ac52d82c652b6756cd746cdcc61a2cbf6fa02d34b6f26863d438f3452a13` | D | equipment-rental annual invoice | 2 | 1 | vendor · invoice-number · customer-number · document-date · service-period · total-amount · tax-amount · **due-date (explicit)** · contract-number · property reference |
| sample-007 | `26121a8a0d754f33eb7e25b6341cd36db5d087e5447113727e59cc9c7906bd14` | E | electrical trade invoice | 2 | 1 | vendor *(low-confidence: letterhead OCR degraded)* · invoice-number · document-date · net-amount · tax-amount · total-amount · ∅ due-date (payment term only) · ∅ service-period |
| sample-008 | `0081d7df96e2abc52089b76bc605fd536d78ebdf2fd5c062723ffc375897528e` | F | final trade invoice with prior installment deducted | 4 | 1 | vendor *(low-confidence)* · invoice-number · document-date · service-date (year only) · net-amount · **amount-due-after-installment** · **contract-total-gross** · prior-installment reference · ∅ due-date |
| sample-009 | `2038c34cada2a2d24a66d682bbbed4185c8e574fdcf27aaeb5aa7b7819d616f1` | G | flooring trade invoice | 4 | 1 | vendor · invoice-number · document-date · net-amount · tax-amount · total-amount · labour-share-net · material-share-net · billed-object · ∅ due-date · service-period **UNVERIFIED (ambiguous as printed — excluded from scoring)** |
| sample-010 | `de9dc8b912e61d2d7abb5c55211ca93b49fe742304077b898f6c3d5510b9b9cb` | H | telecom monthly invoice | 3 | 1 | vendor · invoice-number · customer-number · customer-account · document-date · billing-period · total-amount · tax-amount · ∅ due-date (direct-debit date only) · contains a negative discount line |
| sample-011 | `2d26d8bc7fe5149ab85f5780f35bdcad1958a357fb577d5085467a9d86983799` | I | retail goods invoice (marketplace channel) | 1 | 1 | **vendor = issuer, not the marketplace** · invoice-number · order-number · customer-number · document-date · order-date · delivery-date · net-amount · tax-amount · total-amount · ∅ due-date |
| sample-012 | `ecac4ed4211384f1468df5dab1be6e2a8247581738bb1c1d54a364f03ddcca8c` | J | heating-maintenance trade invoice | 1 | 1 | vendor · invoice-number · customer-number · document-date · service-date (= document-date, stated) · net-amount · tax-amount · total-amount · **due-date (explicit)** |
| sample-013 | `723b7ef45b3a4db034da6db8249cfb9d10d11f04498452d75b85895f9cfc53dd` | K | trade invoice (flue and pipework) | 1 | 1 | vendor *(low-confidence)* · invoice-number · document-date · **due-date (explicit)** · service-date · net-amount · tax-amount · total-amount |
| sample-014 | `34ba9479aae0c8d0880d96e76c32f806234d707913038f8acbf45251c51e3d3c` | L | heating maintenance and repair invoice | 4 | 1 | vendor · invoice-number · project-number · customer-number · document-date · service-period · net-amount · tax-amount · total-amount · labour-included-in-total · ∅ due-date |

Twelve distinct layout families (A–L) across fourteen invoices; families A and D contribute two each,
deliberately, to expose within-family layout drift (one digital-born original versus one scanned copy).

### Class BES — property-tax and municipal assessment notices (8)

Common to the class: **∅ invoice-number, ∅ commercial vendor, ∅ single due-date, ∅ VAT.** The
scoreable amount is **assessment-amount**, which is a different semantic from invoice-total and must
not be compared against it.

| doc-id | sha256 | fam | document type | pg | lg | expected-field semantics |
|---|---|---|---|---:|---:|---|
| sample-015 | `2148494c8d352909940f56d5b1a77314aaeba65a263cbe381235db6723d3b4fb` | M | property-tax and levy assessment notice | 3 | 2 | issuing-authority · document-date · assessment-year · assessment-period · **assessment-amount** · 3 named components · 4 statutory installments with dates · payment-method · ∅ invoice-number · ∅ single due-date · ∅ VAT · ∅ commercial vendor |
| sample-016 | `0f889d49c8210cd37e7e7ae5c127a86b756346dcd73fc93c9ccd9dc42cc24073` | N | municipal utility-charges assessment notice | 2 | 1 | issuing-authority · authority document-number · document-date · assessment-year · **assessment-amount** · 8 named components (two are **negative** credits) · 4 installments with dates · meter reading and consumption · ∅ single VAT · ∅ single due-date · billed-property **not determinable from content** |
| sample-017 | `c99c27ce019682ddda78fe8ea82ba4cda265597b62407b1b560b64ad68da1634` | N | municipal utility-charges assessment notice | 4 | **2 independent notices** | per notice: issuing-authority · document-date · assessment-year · **assessment-amount** · named components · 4 installments with dates; notice A also consumption; two components **UNVERIFIED (excluded from scoring)** |
| sample-018 | `1547b42c59dc2b2efe99e2c320e6572c0f40c9b050f8f975f9082d0d650678df` | O | property-tax assessment notice | 2 | 1 | issuing-authority · document-date · assessment-year · assessment-period · **assessment-amount** · assessment-basis (rate × multiplier) · file-reference · underlying-notice date · assessed-property · 4 installments with dates · prior-payments · ∅ invoice-number · ∅ VAT · ∅ vendor |
| sample-019 | `abaad397ef5291dc183a11f5dde72ff607b4ec0eaca308f0ebba69b2d144fefd` | O | property-tax assessment notice | 3 | 2 | same field set as sample-018; **same property and file-reference, adjacent assessment year, changed multiplier** — a cross-document consistency control |
| sample-020 | `2455d5af6bbb73b267ec2b48865f6d6817fd827bacd95fb6b8a9d4bc4636ecad` | P | waste-disposal fee amendment notice | 2 | 1 | issuing-authority *(low-confidence: letterhead absent from content)* · document-date · assessment-year · **assessment-amount-for-year** · **previously-assessed-amount** · **outstanding-balance** · one **negative** installment with date · one positive installment with date · assessed-property · container registrations · ∅ invoice-number · ∅ VAT |
| sample-021 | `9069ae762ae65b571c9eeff5cf1ff9539f7ab095da76b4e0f4ef404a85990ab6` | P | waste-disposal fee amendment notice | 2 | 1 | same field set as sample-020 — same issuer, same day, same template, different property: a layout-consistency control |
| sample-022 | `c3e578a97aeadd6619951f992095ad5e537392cc99f79b9f525aec66096c4b2b` | M | property-tax assessment notice | 3 | 2 | issuing-authority · document-date · assessment-year · assessment-period · **assessment-amount** · assessment-basis · 4 installments with dates (**first date deviates from the statutory pattern printed in the same document**) · payment-method **differs from sample-015 despite the same issuer and template** · ∅ invoice-number · ∅ VAT · ∅ vendor |

### Class SET — utility settlements (6)

| doc-id | sha256 | fam | document type | pg | lg | expected-field semantics |
|---|---|---|---|---:|---:|---|
| sample-023 | `07b1ca30c0a91431f51cfb5fa488611424aafe7669edfa5970e48917b36abef6` | Q | energy feed-in annual settlement — **result is a credit to the recipient** | 6 | ≥2 | issuer · document-date · settlement-number · contract-account · **settlement-period** · 3 components (two **negative**) · **balance-in-recipient's-favour** · energy quantity · zero-rated VAT · forward installment schedule (paid **to** the recipient) · ∅ due-date · ∅ amount-payable |
| sample-024 | `097ee20a24f4cb7a9e1234c7be7efbf3b517e6f60acbc3ac248bc67e67f34fe8` | Q | energy feed-in settlement — **result is payable by the recipient** | 7 | 2 | same field set as sample-023 but **balance-payable-by-recipient** and a **due-date (explicit)** — a deliberate direction/sign pair with sample-023 and sample-025 on an identical template |
| sample-025 | `1826928aa5cbd8c6a34a0491291c6943612cc8b40a7a440e28d8d808f4e9990e` | Q | energy feed-in annual settlement — **result is a credit** | 6 | ≥2 | as sample-023 |
| sample-026 | `a501341c04f1148a06f828cf412a973da4ba51e5588f2043aac8106ffef8d6e9` | D | heating-cost total settlement, multi-unit building | 12 | 1 | issuer · document-date · **settlement-period** · customer-number · settlement-unit reference · property reference · **total-costs-to-allocate** · balance · unit and occupant counts · ∅ invoice-number · ∅ due-date · ∅ total-level VAT |
| sample-027 | `06a9952e8525f516f965a5a1659a426b2a7628c465ef406ee8fe5f95942cad4a` | O | prior-year utility settlement **combined with** a forward prepayment assessment | 4 | 1 (two classes in one notice) | issuing-authority · authority document-number · document-date · **settlement-period** · **prepayment-period** · settlement-total · residual · prepayment-total · overall-total · one named component with net/VAT split · ∅ single VAT · component column mapping and installment schedule **UNVERIFIED (excluded from scoring)** |
| sample-028 | `6569f4ea1baeacede129b00b41baac2d302a7f0564ea3b110974383e80ada5c6` | R | heating-electricity consumption invoice with a new installment plan | 6 | 1 | vendor · document-date · invoice-number · contract-account · **billing-period** · net · VAT · **period-cost-gross** · **outstanding-balance** · **first-new-installment** · **amount-actually-debited (= balance + installment)** · debit-date · recurring installment plan · tariff name · consumption (contains **negative** sub-meter deltas) · ∅ due-date |

### Class NON — non-invoice correspondence (9)

Purpose: measure the **false-positive rate** of an invoice model. Correct behaviour on every one of
these is to decline or return low confidence. All of them carry invoice-shaped decoys — bank
identifiers, creditor IDs, customer numbers, tax IDs, dates, and in several cases the literal word
for "invoice".

| doc-id | sha256 | fam | document type | pg | lg | expected-field semantics |
|---|---|---|---|---:|---:|---|
| sample-029 | `8c2146817cd4dc16ddcabeaa48528a1937f0e7288c797c7220b81e143069afde` | R | contract-termination confirmation | 1 | 1 | issuer · document-date · contract-end-date · requested-action · **∅ invoice-number · ∅ total-amount · ∅ due-date · ∅ tax-amount · ∅ net-amount · ∅ service-period** |
| sample-030 | `383f4458e0c8d4daee739703003c485ef8c90a6605c8989062a4d2c7bedd679a` | Q | price-adjustment notice | 2 | 1 | issuer · document-date · effective-date · contract-account · customer-number · meter-number · **∅ invoice-number · ∅ total-amount · ∅ due-date · ∅ tax-amount** (decoy: the text discusses cancellation and corrected invoices) |
| sample-031 | `b1bb868b01a2fc103c1fa4b5ca5e2d00f05a2dc5997382cdaeb064040566be9c` | Q | meter-exchange appointment notice | 3 | 1 | issuer · document-date · appointment-date and window · meter-identifier · explicit no-charge statement · **∅ invoice-number · ∅ total-amount · ∅ due-date · ∅ tax-amount** |
| sample-032 | `0d8ffdeb53286bbce2b060a850b8e91a8a249c9334d9d147365f0763c4e961ab` | Q | advance meter-rollout announcement | 2 | 1 | issuer · contract-account · customer-number · **∅ document-date (none printed; only a postal franking imprint, which is not a document date)** · **∅ invoice-number · ∅ total-amount · ∅ due-date · ∅ tax-amount** |
| sample-033 | `b537624417c5d5acc9f19587002c65a58d0947c58e0771195c73d3d50cc9b031` | S | meter-reading request with reply slip | 2 | 1 | issuing-authority · document-date · response-deadline · meter-identifier · previous-reading · meter-location · **∅ invoice-number · ∅ total-amount · ∅ due-date · ∅ tax-amount** |
| sample-034 | `ac24d31d4547668cc78e91027b50a930d9a763d7d7cc8aabefeee1ae6cf8e4e8` | S | meter-reading requests | 10 | **5 independent requests** | per request: issuing-authority · document-date · response-deadline · meter-identifier · meter-location · **∅ invoice-number · ∅ total-amount · ∅ due-date · ∅ tax-amount** |
| sample-035 | `b65885456734336a869e85034793c4392ee37f521b3db6ee03c11550b59306c9` | M | informational insert on a tax reform | 1 | 1 | **∅ issuer · ∅ document-date · ∅ assessment-amount · ∅ assessment-year · ∅ invoice-number · ∅ total-amount · ∅ due-date · ∅ tax-amount** — the assessment-notice false-positive control; reads like a notice but assesses nothing. Also bound in as a page of sample-015 and sample-019, so it doubles as an insert-versus-standalone control. |
| sample-036 | `0c58c6d5efefd9136113bd9ab4db79ca745f4cdc0bee70768c6f77d2f1a4d62b` | H | billing-procedure change notice | 2 | 1 | issuer · document-date · customer-number · **∅ invoice-number · ∅ total-amount · ∅ due-date · ∅ tax-amount · ∅ billing-period** — same issuer and customer number as sample-010, so a vendor-keyed heuristic mis-routes it |
| sample-037 | `f80d0a942a6e9e6f8473b21c5dfcd3a5400e8c5d2c8d39a92d5fcd64b9f3abe2` | R | payment reminder for an unpaid installment | 2 | 1 | issuer · document-date · **outstanding-amount (a dunned balance, not an invoice total)** · **pay-by-date** · referenced-item reference · contract-account · **∅ invoice-number · ∅ net-amount · ∅ tax-amount · ∅ service-period** |

---

## 4. Findings that constrain how T7 and T8 must be run

### 4.1 Filenames are not evidence — 8 of 37 disagree with their content

Content inspection contradicted the filename in eight cases. Two are decisive for the pilot design:

- **Two assessment notices are named for one year and are headed with the next.** Any pipeline that
  derives a relevance year from a filename gets both wrong.
- **One document named "final invoice" is a payment reminder about a final invoice.** The pre-existing
  filename-based enumeration this sample was built on classified it as an invoice; reading it
  reclassified it into the non-invoice class. That single correction is the whole argument for the
  open-the-file rule in `tools/syntex-setup/pilot-sample.md`.

Others: an issue date that differs from the filename's date; a retail invoice named for the
marketplace rather than the issuing seller; two vendors whose legal name differs from the filename's
trading name; and a numeric filename prefix that is a scanner artefact, not a date.

**Consequence for scoring:** ground truth is what the document says. Where a filename disagrees, the
filename is wrong. Do not let a filename-derived expectation enter the T8 comparison.

### 4.2 One file is not one document — 8 of 37 (22 %)

Two files contain genuinely independent documents of the same class (one holds **2** assessment
notices; one holds **5** meter-reading requests). Six more bundle a primary document with a
certificate, an information insert, a questionnaire, a refund notice or a blank form. Three settlement
files bind a settlement together with a forward installment plan.

**Consequence for scoring:** document-level completeness must be measured against the *logical*
document count in the `lg` column, and a run that returns one result for a multi-document file is an
incompleteness, not a mere inaccuracy. Decide before scoring — and record the decision — whether a
settlement-plus-installment-plan mailing counts as one document or two; do not settle it after seeing
the results.

### 4.3 Blank versos are billed

Six files are duplex scans with empty backsides: at least 8 of the sample's 119 pages carry no
content whatsoever and will still be metered per page. Any cost projection built from document counts
rather than page counts understates by roughly 7 % on this sample.

### 4.4 A due-date accuracy figure mostly measures correct silence

Only **3 of 14** invoices carry an unambiguous printed due date. The rest print a payment *term*, a
**direct-debit date**, or a **coverage period** whose label shares a stem with the word for
"due" — a deliberate trap. Across the whole 37-document sample, "return no due date" is the correct
answer far more often than any date is.

**Consequence:** report due-date precision and recall separately, and report the false-positive rate
on the documents where the expected value is `∅`. A single blended due-date accuracy number is
meaningless here.

### 4.5 "Total" is not one semantic

Distinct money semantics present in this sample, each pinned separately in the raw ground truth:

invoice total (gross) · net versus tax versus gross · installment · balance remaining after an
installment · amount actually debited (balance + next installment) · assessment amount ·
previously-assessed amount · outstanding balance after an amendment · credit or negative balance ·
contract total spanning several invoices.

Three documents print three plausible "totals" each. One prints seven per-occupant amounts labelled
with the word "invoice amount" before the single correct total. Two settlements resolve to a credit
*to* the recipient rather than a payable, on the same template as a third that resolves to a payable.

**Consequence:** every row of the T8 field table must name the exact semantic being scored, and
direction (payable versus receivable) must be scored, not just magnitude. A single `TotalAmount`
column cannot represent this sample.

### 4.6 Fields deliberately excluded from scoring

Four field values are recorded as **UNVERIFIED** because the source could not be read reliably
offline, and are excluded from T8 field-accuracy scoring rather than guessed:

| doc-id | field | reason |
|---|---|---|
| sample-009 | service-period | printed value is internally inconsistent with the document date; not resolvable from the document |
| sample-017 | two forward-prepayment components | labels legible, amounts not recoverable from the text layer |
| sample-027 | component column mapping | four interleaved numeric columns; the arithmetic does not reconcile, so the mapping cannot be inferred safely |
| sample-027 | installment schedule | dates and amounts both legible, but no ordering reconciles them to the stated total |

Three vendor names are marked **low-confidence** because their letterheads did not survive scanning;
score vendor-name accuracy leniently on those three or exclude them, and say which was done.

### 4.7 Content quality of the frozen set

All 37 documents yielded a machine-readable text layer, so **no document in this sample rests on its
filename alone**. Seven are digital-born and clean; the remainder are scanned with an embedded OCR
layer of varying quality. This describes the *local* text layer used to freeze ground truth, not the
service under test — measuring the latter is the point of the pilot. Where the local text layer and
the document's evident meaning conflicted, the value was marked UNVERIFIED rather than guessed.

### 4.8 Personal data must be acknowledged before upload

Several documents in the sample identify third parties and tenancies, and one names individual
occupants alongside their consumption data. Uploading the sample to a cloud pilot library moves real
personal data off the local machine. Obtain the owner's explicit acknowledgement before T7, upload
only into the dedicated pilot library so that teardown can remove all of it, and consider substituting
the multi-occupant document with a single-occupant equivalent.

---

## 5. Verification performed

| Check | Result |
|---|---|
| Source set enumerated read-only | 8,187 files, 7,087 PDFs |
| Documents opened and read (not filename-classified) | **37 of 37** |
| SHA-256 computed twice by independent implementations | **37 of 37 agree, 0 mismatches** |
| Source files copied, moved, renamed or modified | **0** |
| SharePoint / Graph / live tenant calls | **0** |
| Class thresholds met | INV 14/≥10 · BES 8/≥5 · SET 6/≥5 · NON 9/≥5 |
| Sample flag | **`sample: DECISIVE`** |
| Raw counterpart git-ignored | verified — `git check-ignore -v` matches `.gitignore:6:docs/evidence/raw/*` |
| Values, paths, vendors, amounts or dates in this committed file | **none** |
