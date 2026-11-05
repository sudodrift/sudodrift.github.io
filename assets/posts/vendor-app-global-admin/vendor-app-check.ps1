<#
  vendor-app-check.ps1  (sudodrift)

  READ-ONLY: this script only reads. It makes no changes. Try it in a test tenant first.
  Not yet tested against a live tenant.

  Lists four things in a Microsoft 365 / Entra tenant:
    1. ConnectWise / SkyKick service principals and whether they are enabled
    2. Every service principal (app) that holds a directory role
    3. Secrets and certificates added to apps or service principals since a date
    4. Audit events where an APP (not a person) added a role member or a credential

  It asks Microsoft Graph for read scopes only and uses only Get-Mg* cmdlets.
  Needs the Microsoft.Graph PowerShell SDK:
    Install-Module Microsoft.Graph.Authentication, Microsoft.Graph.Applications,
                   Microsoft.Graph.Identity.Governance, Microsoft.Graph.Reports -Scope CurrentUser

  Run:  ./vendor-app-check.ps1 -Since 2026-10-13

  Source and write-up: https://sudodrift.github.io/posts/vendor-app-global-admin/
#>
param(
    [datetime]$Since = '2026-10-13'
)

$ErrorActionPreference = 'Stop'

Connect-MgGraph -NoWelcome -Scopes @(
    'Application.Read.All',
    'RoleManagement.Read.Directory',
    'AuditLog.Read.All'
)

# App IDs published by Huntress and ConnectWise for this incident.
$vendorApps = [ordered]@{
    '506e08f9-6e9a-4da4-942b-a099a03644ae' = 'ConnectWise Cloud Backup (SkyKick)'
    '2399d300-6fca-4e6a-a686-399fefe75b83' = 'ConnectWise Cloud Management'
    '24205314-2b89-4e07-a2a4-579e898a5640' = 'ConnectWise Cloud Management - MS Teams'
    'b78f6a77-d4e5-46fb-87e5-d1648bd02519' = 'ConnectWise Cloud Management - Exchange Online'
    '0de14c77-b9b0-4137-9360-34878a929827' = 'ConnectWise Cloud Management - MS Graph'
    '412dcf96-176d-4b3a-a1b0-4981ad66971e' = 'ConnectWise Cloud Management - Partner Center'
    'b2b55f5b-7758-4719-8d8f-88ae172e6bdb' = 'ConnectWise Cloud Management - SharePoint Online'
}

Write-Host "`n== 1. ConnectWise / SkyKick apps in this tenant ==" -ForegroundColor Cyan
foreach ($appId in $vendorApps.Keys) {
    $sp = Get-MgServicePrincipal -Filter "appId eq '$appId'" -Property 'id,displayName,accountEnabled,appId'
    if ($sp) {
        $state = if ($sp.AccountEnabled) { 'ENABLED' } else { 'disabled' }
        '{0,-9} {1}  objectId={2}' -f $state, $sp.DisplayName, $sp.Id
    }
}

Write-Host "`n== 2. Apps holding directory roles ==" -ForegroundColor Cyan
$roleNames = @{}
Get-MgRoleManagementDirectoryRoleDefinition -All -Property 'id,displayName' |
    ForEach-Object { $roleNames[$_.Id] = $_.DisplayName }

Get-MgRoleManagementDirectoryRoleAssignment -All -ExpandProperty 'principal' |
    Where-Object { $_.Principal.AdditionalProperties['@odata.type'] -eq '#microsoft.graph.servicePrincipal' } |
    ForEach-Object {
        [pscustomobject]@{
            Role  = $roleNames[$_.RoleDefinitionId]
            App   = $_.Principal.AdditionalProperties['displayName']
            AppId = $_.Principal.AdditionalProperties['appId']
            Scope = $_.DirectoryScopeId
        }
    } | Sort-Object Role, App | Format-Table -AutoSize

Write-Host "`n== 3. Secrets and certificates added since $($Since.ToString('yyyy-MM-dd')) ==" -ForegroundColor Cyan
$props = 'id,appId,displayName,passwordCredentials,keyCredentials'
$objects = @()
$objects += Get-MgApplication -All -Property $props | ForEach-Object { $_ | Add-Member -NotePropertyName Kind -NotePropertyValue 'app registration' -PassThru }
$objects += Get-MgServicePrincipal -All -Property $props | ForEach-Object { $_ | Add-Member -NotePropertyName Kind -NotePropertyValue 'service principal' -PassThru }

$objects | ForEach-Object {
    $o = $_
    foreach ($c in @($o.PasswordCredentials)) {
        if ($c -and $c.StartDateTime -ge $Since) {
            [pscustomobject]@{ Added = $c.StartDateTime; Type = 'secret'; Expires = $c.EndDateTime; Name = $o.DisplayName; Kind = $o.Kind; AppId = $o.AppId }
        }
    }
    foreach ($c in @($o.KeyCredentials)) {
        if ($c -and $c.StartDateTime -ge $Since) {
            [pscustomobject]@{ Added = $c.StartDateTime; Type = 'certificate'; Expires = $c.EndDateTime; Name = $o.DisplayName; Kind = $o.Kind; AppId = $o.AppId }
        }
    }
} | Sort-Object Added | Format-Table -AutoSize

Write-Host "`n== 4. Audit events started by an app, not a person ==" -ForegroundColor Cyan
Write-Host "(Free tenants keep 7 days of audit log, P1/P2 keep 30. Older events are gone.)"
$sinceUtc = $Since.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$wanted = @('Add member to role', 'Add service principal credentials', 'Update application', 'Add owner to application', 'Add owner to service principal')
$rows = foreach ($name in $wanted) {
    Get-MgAuditLogDirectoryAudit -All -Filter "activityDateTime ge $sinceUtc and activityDisplayName eq '$name'" |
        Where-Object { $_.InitiatedBy.App.AppId } |
        ForEach-Object {
            [pscustomobject]@{
                When      = $_.ActivityDateTime
                Activity  = $_.ActivityDisplayName
                ByApp     = $_.InitiatedBy.App.DisplayName
                Target    = ($_.TargetResources | ForEach-Object { $_.DisplayName }) -join ', '
                Result    = $_.Result
                UserAgent = ($_.AdditionalDetails | Where-Object Key -eq 'User-Agent').Value
            }
        }
}
$rows | Sort-Object When | Format-Table -AutoSize -Wrap

Write-Host "`nDone. Nothing was changed. Compare every line above against something you can explain." -ForegroundColor Green
