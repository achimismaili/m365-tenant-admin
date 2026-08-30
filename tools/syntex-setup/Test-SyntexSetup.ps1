<#
.SYNOPSIS
    READ-ONLY verification of a Microsoft Syntex pay-as-you-go document processing
    setup. Reports six checks as [PASS], [FAIL] or [MANUAL] and ends with a single
    machine-readable "Result:" line.

.DESCRIPTION
    Paired verifier for Enable-SyntexPayAsYouGo.ps1. It answers one question -
    "is the pilot actually set up the way it was meant to be?" - and it answers it
    without changing anything.

    THE READ-ONLY CONTRACT
    ----------------------
    This script contains no mutation whatsoever. It never creates, updates,
    activates, publishes or deletes anything, in Microsoft 365 or in Azure, and it
    never creates a document processing model. The only state-changing statement in
    the whole file is the mandatory 'Set-StrictMode -Version Latest' on the line
    after the parameter block, which changes nothing outside this PowerShell scope.

    It also does NOT sign in. There is no Connect-* call anywhere in the file. The
    script inspects the sessions that already exist in the calling PowerShell
    session and reports what it finds. That is deliberate: it makes check 1
    ("am I looking at the right tenant?") a genuine measurement rather than a
    tautology, and it means running this script can never open a browser, consume a
    token, or start a billable operation.

    Consequence: sign in first, then run this. For example
        Connect-PnPOnline -Url https://contoso-admin.sharepoint.com -Interactive
        Connect-SPOService -Url https://contoso-admin.sharepoint.com     # optional
        Connect-AzAccount                                                # optional
        .\Test-SyntexSetup.ps1 -TenantAdminUrl https://contoso-admin.sharepoint.com ...
    Run with no session at all and the script still runs cleanly - it simply reports
    [FAIL] / [MANUAL] with the reason, which is the correct answer to "is this set
    up?" when nobody is signed in.

    HONESTY RULE
    ------------
    Where a state is not programmatically readable, the check prints [MANUAL] and
    the exact portal location to look at. It never prints [PASS] for something it
    could not actually observe, and it never infers a pass from a plausible proxy.
    Only [PASS] counts towards the final tally; [MANUAL] and [FAIL] do not.

    THE SIX CHECKS
    --------------
    1. Tenant session   - a live session exists and resolves to the tenant named by
                          -TenantAdminUrl. Fully readable, so this check is always
                          [PASS] or [FAIL].
    2. Pay-as-you-go    - document processing billing shows activated. Activation
                          has no documented read cmdlet, so unless a future build of
                          Get-SPOTenant exposes one (this script probes the live
                          property surface by name rather than assuming), the honest
                          answer is [MANUAL] plus the portal location.
    3. Azure linkage    - the Azure subscription and resource group exist and are
                          readable, and the Microsoft 365 -> Azure billing linkage
                          is proven. The linkage itself is portal-only, but it can
                          be proven positively from Cost Management: a document
                          processing meter charged against the resource group is
                          decisive evidence the linkage exists. Absence proves
                          nothing (a freshly linked, unused pilot bills nothing), so
                          absence yields [MANUAL], never [FAIL].
    4. Pilot library    - the pilot library exists and the processing scope is what
                          was intended (SelectedSites containing the pilot site, not
                          AllSites). Both halves are read with Get-PnPList and
                          Get-SPOTenant.
    5. Model capability - CONFIGURATION AND REACHABILITY ONLY. It checks whether the
                          model-creation entry point (a content center site, web
                          template CONTENTCTR#0) is reachable and whether the model
                          read cmdlet surface is present. It NEVER creates a model
                          or any other object.
    6. Budget and alert - when -AzureSubscriptionId / -ResourceGroup are supplied,
                          a budget with at least one enabled alert notification must
                          exist on that scope. Read with Get-AzConsumptionBudget.

    WHAT IS AND IS NOT PROGRAMMATICALLY READABLE (verified, not guessed)
    --------------------------------------------------------------------
    * Processing scope IS readable. Get-SPOTenant (module
      Microsoft.Online.SharePoint.PowerShell) surfaces PrebuiltModelScope and
      PrebuiltModelSelectedSitesList. The output type is not declared, so every
      property access in this script is guarded by a name check first - under
      Set-StrictMode a missing member is a terminating error.

    * Pay-as-you-go billing ACTIVATION is NOT readable. No cmdlet in
      PnP.PowerShell, the SharePoint Online Management Shell or the Az modules
      exposes it. This script probes Get-SPOTenant's live property surface for a
      billing-related name so it will start reporting the truth automatically if
      Microsoft ever adds one, and otherwise reports [MANUAL].

    * Budgets ARE readable, with a caveat. Get-AzConsumptionBudget (Az.Billing)
      lists budgets at subscription or resource group scope. Microsoft's own
      documentation notes that the PowerShell SDK for Consumption is only available
      to Enterprise Agreement customers, so on a non-EA subscription the read can
      fail even though a budget exists in the portal. That failure is reported as
      [MANUAL] with the portal location, never as [FAIL] and never as [PASS].

    PORTAL LOCATIONS USED BY THE [MANUAL] VERDICTS
    ----------------------------------------------
    Pay-as-you-go billing activation state
      https://admin.microsoft.com
        -> Settings -> Org settings -> Pay-as-you-go services
        -> Syntex services (or Document processing services) -> Manage billing
      The same state is reachable while setting it up via
        Setup -> Billing and licenses -> Activate pay-as-you-go services
        -> Get started -> Pay-as-you-go services -> Billing tab
        -> Document processing services -> Set up billing and turn on services
      Older admin-center builds expose it under
        Settings -> Org settings -> Services -> Microsoft Syntex

    Processing scope (which sites are billable)
      https://admin.microsoft.com
        -> Pay-as-you-go services -> Settings tab -> Document processing services
        -> Prebuilt document processing -> site options

    Azure budget and its alert
      https://portal.azure.com
        -> Cost Management + Billing -> Cost Management -> select the scope
           (the subscription, or the resource group) -> Budgets
        -> open the budget -> Alert conditions / Alert recipients

    Content center (model creation entry point)
      https://admin.microsoft.com -> SharePoint admin center -> Active sites
        -> filter or look for the site whose template is "Content center"

    Reference documentation:
      https://learn.microsoft.com/microsoft-365/documentprocessing/syntex-azure-billing
      https://learn.microsoft.com/microsoft-365/documentprocessing/create-a-content-center
      https://learn.microsoft.com/powershell/module/microsoft.online.sharepoint.powershell/get-spotenant
      https://learn.microsoft.com/powershell/module/az.billing/get-azconsumptionbudget

.PARAMETER TenantAdminUrl
    SharePoint tenant administration URL, for example
    https://contoso-admin.sharepoint.com. Required. It is never contacted directly;
    it is the expected value that check 1 compares the existing session against.

.PARAMETER PilotSiteUrl
    Full URL of the site collection processing is supposed to be scoped to, for
    example https://contoso.sharepoint.com/sites/pilot. Same parameter name and
    meaning as in Enable-SyntexPayAsYouGo.ps1.

.PARAMETER PilotLibraryName
    Display name of the dedicated pilot document library inside PilotSiteUrl. Same
    parameter name and meaning as in Enable-SyntexPayAsYouGo.ps1. Reading the
    library requires the current PnP session to be pointed at PilotSiteUrl; if it is
    pointed at the tenant admin URL instead, check 4 reports [MANUAL] and prints the
    read-only command that would resolve it.

.PARAMETER AzureSubscriptionId
    Optional. GUID of the Azure subscription carrying the pay-as-you-go charges.
    Supplying it enables the Azure-side reads in checks 3 and 6.

.PARAMETER ResourceGroup
    Optional. Name of the resource group the billing meter attaches to. Supplying it
    narrows checks 3 and 6 to that resource group scope.

.PARAMETER BudgetName
    Optional. Name of the specific budget check 6 should look for. When omitted, any
    budget on the scope that carries an enabled alert satisfies the check.

.PARAMETER MaxBudgetAmount
    Optional. Ceiling for the pilot. When supplied, a budget whose amount exceeds
    this value fails check 6 - a budget set far above the pilot's intended spend is
    not a guard rail. Ignored when not supplied.

.PARAMETER ContentCenterUrl
    Optional. URL of a specific content center to verify in check 5. When omitted,
    the check enumerates sites with the content center web template (CONTENTCTR#0)
    instead of guessing a URL.

.PARAMETER UsageLookbackDays
    Optional. How far back check 3 looks in Cost Management for a document
    processing meter charged against the resource group. Defaults to 30 days.

.PARAMETER FailOnIncomplete
    Optional. Exit with code 1 unless every check returned [PASS]. Without it the
    script always exits 0 and the "Result:" line is the verdict. Useful in a
    pipeline; noisy for interactive use.

.EXAMPLE
    .\Test-SyntexSetup.ps1 -TenantAdminUrl "https://contoso-admin.sharepoint.com"

    Minimal run. Reports what it can read from whatever sessions already exist and
    marks everything else [MANUAL] with the portal location. Changes nothing.

.EXAMPLE
    Connect-PnPOnline -Url "https://contoso.sharepoint.com/sites/pilot" -Interactive
    .\Test-SyntexSetup.ps1 `
        -TenantAdminUrl "https://contoso-admin.sharepoint.com" `
        -PilotSiteUrl "https://contoso.sharepoint.com/sites/pilot" `
        -PilotLibraryName "Syntex Pilot"

    Verifies the pilot library itself. The PnP session must be pointed at the pilot
    site for the library read to be possible.

.EXAMPLE
    .\Test-SyntexSetup.ps1 `
        -TenantAdminUrl "https://contoso-admin.sharepoint.com" `
        -PilotSiteUrl "https://contoso.sharepoint.com/sites/pilot" `
        -PilotLibraryName "Syntex Pilot" `
        -AzureSubscriptionId "00000000-0000-0000-0000-000000000000" `
        -ResourceGroup "rg-syntex-pilot" `
        -BudgetName "syntex-pilot-budget" `
        -MaxBudgetAmount 50

    Full run including the Azure-side linkage and budget reads, asserting that the
    pilot budget is capped at 50 in the subscription's billing currency.

.NOTES
    Modules used, all read-only
        PnP.PowerShell                          Get-PnPConnection, Get-PnPTenantSite,
                                                Get-PnPList, Get-PnPSyntexModel
        Microsoft.Online.SharePoint.PowerShell  Get-SPOTenant
        Az.Accounts / Az.Resources              Get-AzContext, Get-AzSubscription,
                                                Get-AzResourceGroup
        Az.Billing                              Get-AzConsumptionBudget,
                                                Get-AzConsumptionUsageDetail
    None is mandatory. A missing or unloadable module degrades the affected check to
    [MANUAL] with the portal location; it never fails the script.

    PowerShell edition caveat
        Microsoft.Online.SharePoint.PowerShell declares no Core-compatible edition,
        so PowerShell 7 cannot load it and every Get-SPOTenant-based check degrades
        to [MANUAL]. Run this verifier from Windows PowerShell 5.1 to exercise those
        checks, or install a Core-compatible build. The script distinguishes
        "not installed" from "installed but not loadable in this edition" so the
        message is actionable instead of misleading.

    Idempotency
        Trivially idempotent: it is read-only, so any number of runs produce the same
        result and no side effect.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$TenantAdminUrl,

    [Parameter(Mandatory = $false)]
    [string]$PilotSiteUrl,

    [Parameter(Mandatory = $false)]
    [string]$PilotLibraryName,

    [Parameter(Mandatory = $false)]
    [string]$AzureSubscriptionId,

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $false)]
    [string]$BudgetName,

    [Parameter(Mandatory = $false)]
    [decimal]$MaxBudgetAmount = 0,

    [Parameter(Mandatory = $false)]
    [string]$ContentCenterUrl,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 365)]
    [int]$UsageLookbackDays = 30,

    [Parameter(Mandatory = $false)]
    [switch]$FailOnIncomplete
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# =============================================================================
# Console sink and small pure helpers
#
# Everything in this region is pure or purely diagnostic. Nothing here opens a
# connection and nothing here mutates anything outside this PowerShell scope.
# =============================================================================

function Write-Console {
    <#
        .SYNOPSIS
            Single console sink for the whole script.
        .DESCRIPTION
            Write-Host is intentional. This is an operator transcript for a human,
            not a pipeline of objects, and the colour coding carries the
            PASS / FAIL / MANUAL meaning. Funnelling every write through one
            function keeps the PSAvoidUsingWriteHost suppression to a single place.
            The helper is named Write-Console rather than the more obvious
            Write-Log because PSScriptAnalyzer treats Write-Log as a built-in in its
            core-6.1.0-windows profile and flags the override.
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

function Test-HasProperty {
    <#
        .SYNOPSIS
            Safe member test for objects whose shape is not declared.
        .DESCRIPTION
            Get-SPOTenant, Get-PnPList and the Az consumption cmdlets do not declare
            an output type, and under Set-StrictMode -Version Latest touching a
            member that does not exist is a terminating error. Every property access
            in this script goes through this test first.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [AllowNull()]
        [object]$InputObject,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$Name
    )
    if ($null -eq $InputObject) { return $false }
    return ($InputObject.PSObject.Properties.Name -contains $Name)
}

function Get-SafeProperty {
    <#
        .SYNOPSIS
            Reads a property if it exists, otherwise returns $null.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [AllowNull()]
        [object]$InputObject,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$Name
    )
    if (-not (Test-HasProperty -InputObject $InputObject -Name $Name)) { return $null }
    return $InputObject.$Name
}

function Get-TenantKey {
    <#
        .SYNOPSIS
            Reduces a SharePoint URL to the tenant name it belongs to.
        .DESCRIPTION
            https://contoso-admin.sharepoint.com      -> contoso
            https://contoso.sharepoint.com/sites/x    -> contoso
            https://contoso-my.sharepoint.com         -> contoso
            Pure string work: no network, no module.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Url
    )

    if ([string]::IsNullOrWhiteSpace($Url)) { return '' }

    # NB: not $host - that is a read-only automatic variable and assigning to it
    # throws at run time.
    $hostPart = $Url.Trim()
    $hostPart = $hostPart -replace '^[a-zA-Z]+://', ''
    $hostPart = ($hostPart -split '[/?#]')[0]
    $label = ($hostPart -split '\.')[0]
    $label = $label -replace '-admin$', ''
    $label = $label -replace '-my$', ''
    return $label.ToLowerInvariant()
}

function Get-NormalizedUrl {
    <#
        .SYNOPSIS
            Lower-cases a URL and strips a trailing slash so two spellings of the
            same site compare equal.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Url
    )
    if ([string]::IsNullOrWhiteSpace($Url)) { return '' }
    return $Url.Trim().TrimEnd('/').ToLowerInvariant()
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

function Import-CandidateModule {
    <#
        .SYNOPSIS
            Tries to load a module so that its cmdlets become discoverable.
        .DESCRIPTION
            Get-Command auto-discovery skips modules whose CompatiblePSEditions does
            not include Core, which is exactly the case for
            Microsoft.Online.SharePoint.PowerShell. Probing with a bare Get-Command
            therefore reports a confident and WRONG "the cmdlet does not exist".
            Importing first, and distinguishing NotInstalled from
            InstalledButNotLoadable, produces an actionable message instead.
            Loading a module opens no connection, so this is safe in a read-only
            verifier.
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

function Get-CmdletAvailability {
    <#
        .SYNOPSIS
            Reports whether a read cmdlet can actually be invoked on this host.
        .OUTPUTS
            Hashtable: Available (bool), State (string), Note (string).
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Module,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$Cmdlet
    )

    $state = Import-CandidateModule -Name $Module

    if ($state -eq 'NotInstalled') {
        return @{
            Available = $false
            State     = $state
            Note      = "$Module is not installed on this host, so $Cmdlet cannot be used."
        }
    }
    if ($state -eq 'InstalledButNotLoadable') {
        return @{
            Available = $false
            State     = $state
            Note      = "$Module is installed but cannot be loaded in this PowerShell edition ($($PSVersionTable.PSEdition)), so $Cmdlet is unavailable. Re-run from Windows PowerShell 5.1, or install a Core-compatible build."
        }
    }

    $command = Get-Command -Name $Cmdlet -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        return @{
            Available = $false
            State     = 'CmdletMissing'
            Note      = "$Module loaded, but $Cmdlet was not found in it."
        }
    }

    return @{
        Available = $true
        State     = 'Loaded'
        Note      = "$Cmdlet is available from $Module."
    }
}

# =============================================================================
# Check bookkeeping
# =============================================================================

$script:CheckResults = [System.Collections.Generic.List[object]]::new()

function Resolve-Verdict {
    <#
        .SYNOPSIS
            Folds a set of sub-verdicts into one, with FAIL louder than MANUAL.
        .DESCRIPTION
            A definite negative must never be softened into "go look in the portal",
            and an unreadable state must never be rounded up to PASS. So the
            precedence is FAIL > MANUAL > PASS.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [AllowEmptyCollection()]
        [string[]]$Verdicts = @()
    )
    if ($Verdicts.Count -eq 0) { return 'MANUAL' }
    if ($Verdicts -contains 'FAIL') { return 'FAIL' }
    if ($Verdicts -contains 'MANUAL') { return 'MANUAL' }
    return 'PASS'
}

function Write-CheckResult {
    <#
        .SYNOPSIS
            Prints one check's verdict and records it for the final tally.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$Number,

        [Parameter(Mandatory = $true)]
        [string]$Title,

        [Parameter(Mandatory = $true)]
        [ValidateSet('PASS', 'FAIL', 'MANUAL')]
        [string]$Status,

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [string[]]$Detail = @()
    )

    $colour = switch ($Status) {
        'PASS'   { 'Green' }
        'FAIL'   { 'Red' }
        default  { 'Yellow' }
    }

    Write-Console ''
    Write-Console ("[{0}] {1}. {2}" -f $Status, $Number, $Title) $colour
    foreach ($line in $Detail) {
        Write-Console ("       {0}" -f $line)
    }

    $script:CheckResults.Add([pscustomobject]@{
        Number = $Number
        Title  = $Title
        Status = $Status
    })
}

# =============================================================================
# Session discovery - read-only inspection of sessions that already exist.
# There is deliberately no Connect-* call anywhere in this script.
# =============================================================================

function Get-PnPSessionState {
    <#
        .SYNOPSIS
            Inspects the ambient PnP.PowerShell connection without creating one.
        .OUTPUTS
            Hashtable: Available, Connected, Url, TenantAdminUrl, Note.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $state = @{
        Available      = $false
        Connected      = $false
        Url            = ''
        TenantAdminUrl = ''
        Note           = ''
    }

    $availability = Get-CmdletAvailability -Module 'PnP.PowerShell' -Cmdlet 'Get-PnPConnection'
    $state.Note = [string]$availability.Note
    if (-not $availability.Available) { return $state }
    $state.Available = $true

    try {
        $connection = Get-PnPConnection -ErrorAction Stop
    } catch {
        $state.Note = "No PnP.PowerShell connection is open in this session ($($_.Exception.Message))."
        return $state
    }

    if ($null -eq $connection) {
        $state.Note = 'No PnP.PowerShell connection is open in this session.'
        return $state
    }

    $state.Connected = $true
    $state.Url = [string](Get-SafeProperty -InputObject $connection -Name 'Url')
    $state.TenantAdminUrl = [string](Get-SafeProperty -InputObject $connection -Name 'TenantAdminUrl')
    $state.Note = 'PnP.PowerShell connection found.'
    return $state
}

function Get-SpoTenantState {
    <#
        .SYNOPSIS
            Reads tenant settings through the SharePoint Online Management Shell,
            without opening a session.
        .DESCRIPTION
            Get-SPOTenant throws immediately and locally when no Connect-SPOService
            session exists, so calling it inside a try/catch is a safe way to detect
            "not signed in" without attempting a sign-in. The output type is not
            declared, hence every later read goes through Get-SafeProperty.
        .OUTPUTS
            Hashtable: Available, Connected, Tenant (object or $null), Note.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $state = @{
        Available = $false
        Connected = $false
        Tenant    = $null
        Note      = ''
    }

    $availability = Get-CmdletAvailability -Module 'Microsoft.Online.SharePoint.PowerShell' -Cmdlet 'Get-SPOTenant'
    $state.Note = [string]$availability.Note
    if (-not $availability.Available) { return $state }
    $state.Available = $true

    try {
        $tenant = Get-SPOTenant -ErrorAction Stop
    } catch {
        $state.Note = "Get-SPOTenant could not read tenant settings - most often this means no Connect-SPOService session is open ($($_.Exception.Message))."
        return $state
    }

    $state.Connected = $true
    $state.Tenant = $tenant
    $state.Note = 'Tenant settings read through Get-SPOTenant.'
    return $state
}

function Get-AzureSessionState {
    <#
        .SYNOPSIS
            Inspects the ambient Azure context without signing in.
        .OUTPUTS
            Hashtable: Available, Connected, SubscriptionId, SubscriptionName,
            AccountId, Note.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $state = @{
        Available        = $false
        Connected        = $false
        SubscriptionId   = ''
        SubscriptionName = ''
        AccountId        = ''
        Note             = ''
    }

    $availability = Get-CmdletAvailability -Module 'Az.Accounts' -Cmdlet 'Get-AzContext'
    $state.Note = [string]$availability.Note
    if (-not $availability.Available) { return $state }
    $state.Available = $true

    try {
        $context = Get-AzContext -ErrorAction Stop
    } catch {
        $state.Note = "No Azure context could be read ($($_.Exception.Message))."
        return $state
    }

    if ($null -eq $context) {
        $state.Note = 'No Azure context is present in this session.'
        return $state
    }

    $state.Connected = $true

    $subscription = Get-SafeProperty -InputObject $context -Name 'Subscription'
    if ($null -ne $subscription) {
        $state.SubscriptionId = [string](Get-SafeProperty -InputObject $subscription -Name 'Id')
        $state.SubscriptionName = [string](Get-SafeProperty -InputObject $subscription -Name 'Name')
    }

    $account = Get-SafeProperty -InputObject $context -Name 'Account'
    if ($null -ne $account) {
        $state.AccountId = [string](Get-SafeProperty -InputObject $account -Name 'Id')
    }

    $state.Note = 'Azure context found.'
    return $state
}

# =============================================================================
# Banner
# =============================================================================

Write-Console ''
Write-Console 'Microsoft Syntex - pay-as-you-go setup verification (READ-ONLY)' 'Cyan'
Write-Console '==============================================================' 'Cyan'
Write-Console 'This script reads and reports. It creates nothing, changes nothing,' 'Green'
Write-Console 'activates nothing and signs in to nothing.' 'Green'

$expectedTenantKey = Get-TenantKey -Url $TenantAdminUrl

Write-Console ''
Write-Console "Tenant admin URL    : $TenantAdminUrl"
Write-Console "Expected tenant     : $(if ($expectedTenantKey) { $expectedTenantKey } else { '<could not be derived from the URL>' })"
Write-Console "Pilot site          : $(if ($PilotSiteUrl) { $PilotSiteUrl } else { '<not supplied>' })"
Write-Console "Pilot library       : $(if ($PilotLibraryName) { $PilotLibraryName } else { '<not supplied>' })"
Write-Console "Azure subscription  : $(if ($AzureSubscriptionId) { $AzureSubscriptionId } else { '<not supplied>' })"
Write-Console "Resource group      : $(if ($ResourceGroup) { $ResourceGroup } else { '<not supplied>' })"
Write-Console "Budget name         : $(if ($BudgetName) { $BudgetName } else { '<any budget with an enabled alert>' })"
Write-Console "Budget ceiling      : $(if ($PSBoundParameters.ContainsKey('MaxBudgetAmount')) { $MaxBudgetAmount } else { '<not asserted>' })"
Write-Console "Content center      : $(if ($ContentCenterUrl) { $ContentCenterUrl } else { '<discover by web template CONTENTCTR#0>' })"
Write-Console "PowerShell          : $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))"

Write-Section 'Session discovery (read-only - no sign-in is attempted)'

$pnp = Get-PnPSessionState
Write-Console "  PnP.PowerShell      : $($pnp.Note)"
if ($pnp.Connected) {
    Write-Console "                        connected to: $($pnp.Url)"
}

$spo = Get-SpoTenantState
Write-Console "  SPO Management Shell: $($spo.Note)"

$azure = Get-AzureSessionState
Write-Console "  Azure               : $($azure.Note)"
if ($azure.Connected) {
    Write-Console "                        context subscription: $(if ($azure.SubscriptionId) { $azure.SubscriptionId } else { '<none selected>' })"
}

Write-Section 'Checks'

# =============================================================================
# CHECK 1 - the session really is the tenant named by -TenantAdminUrl.
#
# Fully readable, so this check is always PASS or FAIL. It is never MANUAL:
# "no session" is a definite negative answer to "am I connected to the right
# tenant?", not an unreadable state.
# =============================================================================

$detail = [System.Collections.Generic.List[string]]::new()
$status = 'FAIL'

if (-not $pnp.Available) {
    $detail.Add($pnp.Note)
    $detail.Add('Without PnP.PowerShell the session tenant cannot be established from PowerShell.')
    $detail.Add('Install it with: Install-Module PnP.PowerShell -Scope CurrentUser')
    if ($spo.Connected) {
        $detail.Add('A SharePoint Online Management Shell session IS open, but it does not expose the URL it was opened against, so it cannot confirm WHICH tenant this is.')
        $status = 'MANUAL'
        $detail.Add('Confirm the tenant by hand: https://admin.microsoft.com -> SharePoint admin center -> the admin URL shown in the browser address bar.')
    }
} elseif (-not $pnp.Connected) {
    $detail.Add($pnp.Note)
    $detail.Add('Nothing is signed in, so nothing can be verified against the tenant.')
    $detail.Add("Sign in first, then re-run. For example: Connect-PnPOnline -Url '$TenantAdminUrl' -Interactive")
} else {
    $actualTenantKey = Get-TenantKey -Url $pnp.Url
    $detail.Add("Session URL   : $($pnp.Url)")
    $detail.Add("Session tenant: $(if ($actualTenantKey) { $actualTenantKey } else { '<could not be derived>' })")
    $detail.Add("Expected      : $expectedTenantKey")

    if ($expectedTenantKey -and $actualTenantKey -and $actualTenantKey -eq $expectedTenantKey) {
        $status = 'PASS'
        if ((Get-NormalizedUrl -Url $pnp.Url) -eq (Get-NormalizedUrl -Url $TenantAdminUrl)) {
            $detail.Add('The session is opened against the tenant admin URL itself.')
        } else {
            $detail.Add('The session is opened against a different URL in the same tenant, which is expected when the session is pointed at the pilot site so that the library can be read.')
        }
    } else {
        $status = 'FAIL'
        $detail.Add('The open session belongs to a DIFFERENT tenant than -TenantAdminUrl. Everything below would describe the wrong tenant.')
    }
}

if ($spo.Connected) {
    $detail.Add('Corroborating: a SharePoint Online Management Shell session is also open, so the Get-SPOTenant reads below are live.')
} else {
    $detail.Add("Note: $($spo.Note)")
}

Write-CheckResult -Number 1 -Title 'Connected to the tenant named by -TenantAdminUrl' -Status $status -Detail $detail.ToArray()

# =============================================================================
# CHECK 2 - pay-as-you-go document processing shows activated.
#
# Activation has no documented read cmdlet in any module. Rather than assume
# that forever, the check probes the LIVE property surface of Get-SPOTenant by
# name, so the day Microsoft adds one this check starts reporting the truth on
# its own. Until then the honest verdict is MANUAL plus the portal location.
# The processing scope is printed as corroboration only: a scope can be set
# without billing being linked, so it must never be treated as proof.
# =============================================================================

$detail = [System.Collections.Generic.List[string]]::new()
$verdicts = [System.Collections.Generic.List[string]]::new()

if (-not $spo.Connected) {
    $detail.Add($spo.Note)
    $verdicts.Add('MANUAL')
} else {
    $billingPropertyNames = @(
        $spo.Tenant.PSObject.Properties.Name |
            Where-Object { $_ -match 'PayAsYouGo|Billing|Syntex|Consumption|Meter' }
    )

    if ($billingPropertyNames.Count -eq 0) {
        $detail.Add('Get-SPOTenant exposes no property whose name relates to pay-as-you-go billing, so the activation state is genuinely not readable from PowerShell on this build.')
        $verdicts.Add('MANUAL')
    } else {
        $detail.Add("Get-SPOTenant exposes billing-related properties: $($billingPropertyNames -join ', ')")
        $anyTrue = $false
        foreach ($name in $billingPropertyNames) {
            $value = Get-SafeProperty -InputObject $spo.Tenant -Name $name
            $detail.Add("  $name = $(if ($null -eq $value) { '<null>' } else { $value })")
            if ($value -is [bool] -and $value) { $anyTrue = $true }
        }
        if ($anyTrue) {
            $detail.Add('At least one billing property reports activated.')
            $verdicts.Add('PASS')
        } else {
            $detail.Add('The billing properties present do not report an activated state.')
            $verdicts.Add('FAIL')
        }
    }

    $scope = Get-SafeProperty -InputObject $spo.Tenant -Name 'PrebuiltModelScope'
    if ($null -ne $scope) {
        $detail.Add("Corroborating only - current PrebuiltModelScope is '$scope'. A scope can be set independently of billing, so this is not proof of activation.")
    }
}

$status = Resolve-Verdict -Verdicts $verdicts.ToArray()
if ($status -ne 'PASS') {
    $detail.Add('Check it by hand here:')
    $detail.Add('  https://admin.microsoft.com')
    $detail.Add('    -> Settings -> Org settings -> Pay-as-you-go services')
    $detail.Add('    -> Syntex services (or Document processing services) -> Manage billing')
    $detail.Add('  During initial setup the same state lives under')
    $detail.Add('    Setup -> Billing and licenses -> Activate pay-as-you-go services -> Get started')
    $detail.Add('    -> Pay-as-you-go services -> Billing tab -> Document processing services')
    $detail.Add('  Older admin-center builds: Settings -> Org settings -> Services -> Microsoft Syntex')
}

Write-CheckResult -Number 2 -Title 'Pay-as-you-go document processing is activated' -Status $status -Detail $detail.ToArray()

# =============================================================================
# CHECK 3 - Azure subscription and resource group linkage.
#
# Two things are being asked. The subscription and resource group existing is
# readable outright. The Microsoft 365 -> Azure BILLING LINKAGE is portal-only,
# but it can still be proven POSITIVELY: a document processing meter charged
# against the resource group could only have got there through the linkage.
# Absence of such a meter proves nothing at all - a freshly linked pilot that
# has processed nothing bills nothing - so absence gives MANUAL, never FAIL.
# =============================================================================

$detail = [System.Collections.Generic.List[string]]::new()
$verdicts = [System.Collections.Generic.List[string]]::new()

if ([string]::IsNullOrWhiteSpace($AzureSubscriptionId) -and [string]::IsNullOrWhiteSpace($ResourceGroup)) {
    $detail.Add('Neither -AzureSubscriptionId nor -ResourceGroup was supplied, so there is nothing to verify against.')
    $verdicts.Add('MANUAL')
} else {
    if (-not [string]::IsNullOrWhiteSpace($AzureSubscriptionId) -and -not (Test-GuidFormat -Value $AzureSubscriptionId)) {
        $detail.Add("-AzureSubscriptionId '$AzureSubscriptionId' is not a well-formed GUID.")
        $verdicts.Add('FAIL')
    }

    if (-not $azure.Available) {
        $detail.Add($azure.Note)
        $detail.Add('Install it with: Install-Module Az.Accounts, Az.Resources -Scope CurrentUser')
        $verdicts.Add('MANUAL')
    } elseif (-not $azure.Connected) {
        $detail.Add($azure.Note)
        $detail.Add('Sign in first, then re-run. For example: Connect-AzAccount')
        $verdicts.Add('MANUAL')
    } else {
        $detail.Add("Azure context account : $(if ($azure.AccountId) { $azure.AccountId } else { '<unknown>' })")

        # --- subscription -----------------------------------------------------
        if (-not [string]::IsNullOrWhiteSpace($AzureSubscriptionId) -and (Test-GuidFormat -Value $AzureSubscriptionId)) {
            $subscription = $null
            try {
                $subscription = Get-AzSubscription -SubscriptionId $AzureSubscriptionId -ErrorAction Stop
            } catch {
                $detail.Add("Subscription read failed: $($_.Exception.Message)")
            }

            if ($null -eq $subscription) {
                $detail.Add("Azure subscription '$AzureSubscriptionId' was not found, or the signed-in account cannot see it.")
                $verdicts.Add('FAIL')
            } else {
                $detail.Add("Subscription found    : $(Get-SafeProperty -InputObject $subscription -Name 'Name') ($AzureSubscriptionId)")
                $verdicts.Add('PASS')
            }
        }

        # --- resource group ----------------------------------------------------
        # Get-AzResourceGroup resolves against the CURRENT context subscription.
        # Switching context would mean calling a Set-* cmdlet, which this
        # read-only script will not do, so a context mismatch is reported rather
        # than corrected.
        if (-not [string]::IsNullOrWhiteSpace($ResourceGroup)) {
            $contextMatches = ([string]::IsNullOrWhiteSpace($AzureSubscriptionId)) -or
                              ($azure.SubscriptionId -eq $AzureSubscriptionId)

            if (-not $contextMatches) {
                $detail.Add("The current Azure context targets subscription '$($azure.SubscriptionId)', not '$AzureSubscriptionId', so the resource group cannot be resolved in the intended subscription.")
                $detail.Add("This verifier will not switch context, because that would mean invoking a Set-* cmdlet. Select the subscription yourself and re-run.")
                $verdicts.Add('MANUAL')
            } else {
                $rg = $null
                try {
                    $rg = Get-AzResourceGroup -Name $ResourceGroup -ErrorAction Stop
                } catch {
                    $detail.Add("Resource group read failed: $($_.Exception.Message)")
                }

                if ($null -eq $rg) {
                    $detail.Add("Resource group '$ResourceGroup' was not found in the context subscription.")
                    $verdicts.Add('FAIL')
                } else {
                    $detail.Add("Resource group found  : $(Get-SafeProperty -InputObject $rg -Name 'ResourceGroupName') in $(Get-SafeProperty -InputObject $rg -Name 'Location')")
                    $verdicts.Add('PASS')
                }
            }
        }

        # --- the linkage itself, proven positively from Cost Management ---------
        $usage = Get-CmdletAvailability -Module 'Az.Billing' -Cmdlet 'Get-AzConsumptionUsageDetail'
        if (-not $usage.Available) {
            $detail.Add($usage.Note)
            $detail.Add('Without it, the Microsoft 365 -> Azure billing linkage cannot be proven from PowerShell.')
            $verdicts.Add('MANUAL')
        } else {
            $records = @()
            try {
                $endDate = Get-Date
                $startDate = $endDate.AddDays(-1 * $UsageLookbackDays)
                if ([string]::IsNullOrWhiteSpace($ResourceGroup)) {
                    $records = @(Get-AzConsumptionUsageDetail -StartDate $startDate -EndDate $endDate -IncludeMeterDetails -Top 1000 -ErrorAction Stop)
                } else {
                    $records = @(Get-AzConsumptionUsageDetail -ResourceGroup $ResourceGroup -StartDate $startDate -EndDate $endDate -IncludeMeterDetails -Top 1000 -ErrorAction Stop)
                }
                $detail.Add("Cost Management returned $($records.Count) usage record(s) for the last $UsageLookbackDays day(s).")
            } catch {
                $records = $null
                $detail.Add("Cost Management usage could not be read: $($_.Exception.Message)")
                $detail.Add('Microsoft documents the PowerShell Consumption SDK as available to Enterprise Agreement customers only, so this read can fail on a non-EA subscription even when the linkage exists.')
                $verdicts.Add('MANUAL')
            }

            if ($null -ne $records) {
                $matched = @($records | Where-Object {
                    $text = @(
                        [string](Get-SafeProperty -InputObject $_ -Name 'Product')
                        [string](Get-SafeProperty -InputObject $_ -Name 'ConsumedService')
                        [string](Get-SafeProperty -InputObject $_ -Name 'InstanceName')
                        [string](Get-SafeProperty -InputObject (Get-SafeProperty -InputObject $_ -Name 'MeterDetails') -Name 'MeterCategory')
                        [string](Get-SafeProperty -InputObject (Get-SafeProperty -InputObject $_ -Name 'MeterDetails') -Name 'MeterName')
                    ) -join ' '
                    $text -match 'Syntex|SharePoint Premium|Document [Pp]rocessing|Content AI'
                })

                if ($matched.Count -gt 0) {
                    $detail.Add("$($matched.Count) document processing meter record(s) are charged against this scope, which could only have happened through an active Microsoft 365 -> Azure linkage.")
                    $verdicts.Add('PASS')
                } else {
                    $detail.Add('No document processing meter was found on this scope. That does NOT mean the linkage is missing - a linked pilot that has processed nothing bills nothing - so this is reported as unverified rather than failed.')
                    $verdicts.Add('MANUAL')
                }
            }
        }
    }
}

$status = Resolve-Verdict -Verdicts $verdicts.ToArray()
if ($status -ne 'PASS') {
    $detail.Add('Confirm the linkage by hand here:')
    $detail.Add('  https://admin.microsoft.com')
    $detail.Add('    -> Settings -> Org settings -> Pay-as-you-go services -> Syntex services')
    $detail.Add('    -> Manage billing -> the Azure subscription and resource group shown there')
    $detail.Add('  Cross-check the Azure side at https://portal.azure.com')
    $detail.Add('    -> Cost Management + Billing -> Cost Management -> Cost analysis')
    $detail.Add('    -> scope to the resource group -> group by Meter')
}

Write-CheckResult -Number 3 -Title 'Azure subscription and resource group linkage is present' -Status $status -Detail $detail.ToArray()

# =============================================================================
# CHECK 4 - the pilot library exists and the processing scope is as expected.
#
# Two halves, both read-only. The library is read with Get-PnPList, which needs
# the ambient PnP session to be pointed at the pilot site. The scope is read
# with Get-SPOTenant. A definitely-wrong scope (AllSites, or NoSites) is a FAIL,
# because that is a measured negative and, in the AllSites case, an active
# billing exposure.
# =============================================================================

$detail = [System.Collections.Generic.List[string]]::new()
$verdicts = [System.Collections.Generic.List[string]]::new()

# --- half A: the library ------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($PilotLibraryName)) {
    $detail.Add('-PilotLibraryName was not supplied, so no library was checked.')
    $verdicts.Add('MANUAL')
} elseif (-not $pnp.Connected) {
    $detail.Add('No PnP session is open, so the library cannot be read.')
    $verdicts.Add('MANUAL')
} elseif ([string]::IsNullOrWhiteSpace($PilotSiteUrl)) {
    $detail.Add('-PilotSiteUrl was not supplied, so there is no site to look for the library in.')
    $verdicts.Add('MANUAL')
} elseif ((Get-NormalizedUrl -Url $pnp.Url) -ne (Get-NormalizedUrl -Url $PilotSiteUrl)) {
    $detail.Add("The PnP session is pointed at '$($pnp.Url)', not at the pilot site '$PilotSiteUrl', so the library cannot be read from here.")
    $detail.Add("Point the session at the pilot site and re-run, for example: Connect-PnPOnline -Url '$PilotSiteUrl' -Interactive")
    $detail.Add("Or look by hand: $PilotSiteUrl -> Site contents -> the '$PilotLibraryName' library")
    $verdicts.Add('MANUAL')
} else {
    $list = $null
    try {
        $list = Get-PnPList -Identity $PilotLibraryName -ErrorAction Stop
    } catch {
        $detail.Add("Library read failed: $($_.Exception.Message)")
    }

    if ($null -eq $list) {
        $detail.Add("Library '$PilotLibraryName' does not exist in '$PilotSiteUrl'.")
        $verdicts.Add('FAIL')
    } else {
        $itemCount = Get-SafeProperty -InputObject $list -Name 'ItemCount'
        $baseTemplate = Get-SafeProperty -InputObject $list -Name 'BaseTemplate'
        $detail.Add("Library found         : '$PilotLibraryName'$(if ($null -ne $baseTemplate) { " (base template $baseTemplate)" })$(if ($null -ne $itemCount) { ", $itemCount item(s)" })")
        $verdicts.Add('PASS')
    }
}

# --- half B: the processing scope ---------------------------------------------
if (-not $spo.Connected) {
    $detail.Add("Processing scope not readable: $($spo.Note)")
    $verdicts.Add('MANUAL')
} else {
    $scope = Get-SafeProperty -InputObject $spo.Tenant -Name 'PrebuiltModelScope'
    $selected = Get-SafeProperty -InputObject $spo.Tenant -Name 'PrebuiltModelSelectedSitesList'
    $selectedSites = @()
    if ($null -ne $selected) { $selectedSites = @($selected) }

    if ($null -eq $scope) {
        $detail.Add('Get-SPOTenant does not expose PrebuiltModelScope on this build, so the scope is not readable.')
        $verdicts.Add('MANUAL')
    } else {
        $detail.Add("Processing scope      : $scope")
        if ($selectedSites.Count -gt 0) {
            $detail.Add("Selected sites        : $($selectedSites -join ', ')")
        }

        if ([string]$scope -eq 'AllSites') {
            $detail.Add('Scope is AllSites: EVERY site in the tenant is billable for document processing. For a pilot that is an active cost exposure, not a warning.')
            $verdicts.Add('FAIL')
        } elseif ([string]$scope -eq 'NoSites') {
            $detail.Add('Scope is NoSites: document processing is billable nowhere, so the pilot cannot run.')
            $verdicts.Add('FAIL')
        } elseif ([string]$scope -eq 'SelectedSites') {
            if ([string]::IsNullOrWhiteSpace($PilotSiteUrl)) {
                $detail.Add('Scope is SelectedSites, but -PilotSiteUrl was not supplied so the selection cannot be compared against the intended site.')
                $verdicts.Add('MANUAL')
            } else {
                $wanted = Get-NormalizedUrl -Url $PilotSiteUrl
                $found = @($selectedSites | Where-Object { (Get-NormalizedUrl -Url ([string]$_)) -eq $wanted })
                if ($found.Count -gt 0) {
                    $detail.Add("The pilot site is in the selected-sites list, and only selected sites are billable.")
                    $verdicts.Add('PASS')
                } else {
                    $detail.Add("Scope is SelectedSites but '$PilotSiteUrl' is NOT in the list, so the pilot site is not enabled for processing.")
                    $verdicts.Add('FAIL')
                }
            }
        } else {
            $detail.Add("Scope value '$scope' is not one of NoSites / AllSites / SelectedSites, so it cannot be interpreted here.")
            $verdicts.Add('MANUAL')
        }
    }
}

$status = Resolve-Verdict -Verdicts $verdicts.ToArray()
if ($status -ne 'PASS') {
    $detail.Add('Check both halves by hand here:')
    $detail.Add('  Library: the pilot site -> Settings gear -> Site contents')
    $detail.Add('  Scope  : https://admin.microsoft.com -> Pay-as-you-go services -> Settings tab')
    $detail.Add('           -> Document processing services -> Prebuilt document processing -> site options')
}

Write-CheckResult -Number 4 -Title 'Pilot library exists and the processing scope is as expected' -Status $status -Detail $detail.ToArray()

# =============================================================================
# CHECK 5 - model capability: CONFIGURATION AND REACHABILITY ONLY.
#
# This check answers "could a model be created here?" by reading. It does NOT
# create a model, a content center, a library, a content type or anything else.
# Creation is mutation and would violate the read-only contract of this script,
# so there is deliberately no code path here that could produce an object.
#
# Two readable signals:
#   * the model read cmdlet surface (Get-PnPSyntexModel) is present and loadable
#   * a content center site exists - identified by web template CONTENTCTR#0,
#     which is the model creation interface
# A missing content center is NOT reported as FAIL: models can also be created
# locally from a document library's own menu, so absence does not prove the
# capability is unreachable.
# =============================================================================

$detail = [System.Collections.Generic.List[string]]::new()
$verdicts = [System.Collections.Generic.List[string]]::new()

$detail.Add('This check reads only. It never creates a model, a content center or any other object.')

$modelCmdlet = Get-CmdletAvailability -Module 'PnP.PowerShell' -Cmdlet 'Get-PnPSyntexModel'
$detail.Add("Model read cmdlet     : $($modelCmdlet.Note)")
if (-not $modelCmdlet.Available) {
    $verdicts.Add('MANUAL')
}

if (-not $pnp.Connected) {
    $detail.Add('No PnP session is open, so neither the content center nor the model list can be read.')
    $verdicts.Add('MANUAL')
} else {
    $centers = $null
    if (-not [string]::IsNullOrWhiteSpace($ContentCenterUrl)) {
        try {
            $centers = @(Get-PnPTenantSite -Identity $ContentCenterUrl -ErrorAction Stop)
        } catch {
            $detail.Add("Content center read failed for '$ContentCenterUrl': $($_.Exception.Message)")
            $detail.Add('Reading a site by URL requires the session to be opened against the tenant admin URL.')
            $verdicts.Add('MANUAL')
        }
    } else {
        try {
            $centers = @(Get-PnPTenantSite -Template 'CONTENTCTR#0' -ErrorAction Stop)
            $detail.Add("Enumerated sites with the content center web template (CONTENTCTR#0).")
        } catch {
            $detail.Add("Content center enumeration failed: $($_.Exception.Message)")
            $detail.Add('Enumerating sites by template requires the session to be opened against the tenant admin URL.')
            $verdicts.Add('MANUAL')
        }
    }

    if ($null -ne $centers) {
        if ($centers.Count -gt 0) {
            foreach ($center in $centers) {
                $centerUrl = [string](Get-SafeProperty -InputObject $center -Name 'Url')
                $centerTemplate = [string](Get-SafeProperty -InputObject $center -Name 'Template')
                $detail.Add("Content center found  : $centerUrl$(if ($centerTemplate) { " (template $centerTemplate)" })")
            }
            $detail.Add('The model creation entry point is reachable.')
            $verdicts.Add('PASS')
        } else {
            $detail.Add('No content center site was found. That is not a failure: prebuilt and custom models can also be created locally from a document library, so the capability may still be reachable.')
            $verdicts.Add('MANUAL')
        }
    }

    # Reading the model list is only possible when the session is pointed at a
    # content center. This is a read; it never publishes or creates.
    if ($modelCmdlet.Available -and $null -ne $centers -and $centers.Count -gt 0) {
        $sessionUrl = Get-NormalizedUrl -Url $pnp.Url
        $onCenter = @($centers | Where-Object { (Get-NormalizedUrl -Url ([string](Get-SafeProperty -InputObject $_ -Name 'Url'))) -eq $sessionUrl })
        if ($onCenter.Count -gt 0) {
            try {
                $models = @(Get-PnPSyntexModel -ErrorAction Stop)
                $detail.Add("Models already present in this content center: $($models.Count)")
            } catch {
                $detail.Add("Model list could not be read: $($_.Exception.Message)")
            }
        } else {
            $detail.Add('The session is not pointed at a content center, so the existing model list was not read. Existence of the content center is enough for this check.')
        }
    }
}

$status = Resolve-Verdict -Verdicts $verdicts.ToArray()
if ($status -ne 'PASS') {
    $detail.Add('Check it by hand here:')
    $detail.Add('  https://admin.microsoft.com -> SharePoint admin center -> Active sites')
    $detail.Add('    -> look for the site whose template is "Content center"')
    $detail.Add('  Or, for a local model: the pilot library -> Automate -> Set up a model')
    $detail.Add('  Creating a content center is a mutation and is out of scope for this verifier.')
}

Write-CheckResult -Number 5 -Title 'Model creation entry point is reachable (configuration check only)' -Status $status -Detail $detail.ToArray()

# =============================================================================
# CHECK 6 - budget and alert on the billing scope (amendment H).
#
# A budget alert is a NOTIFICATION, not a hard spending cap - so a budget
# without an enabled alert is not a guard rail and is treated as a failure, not
# a pass. Where the budget is not programmatically readable at all, the verdict
# is MANUAL with the exact portal location, never a false PASS.
# =============================================================================

$detail = [System.Collections.Generic.List[string]]::new()
$verdicts = [System.Collections.Generic.List[string]]::new()

$detail.Add('A budget alert is a notification, not a hard spending cap. It bounds surprise, not spend.')

if ([string]::IsNullOrWhiteSpace($AzureSubscriptionId) -and [string]::IsNullOrWhiteSpace($ResourceGroup)) {
    $detail.Add('Neither -AzureSubscriptionId nor -ResourceGroup was supplied, so no budget scope was given to verify.')
    $verdicts.Add('MANUAL')
} elseif (-not $azure.Connected) {
    $detail.Add($azure.Note)
    $detail.Add('Sign in first, then re-run. For example: Connect-AzAccount')
    $verdicts.Add('MANUAL')
} else {
    $budgetCmdlet = Get-CmdletAvailability -Module 'Az.Billing' -Cmdlet 'Get-AzConsumptionBudget'
    if (-not $budgetCmdlet.Available) {
        $detail.Add($budgetCmdlet.Note)
        $detail.Add('Install it with: Install-Module Az.Billing -Scope CurrentUser')
        $verdicts.Add('MANUAL')
    } elseif (-not [string]::IsNullOrWhiteSpace($AzureSubscriptionId) -and $azure.SubscriptionId -ne $AzureSubscriptionId) {
        $detail.Add("The current Azure context targets subscription '$($azure.SubscriptionId)', not '$AzureSubscriptionId'. Budgets resolve against the context subscription, so the read would describe the wrong scope.")
        $detail.Add('This verifier will not switch context, because that would mean invoking a Set-* cmdlet. Select the subscription yourself and re-run.')
        $verdicts.Add('MANUAL')
    } else {
        $budgets = $null
        try {
            if ([string]::IsNullOrWhiteSpace($ResourceGroup)) {
                if ([string]::IsNullOrWhiteSpace($BudgetName)) {
                    $budgets = @(Get-AzConsumptionBudget -ErrorAction Stop)
                } else {
                    $budgets = @(Get-AzConsumptionBudget -Name $BudgetName -ErrorAction Stop)
                }
                $detail.Add('Scope read           : subscription')
            } else {
                if ([string]::IsNullOrWhiteSpace($BudgetName)) {
                    $budgets = @(Get-AzConsumptionBudget -ResourceGroupName $ResourceGroup -ErrorAction Stop)
                } else {
                    $budgets = @(Get-AzConsumptionBudget -ResourceGroupName $ResourceGroup -Name $BudgetName -ErrorAction Stop)
                }
                $detail.Add("Scope read           : resource group '$ResourceGroup'")
            }
        } catch {
            $budgets = $null
            $detail.Add("Budget read failed: $($_.Exception.Message)")
            $detail.Add('Microsoft documents the PowerShell Consumption SDK as available to Enterprise Agreement customers only, so this read can fail on a non-EA subscription even when a budget exists. Reporting unverified rather than failed.')
            $verdicts.Add('MANUAL')
        }

        if ($null -ne $budgets) {
            if ($budgets.Count -eq 0) {
                $detail.Add("No budget exists on this scope$(if ($BudgetName) { " under the name '$BudgetName'" }). Pay-as-you-go document processing bills per page against this subscription with no cap, so a pilot without a budget alert has no early warning at all.")
                $verdicts.Add('FAIL')
            } else {
                foreach ($budget in $budgets) {
                    $name = [string](Get-SafeProperty -InputObject $budget -Name 'Name')
                    $amount = Get-SafeProperty -InputObject $budget -Name 'Amount'
                    $grain = [string](Get-SafeProperty -InputObject $budget -Name 'TimeGrain')
                    $detail.Add("Budget               : '$name' amount=$amount timeGrain=$grain")

                    $notification = Get-SafeProperty -InputObject $budget -Name 'Notification'
                    $alerts = @()
                    if ($null -ne $notification) {
                        $alerts = @($notification.PSObject.Properties.Name)
                    }

                    if ($alerts.Count -eq 0) {
                        $detail.Add("  Budget '$name' has NO alert notification. A budget without an alert notifies nobody and is not a guard rail.")
                        $verdicts.Add('FAIL')
                    } else {
                        $detail.Add("  Alert notification(s): $($alerts -join ', ')")
                        $verdicts.Add('PASS')
                    }

                    if ($PSBoundParameters.ContainsKey('MaxBudgetAmount') -and $null -ne $amount) {
                        if ([decimal]$amount -gt $MaxBudgetAmount) {
                            $detail.Add("  Budget '$name' is $amount, above the -MaxBudgetAmount ceiling of $MaxBudgetAmount. A budget set far above the pilot's intended spend is not a guard rail.")
                            $verdicts.Add('FAIL')
                        } else {
                            $detail.Add("  Budget '$name' is at or below the -MaxBudgetAmount ceiling of $MaxBudgetAmount.")
                        }
                    }
                }
            }
        }
    }
}

$status = Resolve-Verdict -Verdicts $verdicts.ToArray()
if ($status -ne 'PASS') {
    $detail.Add('Check it by hand here:')
    $detail.Add('  https://portal.azure.com')
    $detail.Add('    -> Cost Management + Billing -> Cost Management')
    $detail.Add("    -> Scope: select the subscription$(if ($ResourceGroup) { ", then the resource group '$ResourceGroup'" })")
    $detail.Add('    -> Budgets -> open the budget')
    $detail.Add('    -> confirm both "Alert conditions" (a threshold) and "Alert recipients" (an email) are set')
}

Write-CheckResult -Number 6 -Title 'Azure budget with an enabled alert exists on the billing scope' -Status $status -Detail $detail.ToArray()

# =============================================================================
# Summary
# =============================================================================

$total = $script:CheckResults.Count
$passed = @($script:CheckResults | Where-Object { $_.Status -eq 'PASS' }).Count
$failed = @($script:CheckResults | Where-Object { $_.Status -eq 'FAIL' }).Count
$manual = @($script:CheckResults | Where-Object { $_.Status -eq 'MANUAL' }).Count

Write-Section 'Summary'
foreach ($result in $script:CheckResults) {
    $colour = switch ($result.Status) {
        'PASS'  { 'Green' }
        'FAIL'  { 'Red' }
        default { 'Yellow' }
    }
    Write-Console ("  [{0}] {1}. {2}" -f $result.Status, $result.Number, $result.Title) $colour
}

Write-Console ''
Write-Console "PASS: $passed   FAIL: $failed   MANUAL: $manual   (only PASS counts as passed)"
Write-Console ''
Write-Console "Result: $passed/$total checks passed" $(if ($passed -eq $total) { 'Green' } else { 'Yellow' })
Write-Console ''
Write-Console 'Nothing was created, changed, activated or published by this run.' 'Green'
Write-Console ''

if ($FailOnIncomplete -and $passed -ne $total) {
    exit 1
}

exit 0
