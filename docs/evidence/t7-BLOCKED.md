# T7 — BLOCKED: three tiered Syntex experiments

**Status: INCOMPLETE — blocked on T6 (live Syntex activation)**

| | |
|---|---|
| Produced | 2026-08-30T22:35:00Z |
| Blocker | T6 (live enablement + pilot-library creation) did not execute. No Syntex pay-as-you-go billing was activated. No pilot library exists. Therefore, no experiment can run. |
| Unblock step | T6 must be unblocked and executed first (see `docs/evidence/t6-BLOCKED.md`). Once T6 succeeds and the pilot library is live, T7 can run the three tiered experiments. |
| Consequence | T7 did not execute. No Syntex models were trained or applied. No experiment results exist. |

---

## What T7 was supposed to do

Per the plan (amendment E, T7 description):

1. **Experiment E1 — Prebuilt invoice processing** on the ≥10 held-out invoices PLUS the non-invoice negatives (to measure true extraction on invoices AND false-positive rate on non-invoices)
2. **Experiment E2 — Custom unstructured classification** (optional, higher cost) for Bescheid/non-invoice classes — train on 5–10 separate training docs per class and score on the held-out set
3. **Experiment E3 — Structured/freeform Bescheid extraction** (optional, highest cost) — run only if intentionally evaluating that tier

Each experiment must:
- Use a separate library OR sequentially remove each model before the next (never stack models)
- Record which model, which library, train vs. holdout split, and page count consumed
- Maintain train/test separation (never reuse a training document in scoring)

---

## Why it is blocked

T7 depends on T6 (live Syntex activation) per the plan's dependency matrix (line 163):

| Todo | Depends on | Blocks |
|---|---|---|
| T7 tiered experiments | **T6, T2** | T8 |

T6 is blocked on missing M365 Global Admin / Azure Owner credentials (see `docs/evidence/t6-BLOCKED.md`). Therefore:

- No pilot library was created
- No Syntex pay-as-you-go billing was activated
- No tenant connection was established
- No experiment can run

---

## Exact unblock step

1. **Unblock T6 first** — see `docs/evidence/t6-BLOCKED.md` for the precise unblock step
2. **Once T6 succeeds**, T7 can proceed with the three experiments:
   - E1: Prebuilt invoice on the 14 invoices + 9 non-invoice negatives
   - E2: Custom classification (optional) on the 8 Bescheide + 6 settlements + 9 non-invoices
   - E3: Structured extraction (optional) on the 8 Bescheide

---

## Consequence for the plan

- **T7 is INCOMPLETE** — it did not run and produced no experiment results
- **T8 is blocked** — it depends on T7 (experiment results to score)
- **T9's verdict must be `BLOCKED / INCOMPLETE — pending live measurement`** — no adopt/reduce recommendation can be drawn from zero data
- **T10 is a read-proven no-op** — since T6 never activated, no pilot library, no models, and no billing were ever created; teardown is a confirmation that nothing exists to remove

---

## No fabrication

This file records the exact blocker and the dependency chain. No experiment results were invented. No Syntex classification or extraction was fabricated. The plan's contract (§5, "Blocked ⇒ INCOMPLETE") is honoured.
