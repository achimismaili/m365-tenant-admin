# m365-tenant-admin

A tool-agnostic toolkit for administering Microsoft 365 tenants from the command line.

This repository is **not** a single script. It is a home for small, independent, self-contained
tools — each one solving one tenant-administration problem, each one runnable on its own against
any Microsoft 365 tenant. Syntex setup happens to be the first tool in the collection; it is not
the identity of the repository. New tools are added as sibling folders under `tools/` without
touching the existing ones.

## Purpose

Tenant administration tasks in Microsoft 365 tend to be one-off, clicked-through, and undocumented.
The result is configuration that nobody can reproduce, verify, or roll forward into a second tenant.
This toolkit exists to make those tasks:

- **Scripted** — every change is expressed as code that can be read, reviewed and diffed.
- **Reproducible** — the same tool run against a fresh tenant produces the same end state.
- **Evidenced** — every run can emit a machine-readable record of what it found and what it changed.

## Design principles

Every tool in this repository is expected to honour the same two contracts.

### Idempotent

Running a tool twice must be safe. A tool inspects the current tenant state first and only makes
the changes that are actually missing. A second run over an already-configured tenant reports
"already correct" and changes nothing. There is no "undo the previous run first" step, and no
tool assumes it is the first thing to touch the tenant.

### Client-agnostic

No tool hard-codes a tenant, a domain, a site collection, a user, or any organisation-specific
name. Everything that varies between customers is a parameter, supplied at invocation time or read
from a configuration file that lives outside this repository. A tool that cannot be pointed at a
different tenant by changing only its arguments is considered broken.

Consequently, nothing organisation-specific is ever committed here — not in scripts, not in
defaults, not in documentation examples. Examples use placeholder values such as
`contoso.onmicrosoft.com`.

## Prerequisites

| Requirement | Notes |
|---|---|
| **PowerShell 7.4+** | The tools are written for cross-platform PowerShell, not Windows PowerShell 5.1. |
| **[PnP.PowerShell](https://pnp.github.io/powershell/)** | `Install-Module PnP.PowerShell -Scope CurrentUser`. Individual tools state the minimum version they need. |
| **An Entra ID app registration** | PnP.PowerShell requires your own registered application. See the PnP documentation for `Register-PnPEntraIDApp`. Interactive, certificate and client-secret authentication are all acceptable; each tool documents what it supports. |
| **Administrative roles** | At minimum a role that can read tenant configuration. Tools that write require elevated roles — typically **SharePoint Administrator** and/or **Global Administrator**. Each tool's own README states the exact least-privilege role it needs. |

Grant the least privilege that lets the tool succeed. If a tool's README asks for Global
Administrator where a narrower role would do, that is a bug worth reporting.

## Tools

| Tool | Path | Purpose |
|---|---|---|
| Syntex setup | [`tools/syntex-setup/`](tools/syntex-setup/) | Inspect and configure Microsoft Syntex / SharePoint Premium settings in a tenant. |

Each tool directory is self-contained and carries its own README describing its parameters,
required roles, and the evidence it produces. Add new tools as new directories under `tools/`.

## Evidence policy: raw vs redacted

Tenant-administration tools inevitably read data that identifies a real organisation — tenant IDs,
domain names, site URLs, user principal names, licence assignments. That data is useful for
verifying a run, and it must never end up in a public repository.

The split is therefore strict:

| Kind | Location | Committed? |
|---|---|---|
| **Raw exports** — verbatim tenant output, unredacted | `docs/evidence/raw/` | **No.** Git-ignored. Keep this directory on secured storage only. |
| **Redacted evidence** — pseudonymised summaries | `docs/evidence/` | **Yes.** |

Rules:

1. **Raw tenant exports go to `docs/evidence/raw/` and stay there.** That directory is listed in
   `.gitignore` and is expected to be empty in a clone. Treat its contents as confidential.
2. **Only redacted or pseudonymous evidence is committed.** Replace tenant names, domains, object
   IDs, URLs and user identifiers with stable pseudonyms (`tenant-a`, `contoso.onmicrosoft.com`,
   `user-01`). Pseudonyms must be consistent within a document so that relationships stay readable.
3. **Commit a SHA-256 hash of every raw artefact alongside its redacted summary.** The hash proves
   the redacted document was derived from a specific raw export without disclosing the export
   itself. Anyone holding the raw file can re-verify:

   ```powershell
   Get-FileHash -Algorithm SHA256 -LiteralPath docs/evidence/raw/<artefact>
   ```

4. **Never commit secrets.** Client secrets, certificates, tokens and passwords do not belong in
   this repository in any form, redacted or otherwise. `.gitignore` blocks the obvious filename
   patterns, but that is a safety net, not a substitute for care.

If you are unsure whether a value is safe to commit, treat it as raw.

## Repository layout

```
.
├── LICENSE
├── README.md
├── docs/
│   └── evidence/          committed, redacted evidence + SHA-256 hashes
│       └── raw/           git-ignored, secured raw tenant exports
└── tools/
    └── syntex-setup/      first tool
```

## Contributing

New tools are welcome. A tool is ready when it is idempotent, client-agnostic, documented in its
own README, listed in the table above, and free of any organisation-specific value.

## Licence

[MIT](LICENSE) — Copyright (c) 2026 Achim Ismaili.
