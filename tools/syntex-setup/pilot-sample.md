# Pilot sample selection and ground-truth freezing

A reusable method for assembling the document sample that a document-understanding pilot is scored
against, and for freezing its ground truth before any processing happens.

This document is deliberately domain-neutral. It prescribes *how* to choose documents and *how* to
record what they say — never which documents, which vendors, or which fields, because those differ
for every evaluation. Follow it and the resulting measurement is auditable and reproducible by
someone who was not in the room.

**Scope.** Sampling and ground truth only. Enabling the service, applying models, running the
experiments and scoring the output are separate steps with their own documents.

---

## Why this exists

A pilot that skips this step produces a number nobody can defend. The three failure modes it prevents,
in order of how often they occur:

1. **Ground truth written after seeing the output.** Once you have read the extraction, "what the
   document says" quietly becomes "what would make this look right". Freezing first, with a timestamp
   and a file hash, makes that impossible to do accidentally and obvious if done deliberately.
2. **Filenames used as truth.** Filenames are written by people and by scanners. They are wrong often
   enough that a filename-derived expectation will produce a wrong accuracy figure in *both*
   directions — penalising correct extractions and rewarding incorrect ones.
3. **One blended accuracy number.** A single percentage across mixed document types hides the only
   thing the pilot exists to find out: *which* types the service handles and which it does not.

---

## The six rules

1. **Stratify by layout family, not by volume.** Ten documents from ten issuers teach you more than a
   hundred from one.
2. **Open every file.** A document's type, date and amounts come from its content. If a file cannot be
   opened or read by your tooling, say so explicitly for that file and mark its ground truth as
   filename-derived and untrusted.
3. **Freeze before you process.** Hash, timestamp and annotate first. Amend by appending, never by
   editing in place.
4. **Include documents that should yield nothing.** A sample of only positives cannot measure a false
   positive rate, which is usually the number that decides whether a human still has to check.
5. **Record `expected: no value` explicitly.** An absent field is a real expectation, not a gap in
   your notes. Without it you cannot tell a correct silence from an untested field.
6. **Never guess to fill a cell.** If a value cannot be read reliably, mark it unverified and exclude
   it from scoring. An honest gap costs one row; an invented value invalidates the table.

---

## Step 1 — Define the decision classes first

Write down the classes **before** looking for documents, and derive them from the decision the pilot
must inform, not from folder structure.

A workable default for a business-document corpus:

| Class | What it is | Why it is in the sample |
|---|---|---|
| **Primary** | The document type the service claims to handle out of the box | Measures the headline capability |
| **Adjacent** | Documents that look similar and carry similar fields, but are a different type | Measures whether the service distinguishes them or over-generalises |
| **Derived** | Reconciliations, settlements, statements — documents *about* other documents | Usually where field semantics fracture |
| **Negative** | Correspondence that carries no extractable business fields at all | Measures the false-positive rate |

Two or three classes are too few to be informative. More than five and per-class counts fall below the
point where a single document stops moving the percentage by double digits.

For each class, write down **before selection**:

- the fields you expect to be present, by exact semantic (see Step 4);
- the fields you expect to be **absent**;
- the accuracy threshold that would count as "good enough" for this class.

Declaring thresholds in advance is what stops the pilot from concluding "good enough" because that is
what the numbers happened to be.

---

## Step 2 — Set the sample size, then meet it or say you did not

Recommended minima, per class, for a directional-to-decisive pilot:

| Class | Minimum | Rationale |
|---|---:|---|
| Primary | **10**, spanning **≥ 8 distinct layout families** | Below 10, one document is more than ten points |
| Every other class | **5** | Below 5, a single miss reads as a 20-point failure |

Plus, if a custom model will be trained: **5–10 additional documents per class**, strictly disjoint
from the sample above. Training and scoring documents must never overlap. Record the split explicitly
and prove the disjointness — a hash list on each side is enough.

Then flag the outcome honestly, in the committed evidence, using two words and no hedging:

- **`sample: DECISIVE`** — every declared minimum met, without padding and without reclassifying a
  document to make a count work.
- **`sample: DIRECTIONAL`** — any class fell short. Name each shortfall and its actual count.

A sample below the minimum with no `DIRECTIONAL` flag is a failed pilot, not a small one. Padding a
class with near-duplicates to reach a number is worse than reporting the shortfall: it produces a
count that passes and a measurement that does not mean anything.

Separately from the count flag, write down what the sample cannot support regardless of size:

- how many distinct issuers, regions, jurisdictions or languages it covers;
- whether all scans come from one device or capture pipeline, which makes input quality
  unrepresentatively uniform;
- the confidence interval implied by the smallest class.

`DECISIVE` is a statement about meeting the declared contract. It is not a claim of statistical power,
and the final report must not let it be read as one.

---

## Step 3 — Select for variety, and prove it

Stratify along the axes that actually change how a document looks:

- **Issuer / layout family.** The dominant axis. Give each family a pseudonym (`family-A`, `family-B`)
  and record it. Two documents sharing a pseudonym share a template.
- **Origin.** Digitally generated versus scanned. Include both. If a corpus is entirely one or the
  other, say so — it bounds the conclusion.
- **Structure.** Single-page, multi-page, multi-column tables, forms.
- **Outcome direction.** Where a document type can resolve either as a payable or as a receivable,
  include **both on the same template**. This is the cheapest way to test whether the service reads
  meaning or pattern-matches position.
- **Composition.** Files that contain more than one logical document (see Step 5).
- **Edge cases you already know about.** Amendments, corrections, reminders, duplicates,
  near-duplicates.

Two selection habits worth adopting:

- **Include deliberate pairs.** Same template with opposite outcomes; the same issuer and template on
  two different subjects; consecutive periods for the same subject with one parameter changed. Pairs
  turn a single accuracy figure into a consistency check that costs nothing extra.
- **Include at least one known-hard document per class.** If you already know a document confuses your
  existing process, it belongs in the sample. Excluding it makes the pilot easier and useless.

---

## Step 4 — Freeze the ground truth

Do this **before** any document is uploaded or processed.

### Per document, record

| Item | Note |
|---|---|
| **doc-id** | A stable sequential pseudonym (`sample-001`). Every later artefact refers to this, never to a filename. |
| **SHA-256** | Of the file itself. Proves the scored document is the frozen one and lets a reviewer verify without access to the file. Compute it twice with independent implementations and record that they agree. |
| **Page count** | Of the file. Note separately if it differs from the logical page count. |
| **Logical document count** | How many independent documents the file contains (see Step 5). |
| **True type and subtype** | From the content. Not from the filename, not from the folder. |
| **Per field** | Exact semantic · normalised expected value · source page. |
| **Annotator and timestamp** | See below. |

### Name the exact semantic, never a generic label

This is the highest-value part of the whole exercise, and the part most often skipped. A field called
"date" or "total" is not a specification — it is an argument waiting to happen after the results are
in. Distinguish at minimum:

- **Dates:** issue date · service or delivery date · service *period* start and end · payment due date
  · scheduled direct-debit date · coverage period · deadline for a response.
- **Amounts:** net · tax · gross total · a single installment · the balance remaining after
  installments · the amount actually collected · an assessed amount · a previously-assessed amount ·
  an outstanding balance after an amendment · a total spanning several documents.
- **Direction:** payable by the recipient versus receivable by the recipient. On many templates these
  are visually identical and differ by one word.
- **Parties:** the issuing party versus a channel, intermediary or marketplace that merely transported
  the document.

Where a label in the document *looks* like one semantic but means another — a period whose label
contains the word "due", a per-line amount labelled with the word "total" — record the trap
explicitly next to the field. That note is what stops a later reviewer from "correcting" your correct
ground truth.

### Normalise, and say how

Pick one representation and state it: dates as `YYYY-MM-DD`, amounts as a decimal point with fixed
precision and an explicit currency, identifiers verbatim as printed including spacing. Scoring
compares normalised values, so an unstated convention is an unscoreable table.

### Record absence explicitly

For every field in the class's declared field set that the document does not carry, write
**`expected: no value`**. Then score any extraction against it as a **false positive**. Without these
rows you can measure only what a model found, never what it invented — and inventing plausible values
on documents that have none is the most expensive failure mode in production, because it is the one a
human does not notice.

### Record unreadable values as unverified

If a value cannot be read reliably, write **`UNVERIFIED — visual check required`**, state why, and
**exclude that field from scoring**. Never guess, and never reverse-engineer a value from arithmetic
that "ought to" reconcile. Guessing to complete a table converts one unknown cell into a silently
wrong accuracy figure.

### Annotate honestly

Every document gets an annotator tag and an ISO-8601 UTC timestamp. If the ground truth was assembled
by, or with, an automated tool and no human has checked it, the tag must say so — for example
`AI-agent-assisted, <ISO timestamp>, human-review-pending`. Do not write "verified" for verification
that did not happen. The tag is what a later reviewer uses to decide how much weight the table
carries; falsifying it corrupts every number derived from it.

### Freeze, then amend by appending

Once processing starts, the ground truth is immutable. A correction is a **dated amendment appended
to the end of the document**, never an in-place edit. In-place edits after scoring are
indistinguishable from fitting the truth to the result.

---

## Step 5 — Check three things that quietly break scoring

### One file is often not one document

Scanned and bundled files routinely contain several independent documents, or one document plus
certificates, inserts, forms and attachments. Count the **logical** documents per file and record the
number.

Then decide, **and write down, before scoring**:

- whether a primary document bundled with its own attachment counts as one document or two;
- how a file containing genuinely independent documents of the same class is scored.

A run that returns one result for a file containing five documents is a **completeness** failure, not
an accuracy failure. Reporting it as accuracy hides an 80 % miss inside a plausible-looking average.
Deciding the counting rule after seeing the results is the single easiest way to accidentally flatter
a pilot.

### Blank and content-free pages are still billed

Duplex scanning produces empty reverse sides. Per-page pricing charges for them. Base cost projections
on **page** counts, not document counts, and record how many pages carry no content — it is often
5–10 % of a scanned sample.

### Content quality is a property of your sample, not of the service

Record how you read each document and how well it read: digitally generated, scanned with a usable
text layer, scanned and partly illegible. Mark specific fields that were illegible.

State plainly that this describes the **local** extraction used to freeze ground truth, not the
service under test. The service may read a degraded document better than your local tooling did.
Ground truth is what the document *says* — where your tooling and the document's evident meaning
conflicted, the value is unverified, not a guess.

---

## Step 6 — Split the evidence

The frozen ground truth contains real values: identifiers, party names, amounts, dates. The index of
it does not need to.

| Artefact | Contains | Committed? |
|---|---|---|
| **Raw ground truth** | Real values, real paths, real party names | **No.** Git-ignored, secured storage only. |
| **Redacted index** | doc-id · SHA-256 · document type · layout-family pseudonym · page and logical-document counts · field **semantics** with no values · the sample flag | **Yes.** |

The hashes are safe to commit and are what make the redacted index auditable: anyone holding the raw
files can verify that a scored document is the frozen one without the index ever disclosing content.
Commit the SHA-256 of the raw ground-truth file itself alongside the index for the same reason.

Two rules that are easy to state and easy to violate:

- Never copy a value from the raw artefact into a committed one "just for context".
- Never paste raw content into a chat, ticket, issue or transcript that leaves the machine.

---

## Step 7 — Before uploading, check what you are moving

A pilot sample drawn from real business documents will contain personal data. Uploading it to a cloud
service moves that data off the local machine, and the pilot is not usually why anyone agreed to that.

Before any upload:

- Identify which documents name third parties, and say which.
- Obtain and record an explicit acknowledgement from the data owner.
- Upload only into a **dedicated pilot container created for the pilot** — never a production one — so
  that teardown can remove all of it.
- Where a document's sensitivity is not necessary to the measurement, substitute a less sensitive
  document of the same type and layout family.

Also record where processing and billing metadata are stored regionally, since that is usually a
separate decision from where the documents live, and it typically retains identifiers and usage
metadata beyond the pilot.

---

## Checklist

Ground truth is frozen when all of the following are true.

- [ ] Decision classes defined **before** selection, each with its expected present fields, expected
      absent fields, and a declared accuracy threshold.
- [ ] Primary class has ≥ 10 documents spanning ≥ 8 distinct layout families.
- [ ] Every other class has ≥ 5 documents.
- [ ] Training documents, if any, are disjoint from the sample and the split is proven.
- [ ] Sample flagged **`DECISIVE`** or **`DIRECTIONAL`**, with every shortfall named.
- [ ] Generalisation limits recorded separately from the count flag.
- [ ] **Every** file opened and read; any file that could not be is flagged as filename-derived and
      untrusted.
- [ ] Every disagreement between filename and content recorded, with content taken as truth.
- [ ] SHA-256 per file, computed twice by independent implementations, agreement recorded.
- [ ] Page count and **logical document count** per file.
- [ ] Every expected field named by its **exact semantic**, with a normalised value and a source page.
- [ ] Every genuinely absent field recorded as **`expected: no value`**.
- [ ] Every unreadable value recorded as **`UNVERIFIED`** and excluded from scoring.
- [ ] Normalisation conventions stated.
- [ ] Annotator and ISO-8601 timestamp on every document, truthful about whether a human checked it.
- [ ] Multi-document counting rule decided and written down **before** scoring.
- [ ] Page-based cost projection, including content-free pages.
- [ ] Raw artefact git-ignored; redacted index committed; ignore status actually verified, not assumed.
- [ ] Personal-data acknowledgement obtained and recorded before any upload.
