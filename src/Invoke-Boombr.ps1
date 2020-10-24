#Requires -Version 5

Set-StrictMode -version Latest
$ErrorActionPreference = 'Stop'

$InformationPreference = 'Continue'
$VerbosePreference = 'SilentlyContinue'
#$DebugPreference = SilentlyContinue
$ProgressPreference = 'SilentlyContinue'

. $PSScriptRoot\Model.ps1
. $PSScriptRoot\Utility.ps1
. $PSScriptRoot\Serialization.ps1


# run, new, publish, test, clean, restore
# add, remove, list

$Config = @{
    RootDir = $PSScriptRoot
    ArtifactsDir = Resolve-FullPath $PSScriptRoot '..\artifacts'
    AuditDir = Resolve-FullPath $PSScriptRoot '..\..\Audit\db'
    BrandBookDir = Resolve-FullPath $PSScriptRoot '..\..\SpbDotNet'
    Inkscape = Resolve-FullPath $PSScriptRoot '..\..\..\inkscape\bin\inkscape.com'
    IsOffline = $false
}

function Test-BoombrEnvironment()
{
    $mode = if ($Config.IsOffline) { 'Offline' } else { 'Online' }
    Write-Information "Start at «$($Config.RootDir)» ($mode mode)"
    Write-Information "Use Artifact directory «$($Config.ArtifactsDir)»"

    if (-not (Test-Path -Path $Config.AuditDir -PathType 'Container'))
    {
        throw "Audit directory is not found at «$($Config.AuditDir)»"
    }

    Write-Information "Found Audit directory at «$($Config.AuditDir)»"

    if (Test-Path -Path $Config.BrandBookDir -PathType 'Container')
    {
        Write-Information "Found BarndBook directory at «$($Config.BrandBookDir)»"
    }
    if (Test-Path -Path $Config.Inkscape -PathType 'Leaf')
    {
        Write-Information "Found Inkscape at «$($Config.Inkscape)»"
    }
}

function Start-BoombrCommand([string] $Command = $(throw 'Command required'))
{
    # GitHub requares TLS 1.2 (https://blog.github.com/2018-02-23-weak-cryptographic-standards-removed/)
    [Net.ServicePointManager]::SecurityProtocol = 'Tls12,Tls11,Tls,Ssl3'

    switch ($Command)
    {
        'build wiki'
        {
            . $PSScriptRoot\Wiki.ps1
            Invoke-BuildWiki
        }

        'build cache'
        {
            . $PSScriptRoot\Wiki.ps1
            Invoke-ReCache
        }

        'rebuild xml'
        {
            Invoke-ReXml
        }

        'new meetup'
        {
            . $PSScriptRoot\Forms.ps1
            New-Meetup
        }

        'export xml'
        {
            . $PSScriptRoot\XmlUtility.ps1
            Export-Xml
        }

        'export images'
        {
            . $PSScriptRoot\ImageUtility.ps1
            Export-Image
        }

        'new announcement'
        {
            . $PSScriptRoot\Announcement.ps1
            Invoke-BuildAnnouncement
        }

        'build brand'
        {
            . $PSScriptRoot\Brand\BrandBook.ps1
            Update-BrandBook
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
    Write-Information '- build cache'
    Write-Information '- rebuild xml'
    Write-Information '- new meetup'
    Write-Information '- export xml'
    Write-Information '- export images'
    Write-Information '- new announcement'
    Write-Information '- build brand'
    return
}

$command = "$($args[0]) $($args[1])"

Test-BoombrEnvironment

Start-BoombrCommand -Command $command
