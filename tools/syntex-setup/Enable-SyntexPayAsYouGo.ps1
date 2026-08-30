<#
.SYNOPSIS
    Activates Microsoft Syntex pay-as-you-go document processing for a Microsoft 365
    tenant, links it to an Azure subscription for billing, and scopes processing to a
    single pilot site instead of the whole tenant.

.DESCRIPTION
    Idempotent enablement tool for Syntex / SharePoint Premium pay-as-you-go document
    processing. Re-running it against an already-configured tenant reports the existing
    state and changes nothing.

    THE SCRIPT HAS THREE EXECUTION MODES
    ------------------------------------
    1. -WhatIf   OFFLINE DRY RUN.
                 Makes no connection of any kind, contacts no tenant, and mutates
                 nothing. It prints the full intended action list, including the
                 site-scope-versus-tenant-wide decision and the exact manual portal
                 steps, then exits 0. It exits 0 even when every parameter value is
                 fake, so it is safe to run before a live target has been chosen.

    2. -Preflight
                 AUTHENTICATED READ-ONLY VALIDATION.
                 Connects, then verifies that the Azure subscription, the resource
                 group, the pilot site and the operator's rights actually exist and
                 are usable. Fails loudly with an explicit message on the first
                 missing resource. Mutates nothing. Use this to prove a target is
                 sound before spending money.

    3. (neither) LIVE RUN.
                 Runs the full -Preflight validation first and refuses to continue if
                 it fails. Only then does it mutate: it creates the dedicated pilot
                 library (when -PilotLibraryName is supplied and the library does not
                 exist), then applies the processing scope, then reports the billing
                 activation state.

    WHAT IS SCRIPTABLE AND WHAT IS NOT (verified, not guessed)
    ----------------------------------------------------------
    * SCOPING processing to selected sites IS scriptable. It is exposed by
      Set-SPOTenant -PrebuiltModelScope / -PrebuiltModelSelectedSitesList /
      -PrebuiltModelSelectedSitesListOperation from the SharePoint Online Management
      Shell module (Microsoft.Online.SharePoint.PowerShell). -PrebuiltModelScope
      accepts NoSites, AllSites or SelectedSites; the list operation accepts
      Overwrite, Append or Remove. This script uses SelectedSites + Append.

    * PnP.PowerShell does NOT expose those parameters. Set-PnPTenant has no
      -PrebuiltModelScope parameter in the shipping module, so the scoping step
      deliberately falls through to the SharePoint Online Management Shell. The
      script probes for the capability at run time instead of assuming it.

    * ACTIVATING pay-as-you-go billing (choosing the Azure subscription, resource
      group and region and accepting the terms of service) is NOT scriptable. There
      is no documented cmdlet for it in PnP.PowerShell, in the SharePoint Online
      Management Shell, or in the Az modules. Rather than invent a plausible-looking
      cmdlet name, this script prints the exact portal click-path (see below) and
      reports that step as MANUAL.

    MANUAL PORTAL FALLBACK - billing activation
    -------------------------------------------
    Microsoft 365 admin center (https://admin.microsoft.com)
      -> Setup
      -> Billing and licenses
      -> Activate pay-as-you-go services
      -> Get started
      -> Pay-as-you-go services page -> Billing tab
      -> Document processing services
      -> Set up billing and turn on services
      -> choose the Azure subscription, the resource group and the region
      -> read and accept the pay-as-you-go terms of service
      -> Save

    MANUAL PORTAL FALLBACK - turning a specific service on and choosing its sites
    -----------------------------------------------------------------------------
    Same Pay-as-you-go services page
      -> Settings tab
      -> Document processing services
      -> select the service (for example Prebuilt document processing)
      -> choose the site options (select "Selected sites" and add the pilot site
         only; do not leave it on all sites)
      -> Save

    An older build of the admin center exposed the same switch under
    Settings -> Org settings -> Services -> Microsoft Syntex. If the Setup path above
    is not present in the tenant, look there instead.

    Reference documentation:
      https://learn.microsoft.com/microsoft-365/documentprocessing/syntex-azure-billing
      https://learn.microsoft.com/microsoft-365/documentprocessing/set-up-microsoft-syntex
      https://learn.microsoft.com/powershell/module/microsoft.online.sharepoint.powershell/set-spotenant

    COST WARNING
    ------------
    Pay-as-you-go document processing bills per page against the linked Azure
    subscription. Uploads, later updates to an already processed file, and pages that
    fail processing are all billed. Set an Azure budget and alert before activating,
    and remember that a budget alert is a notification, not a hard spending cap.

    REQUIRED RIGHTS
    ---------------
    * SharePoint Administrator or Global Administrator in Microsoft 365.
    * Owner or Contributor on the Azure subscription and on the resource group.
    * The Azure subscription must live in the same tenant as Microsoft 365.

.PARAMETER TenantAdminUrl
    SharePoint tenant administration URL, for example
    https://contoso-admin.sharepoint.com. Required in every mode. In -WhatIf mode the
    value is echoed but never contacted.

.PARAMETER AzureSubscriptionId
    GUID of the Azure subscription that will carry the pay-as-you-go charges.
    Validated for existence during -Preflight and before any live mutation. In
    -WhatIf mode a malformed value is reported as a note and does not fail the run.

.PARAMETER ResourceGroup
    Name of the Azure resource group, inside AzureSubscriptionId, that the billing
    meter is attached to. Validated during -Preflight.

.PARAMETER Region
    Billing region for the pay-as-you-go meter, for example westeurope. The region
    determines where the tenant ID and usage metadata such as site names are stored,
    so it is a data-residency decision. Optional: when it is omitted the portal step
    will prompt for it.

.PARAMETER PilotSiteUrl
    Full URL of the single site collection that document processing should be limited
    to, for example https://contoso.sharepoint.com/sites/pilot. Supplying this is what
    keeps the activation site-scoped. When it is omitted the only remaining option is
    tenant-wide enablement, which requires -AcknowledgeTenantWide.

.PARAMETER PilotLibraryName
    Optional display name of a dedicated document library to create inside
    PilotSiteUrl before activation. If the library already exists it is reported and
    left untouched. If the parameter is omitted no library is created.

.PARAMETER DeviceLogin
    Authenticate with the device-code flow instead of launching a browser. Useful on
    a headless or remote host. Note that the SharePoint Online Management Shell
    (Connect-SPOService), which is required for the scoping step, has no device-code
    option and will still open a browser.

.PARAMETER Preflight
    Run the authenticated read-only validation and then stop. Nothing is created,
    changed or activated. This is the safe way to prove that a subscription, resource
    group and site exist and that the operator holds the necessary rights.

.PARAMETER AcknowledgeTenantWide
    Explicit acknowledgement that processing may be enabled for every site in the
    tenant. Required only when -PilotSiteUrl is not supplied, or when the detected
    activation surface offers no site scoping at all. Without this switch the script
    refuses to enable anything tenant-wide.

.EXAMPLE
    .\Enable-SyntexPayAsYouGo.ps1 -WhatIf `
        -TenantAdminUrl "https://contoso-admin.sharepoint.com" `
        -AzureSubscriptionId "00000000-0000-0000-0000-000000000000" `
        -ResourceGroup "rg-syntex-pilot" `
        -PilotSiteUrl "https://contoso.sharepoint.com/sites/pilot"

    Offline dry run. Prints every intended action and the site-scope decision, makes
    no connection, changes nothing and exits 0.

.EXAMPLE
    .\Enable-SyntexPayAsYouGo.ps1 -Preflight `
        -TenantAdminUrl "https://contoso-admin.sharepoint.com" `
        -AzureSubscriptionId "00000000-0000-0000-0000-000000000000" `
        -ResourceGroup "rg-syntex-pilot" `
        -Region "westeurope" `
        -PilotSiteUrl "https://contoso.sharepoint.com/sites/pilot" `
        -DeviceLogin

    Authenticated read-only validation using the device-code flow. Fails loudly if the
    subscription, the resource group or the site is missing. Mutates nothing.

.EXAMPLE
    .\Enable-SyntexPayAsYouGo.ps1 `
        -TenantAdminUrl "https://contoso-admin.sharepoint.com" `
        -AzureSubscriptionId "00000000-0000-0000-0000-000000000000" `
        -ResourceGroup "rg-syntex-pilot" `
        -Region "westeurope" `
        -PilotSiteUrl "https://contoso.sharepoint.com/sites/pilot" `
        -PilotLibraryName "Syntex Pilot"

    Live run. Validates first, then creates the "Syntex Pilot" library if it is absent
    and scopes prebuilt document processing to the pilot site only.

.NOTES
    Prerequisites
        PnP.PowerShell                          Install-Module PnP.PowerShell -Scope CurrentUser
        Microsoft.Online.SharePoint.PowerShell  Install-Module Microsoft.Online.SharePoint.PowerShell -Scope CurrentUser
        Az.Accounts and Az.Resources            Install-Module Az.Accounts, Az.Resources -Scope CurrentUser
    None of these are required for -WhatIf, which is fully offline.

    Idempotency
        Every mutating step reads the current state first. An already created library,
        an already scoped site and an already active service are each reported and
        skipped without raising an error.

    Confirmation
        The script declares SupportsShouldProcess with a High confirm impact because it
        can start billable activity. Pass -Confirm:$false to run it unattended.
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$TenantAdminUrl,

    [Parameter(Mandatory = $false)]
    [string]$AzureSubscriptionId,

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $false)]
    [string]$Region,

    [Parameter(Mandatory = $false)]
    [string]$PilotSiteUrl,

    [Parameter(Mandatory = $false)]
    [string]$PilotLibraryName,

    [Parameter(Mandatory = $false)]
    [switch]$DeviceLogin,

    [Parameter(Mandatory = $false)]
    [switch]$Preflight,

    [Parameter(Mandatory = $false)]
    [switch]$AcknowledgeTenantWide
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# =============================================================================
# Console helpers
# =============================================================================

function Write-Console {
    <#
        .SYNOPSIS
            Single console sink for the whole script.
        .DESCRIPTION
            Write-Host is intentional here. This is an interactive operator tool whose
            output is a transcript for a human, not a pipeline of objects, and the
            colour coding carries the [OK]/[FAIL]/[MANUAL] meaning.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost', '',
        Justification = 'Operator-facing transcript; colour is part of the contract.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [AllowEmptyString()]
        [string]$Message = '',

        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$Colour = 'Gray'
    )
    Write-Host $Message -ForegroundColor $Colour
}

function Write-Section {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Title
    )
    Write-Console ''
    Write-Console $Title 'Cyan'
    Write-Console ('-' * $Title.Length) 'Cyan'
}

function Test-GuidFormat {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Value
    )
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    $parsed = [guid]::Empty
    return [guid]::TryParse($Value, [ref]$parsed)
}

function Get-ProcessingScopePlan {
    <#
        .SYNOPSIS
            Decides site-scoped versus tenant-wide from the supplied parameters alone.
        .DESCRIPTION
            Deliberately pure: it touches no network and no module, so the -WhatIf
            dry run can print exactly the decision a live run would take.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$SiteUrl,

        [Parameter(Mandatory = $false)]
        [bool]$TenantWideAcknowledged = $false
    )

    if (-not [string]::IsNullOrWhiteSpace($SiteUrl)) {
        return @{
            Scope        = 'SelectedSites'
            Sites        = @($SiteUrl)
            Operation    = 'Append'
            Allowed      = $true
            Reason       = "PilotSiteUrl was supplied, so processing is restricted to that one site."
            TenantWide   = $false
        }
    }

    return @{
        Scope        = 'AllSites'
        Sites        = @()
        Operation    = 'Overwrite'
        Allowed      = $TenantWideAcknowledged
        Reason       = if ($TenantWideAcknowledged) {
            "No PilotSiteUrl was supplied and -AcknowledgeTenantWide was passed, so processing would be enabled for EVERY site in the tenant."
        } else {
            "No PilotSiteUrl was supplied. Tenant-wide enablement is blocked until -AcknowledgeTenantWide is passed explicitly."
        }
        TenantWide   = $true
    }
}

function Import-CandidateModule {
    <#
        .SYNOPSIS
            Tries to load a module so that its cmdlets become discoverable.
        .DESCRIPTION
            Get-Command auto-discovery skips modules whose CompatiblePSEditions does
            not include Core, which is exactly the case for the Windows PowerShell
            builds of Microsoft.Online.SharePoint.PowerShell and PnP.PowerShell 1.x.
            Probing without this step reports a false "no cmdlet available".
            Loading a module opens no connection, so this is safe inside -WhatIf.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Name
    )

    if (Get-Module -Name $Name) { return 'Loaded' }
    if (-not (Get-Module -ListAvailable -Name $Name -ErrorAction SilentlyContinue)) { return 'NotInstalled' }

    try {
        Import-Module -Name $Name -DisableNameChecking -ErrorAction Stop -WarningAction SilentlyContinue
        return 'Loaded'
    } catch {
        Write-Verbose "Import of '$Name' failed: $($_.Exception.Message)"
        return 'InstalledButNotLoadable'
    }
}

function Get-ScopingCapability {
    <#
        .SYNOPSIS
            Probes, offline, which cmdlet surface can scope Syntex processing.
        .DESCRIPTION
            Loads candidate modules and inspects their parameter metadata. It never
            opens a connection and never invokes a tenant cmdlet, so it is safe
            inside -WhatIf.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $result = @{
        Provider   = 'PortalOnly'
        Cmdlet     = ''
        Detail     = ''
        ModuleNote = ''
    }

    $notes = New-Object System.Collections.Generic.List[string]

    $candidates = @(
        @{ Module = 'PnP.PowerShell';                        Cmdlet = 'Set-PnPTenant'; Provider = 'PnP' },
        @{ Module = 'Microsoft.Online.SharePoint.PowerShell'; Cmdlet = 'Set-SPOTenant'; Provider = 'SPO' }
    )

    foreach ($candidate in $candidates) {
        $state = Import-CandidateModule -Name $candidate.Module

        # if/elseif, not switch: 'continue' inside a switch targets the switch, not
        # the enclosing foreach, which would silently skip the remaining candidates.
        if ($state -eq 'NotInstalled') {
            $notes.Add("$($candidate.Module): not installed.")
            continue
        }
        if ($state -eq 'InstalledButNotLoadable') {
            $notes.Add("$($candidate.Module): installed but could not be loaded in this PowerShell edition - run the live steps from Windows PowerShell 5.1, or install a Core-compatible build.")
            continue
        }

        $command = Get-Command -Name $candidate.Cmdlet -ErrorAction SilentlyContinue
        if ($null -eq $command) {
            $notes.Add("$($candidate.Module): loaded, but $($candidate.Cmdlet) was not found.")
            continue
        }
        if (-not $command.Parameters.ContainsKey('PrebuiltModelScope')) {
            $notes.Add("$($candidate.Cmdlet): present but has no -PrebuiltModelScope parameter, so it cannot scope Syntex processing.")
            continue
        }

        $result.Provider = $candidate.Provider
        $result.Cmdlet = $candidate.Cmdlet
        $result.Detail = "$($candidate.Cmdlet) exposes -PrebuiltModelScope (NoSites / AllSites / SelectedSites) and -PrebuiltModelSelectedSitesList."
        $result.ModuleNote = ($notes -join ' ')
        return $result
    }

    $result.Detail = 'No available cmdlet exposes a Syntex processing scope on this host; the portal fallback is the only route.'
    $result.ModuleNote = ($notes -join ' ')
    return $result
}

function Write-BillingPortalFallback {
    <#
        .SYNOPSIS
            Prints the exact, documented portal click-path for the one step that has
            no cmdlet.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$ResourceGroupName,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$BillingRegion
    )

    $regionText = if ([string]::IsNullOrWhiteSpace($BillingRegion)) {
        '<choose a region - it decides where tenant ID and usage metadata are stored>'
    } else {
        $BillingRegion
    }

    Write-Console '  [MANUAL] Pay-as-you-go billing activation has no documented cmdlet.' 'Yellow'
    Write-Console '           Complete it once, by hand, in the Microsoft 365 admin center:' 'Yellow'
    Write-Console ''
    Write-Console '           https://admin.microsoft.com'
    Write-Console '             -> Setup'
    Write-Console '             -> Billing and licenses'
    Write-Console '             -> Activate pay-as-you-go services'
    Write-Console '             -> Get started'
    Write-Console '             -> Pay-as-you-go services -> Billing tab'
    Write-Console '             -> Document processing services'
    Write-Console '             -> Set up billing and turn on services'
    Write-Console "                  Azure subscription : $SubscriptionId"
    Write-Console "                  Resource group     : $ResourceGroupName"
    Write-Console "                  Region             : $regionText"
    Write-Console '             -> read and accept the pay-as-you-go terms of service'
    Write-Console '             -> Save'
    Write-Console ''
    Write-Console '           Then turn the individual service on and choose its sites:'
    Write-Console '             -> Pay-as-you-go services -> Settings tab'
    Write-Console '             -> Document processing services'
    Write-Console '             -> Prebuilt document processing'
    Write-Console '             -> site options: choose "Selected sites" and add ONLY the pilot site'
    Write-Console '             -> Save'
    Write-Console ''
    Write-Console '           Older admin-center builds expose the same switch under'
    Write-Console '           Settings -> Org settings -> Services -> Microsoft Syntex.'
    Write-Console '           Docs: https://learn.microsoft.com/microsoft-365/documentprocessing/syntex-azure-billing'
}

# =============================================================================
# Banner and pure planning - no connection has been made at this point
# =============================================================================

$offlineDryRun = [bool]$WhatIfPreference

Write-Console ''
Write-Console 'Microsoft Syntex - pay-as-you-go document processing enablement' 'Cyan'
Write-Console '==============================================================' 'Cyan'

$modeLabel = if ($offlineDryRun) {
    'WHATIF (offline dry run - no connection, no mutation)'
} elseif ($Preflight) {
    'PREFLIGHT (authenticated, read-only - no mutation)'
} else {
    'LIVE (preflight, then mutate)'
}

Write-Console "Mode                : $modeLabel" 'White'
Write-Console "Tenant admin URL    : $TenantAdminUrl"
Write-Console "Azure subscription  : $(if ($AzureSubscriptionId) { $AzureSubscriptionId } else { '<not supplied>' })"
Write-Console "Resource group      : $(if ($ResourceGroup) { $ResourceGroup } else { '<not supplied>' })"
Write-Console "Billing region      : $(if ($Region) { $Region } else { '<not supplied - portal will prompt>' })"
Write-Console "Pilot site          : $(if ($PilotSiteUrl) { $PilotSiteUrl } else { '<not supplied>' })"
Write-Console "Pilot library       : $(if ($PilotLibraryName) { $PilotLibraryName } else { '<none - no library will be created>' })"
Write-Console "Sign-in method      : $(if ($DeviceLogin) { 'device code (-DeviceLogin)' } else { 'interactive browser' })"

$scopePlan = Get-ProcessingScopePlan -SiteUrl $PilotSiteUrl -TenantWideAcknowledged ([bool]$AcknowledgeTenantWide)
$capability = Get-ScopingCapability

Write-Section 'Processing scope decision'
Write-Console "  Decision            : $($scopePlan.Scope)" $(if ($scopePlan.TenantWide) { 'Yellow' } else { 'Green' })
Write-Console "  Reason              : $($scopePlan.Reason)"
if ($scopePlan.Sites.Count -gt 0) {
    Write-Console "  Selected sites      : $($scopePlan.Sites -join ', ')"
    Write-Console "  List operation      : $($scopePlan.Operation) (existing selected sites are preserved)"
}
Write-Console "  Tenant-wide         : $(if ($scopePlan.TenantWide) { 'YES' } else { 'no' })" $(if ($scopePlan.TenantWide) { 'Yellow' } else { 'Green' })
Write-Console "  Acknowledged        : $(if ($AcknowledgeTenantWide) { 'yes (-AcknowledgeTenantWide)' } else { 'no' })"

if ($scopePlan.TenantWide) {
    Write-Warning 'TENANT-WIDE ENABLEMENT REQUESTED. Every site in the tenant would become billable for document processing. Supply -PilotSiteUrl to scope it, or pass -AcknowledgeTenantWide to accept the exposure deliberately.'
}

Write-Section 'Activation surface detected (offline probe, no connection)'
Write-Console "  Scoping provider    : $($capability.Provider)"
Write-Console "  Scoping cmdlet      : $(if ($capability.Cmdlet) { $capability.Cmdlet } else { '<none - portal fallback>' })"
Write-Console "  Detail              : $($capability.Detail)"
if ($capability.ModuleNote) {
    Write-Console "  Module notes        : $($capability.ModuleNote)" 'Yellow'
}
Write-Console '  Billing activation  : PortalOnly (no documented cmdlet exists - see the MANUAL block below)' 'Yellow'

if ($capability.Provider -eq 'PortalOnly' -and -not $AcknowledgeTenantWide -and -not $offlineDryRun) {
    Write-Warning 'No scoping cmdlet is available on this host, so the portal flow would be the only way to enable the service. Confirm in the portal that "Selected sites" is chosen; do not accept an all-sites default.'
}

# =============================================================================
# MODE 1 - offline dry run. Nothing below this block is reached with -WhatIf.
# =============================================================================

if ($offlineDryRun) {
    Write-Section 'Intended actions (WOULD RUN - nothing was executed)'

    $step = 0

    $step++
    Write-Console "  $step. WOULD RUN: Connect-PnPOnline -Url '$TenantAdminUrl' $(if ($DeviceLogin) { '-DeviceLogin' } else { '-Interactive' })"

    if ($capability.Provider -eq 'SPO') {
        $step++
        Write-Console "  $step. WOULD RUN: Connect-SPOService -Url '$TenantAdminUrl'  (SharePoint Online Management Shell; no device-code option)"
    }

    $step++
    Write-Console "  $step. WOULD RUN: Get-AzSubscription / Get-AzResourceGroup read-only checks for subscription '$AzureSubscriptionId' and resource group '$ResourceGroup'"

    if ($PilotSiteUrl) {
        $step++
        Write-Console "  $step. WOULD RUN: Get-PnPTenantSite -Identity '$PilotSiteUrl'   (read-only existence check)"
    } else {
        $step++
        Write-Console "  $step. WOULD SKIP: pilot site existence check - no -PilotSiteUrl was supplied"
    }

    if ($PilotLibraryName) {
        $step++
        Write-Console "  $step. WOULD RUN: Get-PnPList -Identity '$PilotLibraryName' and, only if absent,"
        Write-Console "               New-PnPList -Title '$PilotLibraryName' -Template DocumentLibrary   (idempotent: existing library is left untouched)"
    } else {
        $step++
        Write-Console "  $step. WOULD SKIP: pilot library creation - no -PilotLibraryName was supplied"
    }

    $step++
    Write-Console "  $step. WOULD REPORT (manual): pay-as-you-go billing activation - portal only, see below"

    $step++
    if (-not $scopePlan.Allowed) {
        Write-Console "  $step. WOULD REFUSE: tenant-wide enablement without -AcknowledgeTenantWide. A live run would stop here with an error and activate nothing." 'Yellow'
    } elseif ($capability.Provider -eq 'PortalOnly') {
        Write-Console "  $step. WOULD REPORT (manual): processing scope '$($scopePlan.Scope)' - no scoping cmdlet on this host, so the portal Settings tab is the only route"
    } else {
        if ($scopePlan.Sites.Count -gt 0) {
            $siteArg = "'" + ($scopePlan.Sites -join "','") + "'"
            Write-Console "  $step. WOULD RUN: $($capability.Cmdlet) -PrebuiltModelScope $($scopePlan.Scope) -PrebuiltModelSelectedSitesList $siteArg -PrebuiltModelSelectedSitesListOperation $($scopePlan.Operation)"
        } else {
            Write-Console "  $step. WOULD RUN: $($capability.Cmdlet) -PrebuiltModelScope $($scopePlan.Scope)   (no site list is passed for a tenant-wide scope)"
        }
        Write-Console "               (preceded by a Get-SPOTenant read; if the scope and the site list already match, this is a reported no-op)"
    }

    Write-Section 'Manual portal fallback'
    Write-BillingPortalFallback -SubscriptionId $AzureSubscriptionId -ResourceGroupName $ResourceGroup -BillingRegion $Region

    Write-Section 'Dry-run notes'
    if (-not (Test-GuidFormat -Value $AzureSubscriptionId)) {
        Write-Console "  NOTE: '$AzureSubscriptionId' is not a well-formed GUID. A live run or -Preflight would reject it; an offline dry run does not." 'Yellow'
    }
    if ([string]::IsNullOrWhiteSpace($ResourceGroup)) {
        Write-Console '  NOTE: no resource group was supplied. A live run or -Preflight would reject that.' 'Yellow'
    }
    if ([string]::IsNullOrWhiteSpace($Region)) {
        Write-Console '  NOTE: no billing region was supplied. The portal step will prompt for one.' 'Yellow'
    }

    Write-Console ''
    Write-Console 'WHATIF COMPLETE. No connection was opened. No resource was created, changed or activated.' 'Green'
    Write-Console 'Next step: re-run with -Preflight against a real target to validate it, then run live.' 'Green'
    Write-Console ''
    exit 0
}

# =============================================================================
# MODE 2 - authenticated read-only preflight. Runs for -Preflight AND before any
#          live mutation. Nothing below mutates.
# =============================================================================

Write-Section 'Preflight - authenticated, read-only'

if (-not (Test-GuidFormat -Value $AzureSubscriptionId)) {
    throw "PREFLIGHT FAILED: -AzureSubscriptionId is missing or not a well-formed GUID (got '$AzureSubscriptionId'). Supply the subscription that will carry the pay-as-you-go charges."
}
if ([string]::IsNullOrWhiteSpace($ResourceGroup)) {
    throw 'PREFLIGHT FAILED: -ResourceGroup is required. Supply the resource group, inside the subscription, that the billing meter attaches to.'
}
if ($scopePlan.TenantWide -and -not $scopePlan.Allowed) {
    throw 'PREFLIGHT FAILED: no -PilotSiteUrl was supplied, which means processing would be enabled tenant-wide. Supply -PilotSiteUrl to scope it to the pilot site, or pass -AcknowledgeTenantWide to accept tenant-wide enablement deliberately.'
}

# --- SharePoint connection -----------------------------------------------------
Write-Console '  Connecting to SharePoint (PnP)...' 'Yellow'
try {
    if ($DeviceLogin) {
        Connect-PnPOnline -Url $TenantAdminUrl -DeviceLogin
    } else {
        Connect-PnPOnline -Url $TenantAdminUrl -Interactive
    }
} catch {
    throw "PREFLIGHT FAILED: could not connect to '$TenantAdminUrl'. Confirm the tenant admin URL and that you hold the SharePoint Administrator or Global Administrator role. Underlying error: $($_.Exception.Message)"
}
Write-Console "  [OK] Connected to $TenantAdminUrl" 'Green'

# --- Azure subscription and resource group -------------------------------------
Write-Console '  Validating the Azure subscription and resource group...' 'Yellow'
if (-not (Get-Command -Name 'Get-AzSubscription' -ErrorAction SilentlyContinue)) {
    throw 'PREFLIGHT FAILED: the Az.Accounts module is not available, so the Azure subscription cannot be validated. Install it with: Install-Module Az.Accounts, Az.Resources -Scope CurrentUser'
}

$azContext = Get-AzContext -ErrorAction SilentlyContinue
if ($null -eq $azContext) {
    Write-Console '  No Azure context found; signing in...' 'Yellow'
    if ($DeviceLogin) {
        Connect-AzAccount -UseDeviceAuthentication | Out-Null
    } else {
        Connect-AzAccount | Out-Null
    }
}

$subscription = Get-AzSubscription -SubscriptionId $AzureSubscriptionId -ErrorAction SilentlyContinue
if ($null -eq $subscription) {
    throw "PREFLIGHT FAILED: Azure subscription '$AzureSubscriptionId' was not found, or the signed-in account cannot see it. Pay-as-you-go requires the subscription to live in the same tenant as Microsoft 365, and the operator to hold Owner or Contributor on it."
}
Write-Console "  [OK] Subscription found: $($subscription.Name)" 'Green'

Set-AzContext -SubscriptionId $AzureSubscriptionId | Out-Null

$rg = Get-AzResourceGroup -Name $ResourceGroup -ErrorAction SilentlyContinue
if ($null -eq $rg) {
    throw "PREFLIGHT FAILED: resource group '$ResourceGroup' does not exist in subscription '$AzureSubscriptionId'. Create it first, or correct -ResourceGroup. Nothing was mutated."
}
Write-Console "  [OK] Resource group found: $($rg.ResourceGroupName) in $($rg.Location)" 'Green'

if (-not [string]::IsNullOrWhiteSpace($Region) -and $rg.Location -ne $Region) {
    Write-Warning "The requested billing region '$Region' does not match the resource group location '$($rg.Location)'. The region decides where tenant ID and usage metadata are stored - confirm this is intended."
}

# --- Operator rights ------------------------------------------------------------
Write-Console '  Checking Azure role assignments on the resource group...' 'Yellow'
try {
    $signInName = if ($null -ne $azContext -and $null -ne $azContext.Account) { $azContext.Account.Id } else { (Get-AzContext).Account.Id }
    $roles = Get-AzRoleAssignment -Scope $rg.ResourceId -SignInName $signInName -ErrorAction SilentlyContinue
    $qualifying = @($roles | Where-Object { $_.RoleDefinitionName -in @('Owner', 'Contributor') })
    if ($qualifying.Count -gt 0) {
        Write-Console "  [OK] Operator holds: $(($qualifying | ForEach-Object { $_.RoleDefinitionName }) -join ', ')" 'Green'
    } else {
        Write-Console '  [MANUAL] No Owner or Contributor assignment was returned for the signed-in account on this resource group.' 'Yellow'
        Write-Console '           This can be an inherited or group-based assignment that the read did not resolve.' 'Yellow'
        Write-Console '           Verify in the Azure portal: Resource group -> Access control (IAM) -> Check access.' 'Yellow'
    }
} catch {
    Write-Console "  [MANUAL] Role assignments could not be read ($($_.Exception.Message)). Verify Owner or Contributor by hand in the Azure portal." 'Yellow'
}

# --- Pilot site -----------------------------------------------------------------
if (-not [string]::IsNullOrWhiteSpace($PilotSiteUrl)) {
    Write-Console '  Validating the pilot site...' 'Yellow'
    $site = Get-PnPTenantSite -Identity $PilotSiteUrl -ErrorAction SilentlyContinue
    if ($null -eq $site) {
        throw "PREFLIGHT FAILED: pilot site '$PilotSiteUrl' was not found in this tenant. Create the site first, or correct -PilotSiteUrl. Nothing was mutated."
    }
    Write-Console "  [OK] Pilot site found: $($site.Url)" 'Green'
}

# --- Current Syntex scope (read-only) -------------------------------------------
$currentScope = $null
$currentSites = @()
if ($capability.Provider -eq 'SPO') {
    Write-Console '  Connecting to the SharePoint Online Management Shell to read the current scope...' 'Yellow'
    try {
        Connect-SPOService -Url $TenantAdminUrl
        $spoTenant = Get-SPOTenant
        if ($spoTenant.PSObject.Properties.Name -contains 'PrebuiltModelScope') {
            $currentScope = [string]$spoTenant.PrebuiltModelScope
        }
        if ($spoTenant.PSObject.Properties.Name -contains 'PrebuiltModelSelectedSitesList' -and $null -ne $spoTenant.PrebuiltModelSelectedSitesList) {
            $currentSites = @($spoTenant.PrebuiltModelSelectedSitesList)
        }
        Write-Console "  [OK] Current prebuilt processing scope: $(if ($currentScope) { $currentScope } else { '<not set>' })" 'Green'
        if ($currentSites.Count -gt 0) {
            Write-Console "       Currently selected sites: $($currentSites -join ', ')"
        }
    } catch {
        Write-Console "  [MANUAL] The current scope could not be read ($($_.Exception.Message)). Check it in the admin center before activating." 'Yellow'
    }
} else {
    Write-Console '  [MANUAL] No scoping cmdlet on this host, so the current scope cannot be read programmatically.' 'Yellow'
}

Write-Console ''
Write-Console 'PREFLIGHT PASSED. Nothing was created, changed or activated.' 'Green'

if ($Preflight) {
    Write-Section 'Manual portal fallback (for reference)'
    Write-BillingPortalFallback -SubscriptionId $AzureSubscriptionId -ResourceGroupName $ResourceGroup -BillingRegion $Region
    Write-Console ''
    Write-Console 'Preflight mode requested; stopping before any mutation.' 'Green'
    Write-Console ''
    exit 0
}

# =============================================================================
# MODE 3 - live run. Everything below can mutate and is ShouldProcess-gated.
# =============================================================================

Write-Section 'Live run - mutating steps'

# --- Step 1: dedicated pilot library --------------------------------------------
if (-not [string]::IsNullOrWhiteSpace($PilotLibraryName)) {
    if ([string]::IsNullOrWhiteSpace($PilotSiteUrl)) {
        throw 'LIVE RUN FAILED: -PilotLibraryName was supplied without -PilotSiteUrl, so there is no site to create the library in.'
    }

    Write-Console "  Step 1: dedicated pilot library '$PilotLibraryName'..." 'Yellow'
    if ($DeviceLogin) {
        Connect-PnPOnline -Url $PilotSiteUrl -DeviceLogin
    } else {
        Connect-PnPOnline -Url $PilotSiteUrl -Interactive
    }

    $existingList = Get-PnPList -Identity $PilotLibraryName -ErrorAction SilentlyContinue
    if ($null -ne $existingList) {
        Write-Console "  [OK] Library '$PilotLibraryName' already exists - left untouched (idempotent no-op)." 'Green'
    } elseif ($PSCmdlet.ShouldProcess($PilotSiteUrl, "Create document library '$PilotLibraryName'")) {
        New-PnPList -Title $PilotLibraryName -Template DocumentLibrary -OnQuickLaunch | Out-Null
        Write-Console "  [OK] Library '$PilotLibraryName' created." 'Green'
    } else {
        Write-Console "  [SKIPPED] Library creation was declined at the confirmation prompt." 'Yellow'
    }

    # Return the connection to the tenant admin scope for the remaining steps.
    if ($DeviceLogin) {
        Connect-PnPOnline -Url $TenantAdminUrl -DeviceLogin
    } else {
        Connect-PnPOnline -Url $TenantAdminUrl -Interactive
    }
} else {
    Write-Console '  Step 1: skipped - no -PilotLibraryName was supplied.' 'Gray'
}

# --- Step 2: pay-as-you-go billing activation (portal only) ----------------------
Write-Console ''
Write-Console '  Step 2: pay-as-you-go billing activation...' 'Yellow'
Write-BillingPortalFallback -SubscriptionId $AzureSubscriptionId -ResourceGroupName $ResourceGroup -BillingRegion $Region

# --- Step 3: processing scope ----------------------------------------------------
Write-Console ''
Write-Console '  Step 3: processing scope...' 'Yellow'

if ($capability.Provider -eq 'PortalOnly') {
    Write-Console '  [MANUAL] No scoping cmdlet is available on this host. Set the scope in the portal Settings tab' 'Yellow'
    Write-Console '           described above, choosing "Selected sites" and adding only the pilot site.' 'Yellow'
    if ($scopePlan.TenantWide -and -not $AcknowledgeTenantWide) {
        throw 'LIVE RUN FAILED: the only available activation surface is tenant-wide and -AcknowledgeTenantWide was not passed. Nothing was activated.'
    }
} elseif (-not $scopePlan.Allowed) {
    throw 'LIVE RUN FAILED: tenant-wide enablement was required but -AcknowledgeTenantWide was not passed. Nothing was activated.'
} else {
    $alreadyScoped = ($currentScope -eq $scopePlan.Scope)
    if ($alreadyScoped -and $scopePlan.Sites.Count -gt 0) {
        foreach ($s in $scopePlan.Sites) {
            if ($currentSites -notcontains $s) { $alreadyScoped = $false }
        }
    }

    if ($alreadyScoped) {
        Write-Console "  [OK] Processing is already scoped to $($scopePlan.Scope) including the requested site(s) - reported, no change made (idempotent no-op)." 'Green'
    } else {
        $target = if ($scopePlan.Sites.Count -gt 0) { $scopePlan.Sites -join ', ' } else { 'the entire tenant' }
        if ($PSCmdlet.ShouldProcess($target, "Set prebuilt document processing scope to $($scopePlan.Scope)")) {
            if ($scopePlan.Sites.Count -gt 0) {
                Set-SPOTenant `
                    -PrebuiltModelScope $scopePlan.Scope `
                    -PrebuiltModelSelectedSitesList $scopePlan.Sites `
                    -PrebuiltModelSelectedSitesListOperation $scopePlan.Operation
            } else {
                Set-SPOTenant -PrebuiltModelScope $scopePlan.Scope
            }
            Write-Console "  [OK] Processing scope set to $($scopePlan.Scope) for: $target" 'Green'
        } else {
            Write-Console '  [SKIPPED] Scope change was declined at the confirmation prompt.' 'Yellow'
        }
    }
}

Write-Console ''
Write-Console 'DONE. Re-run this script at any time - it reports existing state instead of failing.' 'Cyan'
Write-Console 'Verify the result with Test-SyntexSetup.ps1 before uploading any billable document.' 'Cyan'
Write-Console ''
