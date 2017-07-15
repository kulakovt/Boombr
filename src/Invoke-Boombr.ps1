﻿#Requires -Version 5.0

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
        'build wiki'
        {
            . $PSScriptRoot\Wiki.ps1
            Build-Wiki
        }

        'new meetup'
        {
            . $PSScriptRoot\Forms.ps1
            New-Meetup
        }

        default { "Command not found: $Command" }
    }
}


### Main ###

#clear
#$args = @('build', 'wiki')
#$args = @('new', 'meetup')
#$Config.IsOffline = $true

if ($args.Length -lt 2)
{
    if ($args)
    {
        Write-Information "Command not found: $args"
    }
    Write-Information 'Supported commands:'
    Write-Information '- build wiki'
    Write-Information '- new meetup'
    return
}

$command = "$($args[0]) $($args[1])"

Test-BoombrEnvironment

Run-BoombrCommand -Command $command
