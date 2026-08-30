# T8 — BLOCKED: capture, score, and protect the data

**Status: INCOMPLETE — blocked on T7 (experiment results)**

| | |
|---|---|
| Produced | 2026-08-30T22:35:00Z |
| Blocker | T7 (three tiered Syntex experiments) did not execute. No experiment results exist. Therefore, no data can be captured or scored. |
| Unblock step | T7 must be unblocked and executed first (see `docs/evidence/t7-BLOCKED.md`). Once T7 succeeds and experiment results are available, T8 can capture, score, and protect the data. |
| Consequence | T8 did not execute. No Syntex output was captured. No scored results table was produced. No raw artifacts were written. |

---

## What T8 was supposed to do

Per the plan (amendment A, T8 description):

1. **Capture Syntex output** for each sample document in each experiment via a Graph read or exported library view
2. **Write raw export/Graph JSON to `docs/evidence/raw/`** (gitignored, secured) — it contains site URLs, item IDs, filenames, vendors, and financial values
3. **Commit only a redacted scored results file** plus the SHA-256 of each raw artifact
4. **Score each document** against the T2 frozen ground truth using predeclared per-type thresholds:
   - Document-level completeness
   - Field-level accuracy per exact field semantic
   - Missing-field rate
   - False-positive invoice-classification rate on non-invoices
   - Confidence calibration (if exposed)
   - Manual-review rate
5. **Report per experiment AND per document type** — a single blended number is prohibited

---

## Why it is blocked

T8 depends on T7 (experiment results) per the plan's dependency matrix (line 164):

| Todo | Depends on | Blocks |
|---|---|---|
| T8 capture + score | **T7** | T9 |

T7 is blocked on T6 (live Syntex activation), which is blocked on missing M365 Global Admin / Azure Owner credentials (see `docs/evidence/t6-BLOCKED.md` and `docs/evidence/t7-BLOCKED.md`). Therefore:

- No experiments ran
- No Syntex output exists
- No data can be captured
- No scoring can be performed

---

## Exact unblock step

1. **Unblock T7 first** — see `docs/evidence/t7-BLOCKED.md` for the dependency chain
2. **Once T7 succeeds and experiment results are available**, T8 can:
   - Capture Syntex output (classification, extracted fields, confidence) via Graph or library export
   - Write raw artifacts to `docs/evidence/raw/` (gitignored)
   - Produce a redacted scored results table with SHA-256 hashes
   - Score against the frozen ground truth per predeclared thresholds
   - Report per experiment and per document type

---

## Consequence for the plan

- **T8 is INCOMPLETE** — it did not run and produced no scored results
- **T9's verdict must be `BLOCKED / INCOMPLETE — pending live measurement`** — no adopt/reduce recommendation can be drawn from zero data
- **T10 is a read-proven no-op** — since T6 never activated, no pilot library, no models, and no billing were ever created; teardown is a confirmation that nothing exists to remove

---

## No fabrication

This file records the exact blocker and the dependency chain. No Syntex output was captured. No scored results table was invented. No raw artifacts were fabricated. The plan's contract (§5, "Blocked ⇒ INCOMPLETE") is honoured.
