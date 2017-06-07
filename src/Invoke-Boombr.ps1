#Requires -Version 5.0

clear

Set-StrictMode -version Latest
$ErrorActionPreference = 'Stop'

$InformationPreference = 'Continue'
$VerbosePreference = 'SilentlyContinue'
#$DebugPreference = SilentlyContinue

. $PSScriptRoot\Model.ps1
. $PSScriptRoot\Utility.ps1
. $PSScriptRoot\Serialization.ps1


# run, new, publish, test, clean, restore
# add, remove, list

# build wiki
# new meetup

$Config = @{
    RootDir = $PSScriptRoot
    ArtifactsDir = Resolve-FullPath $PSScriptRoot '..\artifacts'
    AuditDir = Resolve-FullPath $PSScriptRoot '..\..\Audit\db'
    IsOffline = $false
}

function Test-BoombrEnvironment()
{
    $mode = if ($Config.IsOffline) { 'Offline' } else { 'Online' }
    Write-Information "Start at «$($Config.RootDir)» ($mode mode)"
    Write-Information "Use Artifact directory «$($Config.ArtifactsDir )»"

    if (-not (Test-Path -Path $Config.AuditDir))
    {
        throw "Audit directory is not found at «$($Config.AuditDir)»"
    }
}

function Run-BoombrCommand([string] $Command = $(throw 'Command required'))
{
    switch ($Command)
    {
        'build wiki' { Build-Wiki }
        'new meetup' { New-Meetup }
        default { "Command not found: $Command" }
    }
}


### Main ###

$args = @('new', 'meetup')
$Config.IsOffline = $true

. $PSScriptRoot\Wiki.ps1
. $PSScriptRoot\Forms.ps1

if ($args.Length -lt 2)
{
    Write-Information "Command not found: $args"
    Write-Information 'Supported commands:'
    Write-Information '- build wiki'
    Write-Information '- new meetup'
    return
}

$command = "$($args[0]) $($args[1])"

Test-BoombrEnvironment

Run-BoombrCommand -Command $command

