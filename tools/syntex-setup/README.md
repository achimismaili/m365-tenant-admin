# Syntex setup

Tools for turning Microsoft Syntex / SharePoint Premium **pay-as-you-go document processing** on in
a Microsoft 365 tenant, scoping it to the sites you actually intend to bill for, and verifying the
result.

| Script | Kind | Status |
|---|---|---|
| [`Enable-SyntexPayAsYouGo.ps1`](Enable-SyntexPayAsYouGo.ps1) | Mutating, idempotent | Available |
| `Test-SyntexSetup.ps1` | Read-only verifier | Not yet written |
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
