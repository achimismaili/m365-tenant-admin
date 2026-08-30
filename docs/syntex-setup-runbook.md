# Microsoft Syntex pay-as-you-go: setup and cost-safety runbook

Hand-over document for enabling **Microsoft Syntex document processing** (also branded SharePoint
Premium) in a Microsoft 365 tenant on a pay-as-you-go basis.

This runbook is tenant-agnostic. Every URL, GUID and site name below is a placeholder
(`contoso.onmicrosoft.com`, `00000000-0000-0000-0000-000000000000`, `rg-syntex-pilot`). Substitute
your own values. Nothing here is hardcoded to a specific customer.

**Read section 4 before you activate anything.** Activation starts billable, per-page activity that
no software gate in this repo can stop once a model is applied to a library.

---

## 1. What Syntex does + the full cost model

### What it does

Syntex document processing applies AI models to files in a **SharePoint document library**. A model
classifies an incoming document and extracts named values out of it into library columns, so a
scanned PDF stops being an opaque blob and becomes a list item with real metadata you can filter,
sort and search on. Three model families matter here:

| Family | What it is |
|---|---|
| **Prebuilt** | Ready-made models for common document types (invoices, receipts). Configurable from a single file. No training. |
| **Unstructured** | Custom models you train to classify and extract from free-text documents such as contracts and letters. |
| **Structured / freeform** | Custom extraction models built on Power Apps AI Builder for forms and semi-structured layouts. |

### The cost model

There is **no per-user licence** for pay-as-you-go. Billing runs through an Azure subscription you
nominate, metered per transaction.

| Service | Meter | Price (USD) |
|---|---|---|
| Prebuilt document processing | per page (PDF or image) | **$0.01 / transaction** |
| Unstructured document processing (custom classification) | per page, sheet, slide or file | **$0.005 / transaction** |
| Structured and freeform document processing (custom extraction) | per page (PDF or image) | **$0.05 / transaction** |

Source, verified against Microsoft Learn:
<https://learn.microsoft.com/microsoft-365/documentprocessing/syntex-pay-as-you-go-services>

Those three figures are the current published rates on that page. Prices can change, so re-check the
link before quoting a number to a budget holder.

### What is actually billed, and what is not

Microsoft states this explicitly on the page above. Read it carefully, because the surprises live
here:

- **Model training is free.** You are not charged for teaching a model.
- **Uploads are billed.** Every document added to a library with a model applied is processed.
- **Subsequent updates are billed again.** Editing an already processed file re-processes it. A file
  edited ten times is billed eleven times.
- **Failures are billed.** You pay "whether or not there's a positive classification, or any
  entities extracted". A page that Syntex cannot read still costs money.
- **Each applied model is metered separately.** Microsoft's own example: two models applied to one
  library, upload a five-page document, **ten pages** are billed.

That last point is the one that quietly multiplies a bill. Two models on a library doubles the rate.
Three triples it.

### Free trial capacity

Through June 2026 Microsoft grants a limited monthly allowance at no charge once pay-as-you-go
billing is configured: 100 pages/month each for prebuilt, structured and unstructured processing
(unstructured shares its 100 with autofill columns). Capacity is per tenant, not per user. Anything
above the allowance is billed at the rates in the table.
<https://learn.microsoft.com/microsoft-365/documentprocessing/promo-syntex>

---

## 2. Prerequisites

### Licensing

Syntex pay-as-you-go needs **no per-user Syntex licence**. Per the Microsoft Syntex service
description: it "is available on a pay-as-you-go basis through an Azure subscription. Users must have
a valid Office 365, Microsoft 365, or SharePoint Online license to be eligible to use Microsoft
Syntex."
<https://learn.microsoft.com/office365/servicedescriptions/microsoft-syntex-service-description/microsoft-syntex-service-description>

In practice that means any plan that carries SharePoint Online qualifies, **Microsoft 365 Business
Basic and upwards included**. You buy nothing per head. You pay per page.

### Admin roles

| Where | Role needed | Note |
|---|---|---|
| Microsoft 365 | **SharePoint Administrator** (preferred) or Global Administrator | Microsoft's own guidance is to prefer the least-privileged role. Use SharePoint Administrator unless you genuinely cannot. |
| Azure subscription | **Owner** or **Contributor** | Required on the subscription used for billing. |
| Azure resource group | **Owner** or **Contributor** | Required on the resource group the meter attaches to. |

### Azure resources

- An **Azure subscription in the same tenant** as Microsoft 365. A subscription in a different tenant
  cannot be linked.
- An **Azure resource group** inside that subscription. An existing one is fine.

Both prerequisites are stated at
<https://learn.microsoft.com/microsoft-365/documentprocessing/syntex-azure-billing>.

### PowerShell modules (only for the scripted path)

```powershell
Install-Module PnP.PowerShell                         -Scope CurrentUser
Install-Module Microsoft.Online.SharePoint.PowerShell -Scope CurrentUser
Install-Module Az.Accounts, Az.Resources              -Scope CurrentUser
```

`Microsoft.Online.SharePoint.PowerShell` declares no PowerShell Core compatibility, so the scoping
step must run from **Windows PowerShell 5.1**. The script detects this and says so instead of failing
obscurely.

---

## 3. Step-by-step

Two paths lead to the same result. **Billing activation itself is portal-only**: no documented cmdlet
exists in PnP.PowerShell, the SharePoint Online Management Shell or the Az modules for choosing the
subscription, resource group and region and accepting the terms. The scripted path automates
everything around it and prints the click-path for the one step it cannot do.

### (a) Portal path

**Step 1: link the Azure subscription and accept the terms.**

```
https://admin.microsoft.com
  -> Setup
  -> Billing and licenses section
  -> Activate pay-as-you-go services
  -> Get started
  -> Pay-as-you-go services page -> Billing tab
  -> Document processing services
  -> Set up billing and turn on services
       -> Azure subscription : <your subscription>
       -> Resource group     : rg-syntex-pilot
       -> Region             : <see section 7, this is a data-residency choice>
  -> read and accept the pay-as-you-go terms of service
  -> Save
```

The Pay-as-you-go services page is also reachable directly via
**Settings -> Org settings -> Services tab -> Pay-as-you-go services**. Older admin-center builds
expose the same switch under **Settings -> Org settings -> Services -> Microsoft Syntex**. Both are
valid; use whichever your tenant's UI shows.

**Step 2: turn a service on and scope it to the intended sites.**

```
Pay-as-you-go services page
  -> Settings tab
  -> Document processing services
  -> select the service, for example "Prebuilt document processing"
  -> site options: choose "Selected sites" and add ONLY the pilot site
  -> Save
```

Do not leave this on an all-sites default. See section 4.

Reference: <https://learn.microsoft.com/microsoft-365/documentprocessing/syntex-azure-billing>

### (b) Scripted path

`tools/syntex-setup/Enable-SyntexPayAsYouGo.ps1` is idempotent: re-running it against an already
configured tenant reports the existing state and changes nothing. It has three modes.

**Mode 1: `-WhatIf`, fully offline dry run.** Opens no connection, contacts no tenant, mutates
nothing, exits `0` even with entirely fake values. Run this first.

```powershell
.\Enable-SyntexPayAsYouGo.ps1 -WhatIf `
    -TenantAdminUrl "https://contoso-admin.sharepoint.com" `
    -AzureSubscriptionId "00000000-0000-0000-0000-000000000000" `
    -ResourceGroup "rg-syntex-pilot" `
    -PilotSiteUrl "https://contoso.sharepoint.com/sites/pilot"
```

It prints the full intended action list, the site-scope decision, and the manual portal steps.

**Mode 2: `-Preflight`, authenticated but read-only.** Connects and proves the subscription, resource
group, pilot site and your rights all really exist. Fails loudly on the first missing resource.
Mutates nothing.

```powershell
.\Enable-SyntexPayAsYouGo.ps1 -Preflight `
    -TenantAdminUrl "https://contoso-admin.sharepoint.com" `
    -AzureSubscriptionId "00000000-0000-0000-0000-000000000000" `
    -ResourceGroup "rg-syntex-pilot" `
    -Region "westeurope" `
    -PilotSiteUrl "https://contoso.sharepoint.com/sites/pilot" `
    -DeviceLogin
```

**Mode 3: live.** Runs the preflight first and refuses to continue if it fails. Then creates the
dedicated pilot library if it is missing, prints the portal billing steps, and applies the processing
scope via `Set-SPOTenant -PrebuiltModelScope SelectedSites`.

```powershell
.\Enable-SyntexPayAsYouGo.ps1 `
    -TenantAdminUrl "https://contoso-admin.sharepoint.com" `
    -AzureSubscriptionId "00000000-0000-0000-0000-000000000000" `
    -ResourceGroup "rg-syntex-pilot" `
    -Region "westeurope" `
    -PilotSiteUrl "https://contoso.sharepoint.com/sites/pilot" `
    -PilotLibraryName "Syntex Pilot"
```

Omitting `-PilotSiteUrl` means tenant-wide enablement, which the script **refuses** unless you also
pass `-AcknowledgeTenantWide`. That refusal is deliberate. Do not reach for the switch to make an
error go away.

Full help: `Get-Help .\Enable-SyntexPayAsYouGo.ps1 -Full`.

---

## 4. Cost control

### Set an Azure budget and an alert, before activating

Azure portal -> **Cost Management + Billing** -> **Cost Management** -> **Budgets** -> **Add**.
Scope the budget to the resource group you nominated (`rg-syntex-pilot`), set a monthly amount you
are genuinely willing to lose, and add alert thresholds at 50%, 80% and 100% with a real email
recipient.

Then two warnings that matter more than the budget itself:

> **A budget alert is a notification, not a hard spending cap.** Azure will not stop processing, will
> not disable the meter, and will not block further charges when the budget is exceeded. It sends
> mail. Spending continues until a human turns the service off (section 6).

> **Cost data lags.** Microsoft states usage information "might take up to 24 hours to appear in Cost
> Management". A runaway job can bill for a full day before you can see it. Do not treat a quiet Cost
> Analysis blade as proof that nothing is being charged.

Monitoring path: Azure portal -> **Cost Management** -> **Cost analysis** -> **Add filter** ->
**Product**, and a second filter on **Tag** -> **Site**, which lets you attribute cost per SharePoint
site.
<https://learn.microsoft.com/microsoft-365/documentprocessing/syntex-azure-billing>

### Scope to the intended libraries only

Processing is enabled per site and applied per library. If you do not restrict the scope, **billing
can extend well beyond the one library you had in mind**: an all-sites setting means every document
uploaded or edited anywhere in the tenant, in any library with a model applied, is a billable
transaction. On a tenant with an active document flow that is not a rounding error.

Rules for a first run:

1. Always choose **Selected sites** in the portal, or supply `-PilotSiteUrl` to the script.
2. Apply the model to a **dedicated pilot library** that contains only the documents you intend to
   pay for. Never point a first run at a production library.
3. Never accept tenant-wide unless someone with budget authority has explicitly acknowledged it in
   writing.
4. Apply **one model at a time**. Two models on a library doubles the per-page bill (section 1).

### Verify no production library has a model applied

Do this **before** activation, to establish a clean baseline, and **again after**, to prove nothing
leaked. For each production library: open the library -> **Automate** -> **Apply a model**, and
confirm no model is listed as applied. Record the result. If a model is already applied somewhere you
did not expect, stop and resolve that before activating anything new.

---

## 5. Verification

`tools/syntex-setup/Test-SyntexSetup.ps1` is the read-only companion verifier. It re-runs safely,
mutates nothing, and reports `[PASS]` or `[FAIL]` per check: billing linkage state, the resolved
processing scope, the selected-sites list, and the presence of the pilot library.

```powershell
.\Test-SyntexSetup.ps1 `
    -TenantAdminUrl "https://contoso-admin.sharepoint.com" `
    -AzureSubscriptionId "00000000-0000-0000-0000-000000000000" `
    -ResourceGroup "rg-syntex-pilot" `
    -PilotSiteUrl "https://contoso.sharepoint.com/sites/pilot"
```

Run it after enablement and **before uploading any billable document**. A green run is your evidence
that the scope is what you think it is. Confirm `[PASS]` on the scope check specifically: it is the
one that separates a $2 pilot from a tenant-wide bill.

If the script is not present in your copy of the repo yet, do the equivalent by hand: read the
current scope with `Get-SPOTenant` and confirm `PrebuiltModelScope` is `SelectedSites` and that
`PrebuiltModelSelectedSitesList` contains only your pilot site.

---

## 6. How to turn it off

Two levels. Do both if you want billing to stop completely.

**Level 1: remove the models and narrow the scope.** Faster, and it is what actually stops new
transactions.

1. In each library: **Automate** -> **Apply a model** -> remove the applied model.
2. In the admin center: **Settings -> Org settings -> Services tab -> Pay-as-you-go services ->
   Settings tab -> Document processing services**, and turn the individual service off (or set its
   site option to no sites).
3. Or, scripted: `Set-SPOTenant -PrebuiltModelScope NoSites`.

**Level 2: disconnect the Azure subscription.** This unlinks the meter entirely.

```
https://admin.microsoft.com
  -> Settings -> Org settings
  -> Pay-as-you-go services page -> Billing tab
  -> Document processing services
  -> Manage billing panel -> Azure subscription -> Edit billing information
  -> Manage billing -> Disconnect Azure subscription
  -> Disconnect subscription? -> Disconnect
  -> confirm the message that the Azure subscription has been disconnected
```

**Post-run cost check, do not skip this.** Because cost data lags up to 24 hours, turning the service
off does not mean the invoice is final. Wait at least 24 to 48 hours after disconnecting, then return
to **Cost Management -> Cost analysis**, filter by **Product** and by the **Site** tag, and confirm
the total charge matches what you expected. Charges already incurred will still land after the
service is off. Put a calendar reminder on it.

---

## 7. Region and data residency

When you link the Azure subscription you must choose a **region**. Microsoft's documentation states
plainly what this controls:

> "The region determines where your tenant ID and usage information such as site names will be
> stored."
> <https://learn.microsoft.com/microsoft-365/documentprocessing/syntex-azure-billing>

Two points to disclose to the client before they click Save:

1. This is a **data-residency decision**, not a performance setting. Choose it deliberately. For EU
   customers with a residency requirement, pick an EU region such as `westeurope`.
2. The stored metadata is not just an anonymous counter. It includes the **tenant ID** and **site
   names**. Site names in a real tenant can carry meaningful information (customer names, project
   names, property designations). If that is sensitive in your organisation, take it into account
   when naming the pilot site and when choosing the region.

The `Site` tag surfaced in Azure Cost Management is the same metadata, which is why per-site cost
attribution works at all.

---

## 8. Scope note

Syntex processing is applied at the **SharePoint document library** level.

- **Not per document.** You cannot mark one file as "process this" and another as "skip this" inside
  the same library. Every file that lands in a library with a model applied is processed and billed.
  The unit of control is the library, so control it by choosing what goes into which library.
- **Not per site globally, unless you configure it that way.** Enabling the service on a site does
  not by itself process everything in that site. A model still has to be applied to a specific
  library. But the tenant-level scope setting (`AllSites` versus `SelectedSites`) decides which sites
  are even permitted to have models applied, and setting it to all sites is what turns a contained
  pilot into open-ended exposure.

Practical consequence: the cheapest and safest control surface is the library boundary. Create a
dedicated library, put exactly the documents you intend to pay for into it, apply exactly one model,
and leave every production library untouched until the pilot numbers are in.
