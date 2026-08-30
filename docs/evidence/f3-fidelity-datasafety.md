# F3 — Scope fidelity and data-safety audit

**Overall verdict: APPROVE**

## 1. Genericity grep

Scope per amendment B:

- `tools/syntex-setup/*.ps1`
- `README.md`
- `LICENSE`
- `docs/syntex-setup-runbook.md`

Command:

```powershell
git grep -ril "tenero\|docanalyzer\|nebenkosten\|wirtschaftseinheit" -- `
  tools/syntex-setup/*.ps1 README.md LICENSE docs/syntex-setup-runbook.md
```

Result: **ZERO hits — PASS.**

The name `Achim Ismaili` in the MIT copyright notice and README licence footer is required copyright attribution, not a client, tenant, product, or domain-specific implementation reference. It is excluded from the genericity concern.

## 2. Data-privacy grep

Command:

```powershell
git grep -il "@\|GmbH\|EUR\|sharepoint.com/sites/" -- . ':!docs/evidence/raw'
```

Result: matches were returned and manually inspected.

Findings:

- `@` matches in PowerShell files are language syntax such as arrays and hashtables, not email addresses or tenant identifiers.
- Case-insensitive `EUR` matches are substring false positives in ordinary words and identifiers; no standalone currency values were found.
- No `GmbH` or euro sign values were found.
- SharePoint URLs use explicit placeholders only: `https://fake.sharepoint.com/sites/pilot`, `https://contoso.sharepoint.com/sites/pilot`.
- No real vendor names, financial amounts, site URLs, tenant domains, subscription IDs, resource-group names, item IDs, or email addresses were found.

Result after manual inspection: **PASS.**

## 3. Raw versus redacted evidence

Command:

```powershell
git ls-files docs/evidence/raw
```

Result:

```text
docs/evidence/raw/.gitkeep
```

Ignore verification:

```powershell
git check-ignore -v docs/evidence/raw/probe.txt
```

Confirms `.gitignore:6` applies (`docs/evidence/raw/*`), with a `.gitkeep` exception.

Result: **PASS. No raw tenant or corpus evidence is committed.**

## 4. Sample coverage and frozen hashes

`docs/evidence/t2-preconditions.md` declares `sample: DECISIVE`.

The committed redacted index contains 37 held-out documents across multiple document types:

| Class | Documents |
|---|---:|
| Invoices | 14 |
| Property-tax and municipal assessment notices | 8 |
| Utility settlements | 6 |
| Non-invoice correspondence | 9 |

Every sample row uses a pseudonymous `sample-NNN` identifier and a SHA-256 hash. Expected-field semantics are recorded without real filenames, vendor names, monetary values, or document dates.

Result: **PASS. The sample is not invoice-only and satisfies the declared DECISIVE count contract.**

## 5. Layer 2/3 leakage

Command:

```powershell
git grep -in -e "ProcessedVersion" -e "ProcessingStatus" -e "BaseDocument" -e "content-type-hub" -e "per-unit site" -- .
```

Result: **ZERO hits — PASS.**

## 6. Committed filename inspection

The complete output of `git ls-files` was inspected. No tracked filename contains a real vendor, tenant, site, customer, property, or corpus-document name. The raw evidence directory tracks only `.gitkeep`.

Result: **PASS.**

## Final decision

All F3 scope-fidelity and data-safety checks pass.

**VERDICT: APPROVE**
