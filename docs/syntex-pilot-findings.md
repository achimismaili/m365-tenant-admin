# Syntex pilot findings

**Classification: REDACTED, safe to commit.** No tenant identifier, site or library URL, subscription
or resource-group ID, vendor name, monetary amount or document date appears below.

## PILOT OUTCOME: BLOCKED / INCOMPLETE — pending live measurement

No Syntex model was ever activated, applied or run. **Zero live data exists.** Nothing in this file
is an accuracy result, and none is inferred.

| Axis | Label |
|---|---|
| `sample` | **DECISIVE** (T2 met every predeclared sizing threshold without padding) |
| `pilot outcome` | **INCOMPLETE** (no live run happened) |

These are two different axes and must not be conflated. A decisive sample says the *measuring
instrument* is adequate; it says nothing about a measurement that was never taken. Reading "DECISIVE"
as a pilot verdict is the specific misreading this table exists to prevent.

**No adopt recommendation. No reduce recommendation. No recommendation of any kind is made here.**
Per the plan's blocked-implies-INCOMPLETE contract, a blocked pilot that produced a right-sizing call
would be a fabrication.

---

## 1. What was completed (T1 to T5)

All five are offline authoring and inspection passes. No tenant was contacted, no credential used, no
sign-in performed, no billable operation started.

| Todo | Deliverable | State |
|---|---|---|
| T1 | Repo scaffolded, MIT, deliberately client-generic, remote live at <https://github.com/achimismaili/m365-tenant-admin> | done |
| T2 | Pilot sample assembled and ground truth frozen | done, `sample: DECISIVE` |
| T3 | `tools/syntex-setup/Enable-SyntexPayAsYouGo.ps1`, idempotent, site-scoped, dual-mode `-WhatIf` / `-Preflight`, PSScriptAnalyzer clean | done, live path UNVERIFIED |
| T4 | `tools/syntex-setup/Test-SyntexSetup.ps1`, read-only, 6 checks | done, live path UNVERIFIED |
| T5 | Client-facing setup runbook, pricing verified against Microsoft Learn | done |

**T2 sample.** 37 documents / 119 PDF pages: 14 invoices spanning 12 distinct vendor families, 8
Bescheide, 6 settlements, 9 non-invoice. Ground truth frozen *before* any processing, per document,
with SHA-256, page count, true type, and the exact semantic of every expected field (invoice-date vs
due-date vs service-period; total vs balance vs installment vs assessment amount), including
`expected: no value` rows. The raw counterpart is git-ignored and secured; its SHA-256 is recorded in
the committed index (`docs/evidence/t2-preconditions.md`). Two cells were left
`UNVERIFIED — visual check required` and excluded from scoring rather than guessed.

**T3 scoping.** `Set-SPOTenant -PrebuiltModelScope` / `-PrebuiltModelSelectedSitesList` /
`-PrebuiltModelSelectedSitesListOperation` is the scoping surface (`NoSites|AllSites|SelectedSites`;
list operation defaults to `Overwrite`, so a naive call silently discards an admin's earlier site
selection, hence `Append`). Pay-as-you-go **billing activation has no cmdlet at all** and is genuinely
portal-only. `-WhatIf` inertness was proved with 29 command breakpoints, 0 tripped, in both PowerShell
editions. Evidence: `docs/evidence/t3-whatif.txt`.

**T4 read-only.** The verifier never signs in; it inspects sessions that already exist. Zero mutation
proved three independent ways: an AST walk (132 invocation sites, 32 distinct commands; the only
`Set|Add|New|Remove|Activate|Publish` hit is the mandated `Set-StrictMode`), a classified grep
cross-referenced line-by-line against that AST, and 60 command breakpoints with 0 trips in both
editions. Verdict precedence is FAIL > MANUAL > PASS, so an unreadable state is never rounded up.
Evidence: `docs/evidence/t4-test-scaffold.txt`.

**T5 pricing.** Verified against Microsoft Learn: prebuilt **$0.01**, unstructured **$0.005**,
structured/freeform **$0.05**. All three are per *transaction*, not strictly per page (unstructured
counts sheets for Excel and slides for PowerPoint). Processing is billed **per applied model**, so two
models over a five-page upload bills ten pages; billing happens on upload and again on subsequent
updates, and whether or not there's a positive classification. Azure Cost Management lags roughly
**24 hours**, which is why any teardown cost check needs a next-day recheck. Evidence:
`docs/evidence/t5-runbook-check.txt`.

## 2. What did not run (T6, T7, T8, T10)

All four are marked `- [~]` in the plan.

**Blocker.** No live Microsoft 365 Global Administrator (or SharePoint Administrator) session and no
Azure Owner/Contributor credentials were available to this agent environment. Activation requires an
interactive device-login / MFA flow and a live billing authorization, neither of which an unattended
agent can perform. T2 recorded every required live value as `NOT DETERMINED` and every access
precondition as `NOT CONFIRMED`, and invented none.

Consequently:

- T6 live activation and cost gate: not run.
- T7 three tiered experiments (E1 prebuilt invoice, E2 custom unstructured classification, E3
  structured/freeform Bescheid extraction): **not run, none of the three**. This is not evidence that
  Syntex cannot handle any of these classes. It is the absence of evidence either way.
- T8 capture and scoring: not run. No Syntex output exists to score against the frozen ground truth.
- T10 teardown: nothing was provisioned, so there should be nothing to tear down, but that is a
  *prediction*, not a proof. Confirming it needs the same live read this environment lacks, and the
  teardown is inventory-driven, not blocked-flag-driven.

## 3. Exact unblock

A **human operator** holding Microsoft 365 **Global Administrator** (or SharePoint Administrator)
**and** Azure **Owner/Contributor** on the billing subscription and resource group, present at the
keyboard for MFA / device login, must:

1. **Supply the live target.** Tenant-admin URL, Azure subscription ID, resource group, billing region
   (it stores tenant ID and usage metadata including site names, so disclose it to the owner), the
   pilot site URL, and a dedicated pilot library name. A **new** library created solely for the pilot,
   never a production one. The fill-in handoff table is in T2's git-ignored raw ground-truth file; the
   redacted index `docs/evidence/t2-preconditions.md` lists the same rows.
2. **Repair the Az module set first.** `Install-Module Az.Accounts -RequiredVersion 5.5.0 -Scope
   CurrentUser -Force`. On an unrepaired box the SharePoint reads and the Azure reads cannot run in the
   same PowerShell edition.
3. **T6.** Compute the cost estimate and maximum-spend ceiling, set an Azure budget with an *enabled*
   alert notification, run `Enable-SyntexPayAsYouGo.ps1 -Preflight`, then the live activation, then
   `Test-SyntexSetup.ps1`. Billing activation itself is portal-only; the runbook carries the current
   click path.
4. **T7.** Run the three tiered experiments in isolation, a separate library per experiment or each
   model removed before the next. Never stack models on one library: it confounds attribution and
   multiplies page charges.
5. **T8.** Capture, score against the T2 frozen ground truth per document type and per tier, raw
   exports to the git-ignored `docs/evidence/raw/` with only hashes and a redacted table committed.
6. **T10.** Inventory-driven teardown, then a residual-cost check plus a 24-hour recheck.

**Personal-data gate before any upload.** One sample settlement names individual tenants alongside
their meter readings. Uploading the sample moves real tenant PII to the cloud. Get an explicit owner
acknowledgement, upload only into the dedicated pilot library, and consider swapping that file for a
single-unit settlement.

**Spend context.** One full pass of the 119-page sample is roughly $1.19 prebuilt, $0.60 unstructured,
$5.95 structured. At least 8 of those pages are blank duplex versos that are still billed, and every
re-run re-bills.

## 4. DocAnalyzer is preserved, unconditionally

**Nothing in this pilot authorizes any change to DocAnalyzer, and nothing in it authorizes any change
to Tenero.** DocAnalyzer's engine (56 passing tests, code-complete, not yet live-verified per WorkIQ
`AGENTS.md` §9.9) stands exactly as it is. No source file in either project was touched by this pilot.

Even on the unblocked path this preservation clause would hold through the pilot: pilot evidence alone
never authorizes deleting working code. Any reduction would need a later shadow or production
acceptance gate. On the blocked path the question does not even arise, because there is no evidence at
all.

## 5. Layer-2 gap sizing

**Layer-2 gap sizing awaits live pilot data.** See WorkIQ `AGENTS.md` §9.10 for what is already known
independent of this pilot: the taxonomy / `RelevantYear` Q1-decrement question and the per-unit contact
matching gaps. This pilot neither widens nor narrows those findings.

## 6. Two corpus facts T2 surfaced (not Syntex results)

Both come from reading the actual PDF text layer of the 37 sample documents. Neither is a claim about
Syntex, and neither depends on the pilot ever running. Both will change how the live experiments must
be scored.

**(a) Filenames disagree with content in 8 of 37 files.** Two documents named `... Final 2025.pdf` are
headed **2026** in their own body text and dated in 2026. Another file whose name says
"Schlussrechnung" is a payment reminder. Any pipeline that derives type or year from the filename
misclassifies these, and a scoring pass that trusts filenames would grade the model against the wrong
answer key. Related: one downstream analysis file in DocAnalyzer carries a filename-derived row that is
wrong for exactly this reason and is worth correcting when someone next touches it.

**(b) 8 of 37 files (22%) contain more than one logical document.** The multi-doc-per-PDF splitting
problem on the plan's own risk list is **confirmed in this exact corpus, not hypothetical**. Two cases
are severe: one PDF holds two independent Bescheide, another holds five separate meter-reading requests
with distinct meters. Six more bundle a certificate, info insert, questionnaire or blank SEPA mandate.
The counting rule (is a five-in-one PDF one document or five?) must be decided **before** scoring, or an
80% miss hides inside an average.

A third observation worth carrying forward, though it is a measurement design note rather than a corpus
defect: only 3 of 14 invoices carry a due date at all. A DueDate accuracy number from this corpus mostly
measures whether a model correctly returns *nothing*, so precision, recall and the false-positive rate
on `expected: no value` rows have to be reported separately.

## 7. Evidence index

| File | Contents |
|---|---|
| `docs/evidence/t1-remote.md`, `t1-repo-tree.txt` | Repo creation and structure |
| `docs/evidence/t2-preconditions.md` | Redacted ground-truth index, sample sizing verdict, undetermined live target |
| `docs/evidence/t3-whatif.txt` | Dry-run transcript, breakpoint proof, PSScriptAnalyzer result |
| `docs/evidence/t4-test-scaffold.txt` | Verifier transcript, three zero-mutation proofs |
| `docs/evidence/t5-runbook-check.txt` | 11 runbook checks, all pass |
| `docs/syntex-setup-runbook.md` | Client-facing setup runbook |
| *(absent by design)* | `t6-*`, `t7-*`, `t8-*`, `t10-*` live artefacts. None exists, none was fabricated. |
