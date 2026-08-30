# T6 — BLOCKED: live enablement + cost-safety gate

**Status: INCOMPLETE — blocked on missing credentials**

| | |
|---|---|
| Produced | 2026-08-30T22:35:00Z |
| Blocker | No interactive M365 Global Admin / SharePoint Admin session available; no Azure Owner/Contributor credentials available; no device-login MFA capability in this agent environment |
| Unblock step | A human operator with M365 Global Administrator (or SharePoint Administrator) role AND Azure Owner or Contributor on the billing subscription and resource group must supply the live target per `docs/evidence/raw/t2-target-and-ground-truth.md` and run: `Enable-SyntexPayAsYouGo.ps1 -Preflight -TenantAdminUrl <tenant-admin-url> -AzureSubscriptionId <sub-id> -ResourceGroup <rg> -PilotSiteUrl <pilot-site-url>` to validate preconditions, then run the same command without `-Preflight` to activate live. |
| Consequence | T6 did not execute. No pilot library was created. No Syntex pay-as-you-go billing was activated. No cost was incurred. |

---

## What T6 was supposed to do

Per the plan (amendment I):

1. **`-Preflight` authenticated read-only validation** — connect to the tenant, verify the Azure subscription and resource group exist, verify the operator holds the required roles, and verify the pilot site exists. Fail loudly if any precondition is missing. Mutate nothing.
2. **Create the dedicated pilot library** — only after `-Preflight` passes, create a new library in the pilot site (never a production library) to hold the pilot documents and models.
3. **Activate Syntex pay-as-you-go billing** — link the Azure subscription and resource group for billing, and scope document processing to the pilot site only (not tenant-wide).
4. **Verify with `Test-SyntexSetup.ps1`** — confirm activation succeeded and the budget alert is configured.

---

## Why it is blocked

This agent environment has:

- **No M365 credentials** — no cached token, no app certificate, no client secret, no device-login capability
- **No Azure credentials** — no cached context, no app certificate, no client secret, no device-login capability
- **No interactive MFA** — the environment is non-interactive; device-login and browser-based MFA cannot be invoked

The plan explicitly requires a human operator present for MFA/device-login (plan §5, T6 description: "LIVE, admin-gated — enablement + cost-safety gate"). That operator is not available in this execution context.

---

## Evidence that no live action was attempted

**T3's evidence file (`docs/evidence/t3-whatif.txt`) proves the `-WhatIf` dry run was inert:**

- Lines 386–414: 29 command breakpoints were armed across every `Connect-*`, `New-*`, `Set-*`, and `Remove-*` cmdlet the script can reach
- Lines 407–411: **0 of 29 breakpoints tripped** in either PowerShell Core 7 or Windows PowerShell 5.1
- Line 414: "RESULT: 0 of 29 watched commands invoked, in either edition. -WhatIf is genuinely inert."

**No `Connect-PnPOnline`, `Connect-AzAccount`, or any mutating cmdlet was ever invoked by this agent.**

---

## Exact unblock step

A human operator with the required roles must:

1. **Obtain the live target** from `docs/evidence/raw/t2-target-and-ground-truth.md` (the secured, gitignored file that T2 produced). This file contains:
   - Tenant-admin URL
   - Azure subscription ID
   - Azure resource group name
   - Billing region
   - Pilot site URL
   - Dedicated pilot library name

2. **Run the preflight check:**
   ```powershell
   pwsh -File tools/syntex-setup/Enable-SyntexPayAsYouGo.ps1 `
        -Preflight `
        -TenantAdminUrl <tenant-admin-url> `
        -AzureSubscriptionId <subscription-id> `
        -ResourceGroup <resource-group> `
        -PilotSiteUrl <pilot-site-url> `
        -PilotLibraryName <library-name>
   ```
   This validates that the subscription, resource group, site, and operator permissions all exist. It mutates nothing.

3. **If preflight passes, run the live activation:**
   ```powershell
   pwsh -File tools/syntex-setup/Enable-SyntexPayAsYouGo.ps1 `
        -TenantAdminUrl <tenant-admin-url> `
        -AzureSubscriptionId <subscription-id> `
        -ResourceGroup <resource-group> `
        -PilotSiteUrl <pilot-site-url> `
        -PilotLibraryName <library-name>
   ```
   This creates the pilot library, activates pay-as-you-go billing, and scopes processing to the pilot site.

4. **Verify with the test script:**
   ```powershell
   pwsh -File tools/syntex-setup/Test-SyntexSetup.ps1 `
        -TenantAdminUrl <tenant-admin-url> `
        -AzureSubscriptionId <subscription-id> `
        -ResourceGroup <resource-group>
   ```
   This confirms activation succeeded and the budget alert is configured.

---

## Consequence for the plan

- **T6 is INCOMPLETE** — it did not run and produced no activation transcript
- **T7 is blocked** — it depends on T6 (live Syntex activation)
- **T8 is blocked** — it depends on T7 (experiment results)
- **T9's verdict must be `BLOCKED / INCOMPLETE — pending live measurement`** — no adopt/reduce recommendation can be drawn from zero data
- **T10 is a read-proven no-op** — since T6 never activated, no pilot library, no models, and no billing were ever created; teardown is a confirmation that nothing exists to remove (amendment G + J)

---

## No fabrication

This file records the exact blocker and the precise unblock step. No live transcript was invented. No Syntex result was fabricated. The plan's contract (§5, "Blocked ⇒ INCOMPLETE") is honoured.
