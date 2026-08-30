# Syntex setup

Tools for turning Microsoft Syntex / SharePoint Premium **pay-as-you-go document processing** on in
a Microsoft 365 tenant, scoping it to the sites you actually intend to bill for, and verifying the
result.

| Script | Kind | Status |
|---|---|---|
| [`Enable-SyntexPayAsYouGo.ps1`](Enable-SyntexPayAsYouGo.ps1) | Mutating, idempotent | Available |
| [`Test-SyntexSetup.ps1`](Test-SyntexSetup.ps1) | Read-only verifier | Available |
| `pilot-sample.md` | Sampling methodology for a measured pilot | Available |

---

## `Enable-SyntexPayAsYouGo.ps1`

Activates pay-as-you-go document processing, links it to an Azure subscription for billing, and
restricts processing to a single pilot site rather than the whole tenant.

### Execution modes

The script deliberately separates "tell me what you would do" from "check that the target is real"
from "do it".

| Mode | Connects? | Mutates? | Use it to |
|---|---|---|---|
| `-WhatIf` | **No** | No | See the full intended action list, including the site-scope decision, before a live target even exists. Exits `0` with entirely fake parameter values. |
| `-Preflight` | Yes | No | Prove that the subscription, the resource group and the pilot site exist and that you hold the rights. Fails loudly on the first missing resource. |
| *(neither)* | Yes | Yes | Run the preflight, then create the pilot library and apply the processing scope. |

`-WhatIf` is genuinely offline: it opens no connection of any kind. That is not a claim in a
comment — it is measured with command breakpoints in
[`docs/evidence/t3-whatif.txt`](../../docs/evidence/t3-whatif.txt).

### Parameters

| Parameter | Required | Purpose |
|---|---|---|
| `-TenantAdminUrl` | Yes | SharePoint tenant admin URL, e.g. `https://contoso-admin.sharepoint.com`. Echoed but never contacted under `-WhatIf`. |
| `-AzureSubscriptionId` | For preflight / live | Subscription that carries the pay-as-you-go charges. Must be a GUID and must live in the same tenant as Microsoft 365. |
| `-ResourceGroup` | For preflight / live | Resource group, inside that subscription, that the billing meter attaches to. |
| `-Region` | No | Billing region. It decides where the tenant ID and usage metadata such as site names are stored, so it is a data-residency choice. Omitted means the portal prompts. |
| `-PilotSiteUrl` | Strongly recommended | The single site collection processing is restricted to. Supplying it is what keeps activation site-scoped. |
| `-PilotLibraryName` | No | Display name of a dedicated library to create in the pilot site. An existing library of that name is reported and left untouched. |
| `-DeviceLogin` | No | Device-code sign-in instead of a browser. |
| `-Preflight` | No | Validate read-only, then stop. |
| `-AcknowledgeTenantWide` | Only for tenant-wide | Explicit acknowledgement that every site in the tenant may become billable. Without it the script refuses to enable anything tenant-wide. |

`-WhatIf` and `-Confirm` come from `SupportsShouldProcess`. The script declares a **High** confirm
impact because it can start billable activity; pass `-Confirm:$false` to run it unattended.

### Least-privilege roles

| Where | Role |
|---|---|
| Microsoft 365 | **SharePoint Administrator** (preferred) or Global Administrator |
| Azure subscription and resource group | **Owner** or **Contributor** |

The tenant also needs at least one SharePoint-bearing licence, and the Azure subscription must be in
the same tenant as Microsoft 365.

### What is scriptable, and what is not

This matters, because guessing here silently produces a script that appears to work and bills
nothing — or bills everything.

**Scoping IS scriptable.** `Set-SPOTenant` in the SharePoint Online Management Shell
(`Microsoft.Online.SharePoint.PowerShell`) exposes:

- `-PrebuiltModelScope` — `NoSites`, `AllSites`, `SelectedSites`
- `-PrebuiltModelSelectedSitesList` — `String[]`
- `-PrebuiltModelSelectedSitesListOperation` — `Overwrite`, `Append`, `Remove`

The script uses `SelectedSites` + `Append`, so it adds the pilot site without discarding any
selection an administrator made earlier.

**PnP.PowerShell does not expose those parameters.** `Set-PnPTenant` has no `-PrebuiltModelScope`.
The script therefore probes for the capability at run time rather than assuming a provider, and
reports which surface it found.

**Billing activation is NOT scriptable.** Choosing the Azure subscription, resource group and region
and accepting the terms of service has no documented cmdlet in PnP.PowerShell, the SharePoint Online
Management Shell, or the Az modules. The script prints the exact portal click-path and marks the
step `[MANUAL]` instead of inventing a plausible cmdlet name:

```
https://admin.microsoft.com
  -> Setup -> Billing and licenses
  -> Activate pay-as-you-go services -> Get started
  -> Pay-as-you-go services -> Billing tab -> Document processing services
  -> Set up billing and turn on services
  -> choose Azure subscription / resource group / region
  -> accept the pay-as-you-go terms of service -> Save
```

Then, on the same page's **Settings** tab, open **Document processing services -> Prebuilt document
processing**, choose **Selected sites**, add only the pilot site, and save. Older admin-center builds
expose the same switch under *Settings -> Org settings -> Services -> Microsoft Syntex*.

References:
[billing setup](https://learn.microsoft.com/microsoft-365/documentprocessing/syntex-azure-billing) ·
[service setup](https://learn.microsoft.com/microsoft-365/documentprocessing/set-up-microsoft-syntex) ·
[`Set-SPOTenant`](https://learn.microsoft.com/powershell/module/microsoft.online.sharepoint.powershell/set-spotenant)

### PowerShell edition caveat

The repository README asks for PowerShell 7.4+, and `-WhatIf` and the PnP paths do run there. But
`Microsoft.Online.SharePoint.PowerShell` declares no Core-compatible edition, so **PowerShell 7
cannot load it** and the scoping step degrades to the portal fallback. Run the live scoping step
from **Windows PowerShell 5.1**, or install a Core-compatible build of that module. The script
detects this and says so rather than failing obscurely.

### Idempotency

Every mutating step reads current state first:

- an existing pilot library is reported and left untouched;
- a scope that already matches the requested scope and site list is reported as a no-op;
- an already-active service is reported, not treated as an error.

Re-running the script is safe.

### Cost safety

Document processing bills **per page** against the linked Azure subscription. Uploads, later updates
to an already-processed file, and pages that fail processing are all billed. Set an Azure budget and
alert before activating, and remember that a budget alert is a notification, **not** a hard spending
cap. Scope to a dedicated pilot library; never point a first run at a production library.

### Examples

```powershell
# Offline dry run - no connection, no mutation, exits 0 even with fake values
.\Enable-SyntexPayAsYouGo.ps1 -WhatIf `
    -TenantAdminUrl "https://contoso-admin.sharepoint.com" `
    -AzureSubscriptionId "00000000-0000-0000-0000-000000000000" `
    -ResourceGroup "rg-syntex-pilot" `
    -PilotSiteUrl "https://contoso.sharepoint.com/sites/pilot"

# Authenticated read-only validation
.\Enable-SyntexPayAsYouGo.ps1 -Preflight `
    -TenantAdminUrl "https://contoso-admin.sharepoint.com" `
    -AzureSubscriptionId "00000000-0000-0000-0000-000000000000" `
    -ResourceGroup "rg-syntex-pilot" `
    -Region "westeurope" `
    -PilotSiteUrl "https://contoso.sharepoint.com/sites/pilot" `
    -DeviceLogin

# Live, site-scoped, with a dedicated pilot library
.\Enable-SyntexPayAsYouGo.ps1 `
    -TenantAdminUrl "https://contoso-admin.sharepoint.com" `
    -AzureSubscriptionId "00000000-0000-0000-0000-000000000000" `
    -ResourceGroup "rg-syntex-pilot" `
    -Region "westeurope" `
    -PilotSiteUrl "https://contoso.sharepoint.com/sites/pilot" `
    -PilotLibraryName "Syntex Pilot"
```

Full comment-based help is in the script: `Get-Help .\Enable-SyntexPayAsYouGo.ps1 -Full`.

### Evidence produced

| File | Contents |
|---|---|
| [`docs/evidence/t3-whatif.txt`](../../docs/evidence/t3-whatif.txt) | `-WhatIf` transcripts in both PowerShell editions, the tenant-wide-gate induced failure, PSScriptAnalyzer output, and the breakpoint proof that the dry run invokes nothing. Fully redacted — placeholder values only. |

A live run's transcript contains tenant URLs and subscription IDs and therefore belongs in the
git-ignored `docs/evidence/raw/`; commit only a redacted summary plus the raw file's SHA-256. See
the repository README's evidence policy.

### Prerequisites

```powershell
Install-Module PnP.PowerShell                         -Scope CurrentUser
Install-Module Microsoft.Online.SharePoint.PowerShell -Scope CurrentUser
Install-Module Az.Accounts, Az.Resources              -Scope CurrentUser
```

None of these are needed for `-WhatIf`, which is fully offline.

---

## `Test-SyntexSetup.ps1`

The read-only half of the pair. It answers one question — *is the pilot actually set up the
way it was meant to be?* — and answers it without changing anything.

### The read-only contract

There is no mutation anywhere in the file. The only state-changing statement is the mandatory
`Set-StrictMode -Version Latest`, which changes nothing outside its own PowerShell scope.

It also **does not sign in**. There is no `Connect-*` call in the script at all. It inspects the
sessions that already exist in the calling session and reports what it finds. That is deliberate:

- it makes check 1 (*am I looking at the right tenant?*) a genuine measurement rather than a
  tautology;
- running the verifier can never open a browser, consume a token, or start a billable operation.

So sign in first, then run it:

```powershell
Connect-PnPOnline -Url "https://contoso-admin.sharepoint.com" -Interactive
Connect-SPOService -Url "https://contoso-admin.sharepoint.com"   # optional, enables checks 2 and 4b
Connect-AzAccount                                                 # optional, enables checks 3 and 6
.\Test-SyntexSetup.ps1 -TenantAdminUrl "https://contoso-admin.sharepoint.com" ...
```

Run it with no session at all and it still runs cleanly — it reports `[FAIL]` / `[MANUAL]` with the
reason, which is the correct answer to "is this set up?" when nobody is signed in.

That claim is measured, not asserted: 60 command breakpoints across every sign-in, mutation,
publish, raw-HTTP and filesystem cmdlet, **0 tripped** in both PowerShell editions, plus a full AST
walk showing the only mutating-verb command in the file is `Set-StrictMode`. See
[`docs/evidence/t4-test-scaffold.txt`](../../docs/evidence/t4-test-scaffold.txt).

### The six checks

| # | Check | Can it be `[PASS]`? |
|---|---|---|
| 1 | A live session exists and resolves to the tenant named by `-TenantAdminUrl` | Always `[PASS]` or `[FAIL]` — fully readable |
| 2 | Pay-as-you-go document processing is activated | Only if a future `Get-SPOTenant` build exposes it; today `[MANUAL]` |
| 3 | Azure subscription + resource group linkage is present | `[PASS]` when a document processing meter is found on the scope |
| 4 | Pilot library exists **and** the processing scope is as expected | Yes — both halves are readable |
| 5 | Model creation entry point is reachable (**configuration check only**) | Yes — when a content center site resolves |
| 6 | Azure budget with an enabled alert exists on the billing scope | Yes — via `Get-AzConsumptionBudget` |

Every check prints `[PASS]`, `[FAIL]` or `[MANUAL]`, and the run ends with a single
machine-readable line:

```
Result: 4/6 checks passed
```

Only `[PASS]` counts. `[MANUAL]` and `[FAIL]` do not.

### The honesty rule

Where a state is not programmatically readable, the check prints `[MANUAL]` **and the exact portal
location**. It never prints `[PASS]` for something it could not observe, and it never rounds a
plausible proxy up to a pass. Two places where that rule does real work:

- **Check 2.** Billing activation has no documented read cmdlet in any module. Rather than hard-code
  that forever, the check probes `Get-SPOTenant`'s *live* property surface by name, so it will start
  reporting the truth on its own if Microsoft ever adds one. Until then it reports `[MANUAL]`. The
  current processing scope is printed as corroboration only — a scope can be set without billing
  being linked, so it is not proof.
- **Check 3.** The Microsoft 365 → Azure linkage is portal-only, but it can still be proven
  *positively*: a document processing meter charged against the resource group could only have got
  there through the linkage. Absence proves nothing — a freshly linked pilot that has processed
  nothing bills nothing — so absence yields `[MANUAL]`, never `[FAIL]`.

Verdict precedence inside a check with several halves is **FAIL > MANUAL > PASS**: a measured
negative is never softened into "go look in the portal", and an unreadable state is never rounded up.

### Check 5 creates nothing

Check 5 is a *capability and reachability* check. It reads whether the model read cmdlet surface
(`Get-PnPSyntexModel`) is loadable and whether a content center site exists — identified by its web
template `CONTENTCTR#0`, which is the model creation interface. It does **not** create a model, a
content center, a library or a content type. Creation is mutation.

A missing content center is reported `[MANUAL]`, not `[FAIL]`: models can also be created locally
from a document library's own **Automate → Set up a model** menu, so absence does not prove the
capability is unreachable.

### Check 6 — budget and alert

A budget alert is a **notification, not a hard spending cap**. It bounds surprise, not spend. So a
budget that exists with no enabled alert is a `[FAIL]`, not a `[PASS]` — it notifies nobody.

`Get-AzConsumptionBudget` reads budgets at subscription or resource group scope. Microsoft documents
the PowerShell Consumption SDK as available to **Enterprise Agreement customers only**, so on a
non-EA subscription the read can fail even though a budget exists in the portal. That failure is
reported `[MANUAL]` with the portal location — never `[FAIL]`, and never `[PASS]`.

### Parameters

`-PilotSiteUrl` and `-PilotLibraryName` are spelled and meant exactly as in
`Enable-SyntexPayAsYouGo.ps1`, so the two scripts take the same arguments.

| Parameter | Required | Purpose |
|---|---|---|
| `-TenantAdminUrl` | Yes | The expected tenant. Never contacted; check 1 compares the existing session against it. |
| `-PilotSiteUrl` | No | The site processing is supposed to be scoped to. Same name/meaning as in the enable script. |
| `-PilotLibraryName` | No | The dedicated pilot library. Same name/meaning as in the enable script. Reading it needs the PnP session pointed at `-PilotSiteUrl`. |
| `-AzureSubscriptionId` | No | Enables the Azure-side reads in checks 3 and 6. |
| `-ResourceGroup` | No | Narrows checks 3 and 6 to that resource group scope. |
| `-BudgetName` | No | Look for one specific budget. Omitted: any budget with an enabled alert satisfies check 6. |
| `-MaxBudgetAmount` | No | Ceiling for the pilot. A budget above it fails check 6 — a budget set far above intended spend is not a guard rail. |
| `-ContentCenterUrl` | No | Verify one specific content center. Omitted: sites are enumerated by web template `CONTENTCTR#0` rather than guessing a URL. |
| `-UsageLookbackDays` | No | How far back check 3 looks for a document processing meter. Default 30. |
| `-FailOnIncomplete` | No | Exit `1` unless every check returned `[PASS]`. Without it the script always exits `0` and the `Result:` line is the verdict. |

### PowerShell edition caveat, sharpened

`Microsoft.Online.SharePoint.PowerShell` still cannot load under PowerShell 7, so checks 2 and the
scope half of check 4 degrade to `[MANUAL]` there. Testing this script surfaced the mirror image of
that problem on the same host: `Az.Billing 2.3.0` demands `Az.Accounts 5.5.0` under PowerShell 7,
and `Az.Accounts 5.3.2` throws `MissingMethodException` under Windows PowerShell 5.1.

| | PowerShell 7.6 | Windows PowerShell 5.1 |
|---|---|---|
| `Microsoft.Online.SharePoint.PowerShell` | `TypeLoadException` — cannot load | Loads; `Get-SPOTenant` reachable |
| `Az.Accounts` 5.3.2 | Loads; context readable | `Get-AzContext` throws |
| `Az.Billing` 2.3.0 | Wants `Az.Accounts` 5.5.0 | blocked by the above |

So on an unrepaired host the SharePoint reads and the Azure reads cannot run in the same edition.
The verifier degrades each affected check independently rather than failing, so it still produces a
useful report either way — but a live verification run wants the Az module set repaired first:

```powershell
Install-Module Az.Accounts -RequiredVersion 5.5.0 -Scope CurrentUser -Force
```

### Idempotency

Trivial: it is read-only, so any number of runs produce the same result and no side effect.

### Examples

```powershell
# Minimal - reports what it can read from whatever sessions exist
.\Test-SyntexSetup.ps1 -TenantAdminUrl "https://contoso-admin.sharepoint.com"

# Verify the pilot library itself (session must be pointed at the pilot site)
Connect-PnPOnline -Url "https://contoso.sharepoint.com/sites/pilot" -Interactive
.\Test-SyntexSetup.ps1 `
    -TenantAdminUrl "https://contoso-admin.sharepoint.com" `
    -PilotSiteUrl "https://contoso.sharepoint.com/sites/pilot" `
    -PilotLibraryName "Syntex Pilot"

# Full run including the Azure linkage and budget reads, capped at 50
.\Test-SyntexSetup.ps1 `
    -TenantAdminUrl "https://contoso-admin.sharepoint.com" `
    -PilotSiteUrl "https://contoso.sharepoint.com/sites/pilot" `
    -PilotLibraryName "Syntex Pilot" `
    -AzureSubscriptionId "00000000-0000-0000-0000-000000000000" `
    -ResourceGroup "rg-syntex-pilot" `
    -BudgetName "syntex-pilot-budget" `
    -MaxBudgetAmount 50
```

Full comment-based help is in the script: `Get-Help .\Test-SyntexSetup.ps1 -Full`.

### Evidence produced

| File | Contents |
|---|---|
| [`docs/evidence/t4-test-scaffold.txt`](../../docs/evidence/t4-test-scaffold.txt) | Scaffold transcripts in both PowerShell editions, `-FailOnIncomplete` exit codes, comment-based-help completeness, PSScriptAnalyzer output, and three independent proofs that the script mutates nothing: an AST walk of every command it can invoke, a classified grep, and 60 command breakpoints with 0 trips. Redacted — placeholder values only, with the raw transcript's SHA-256 recorded. |
