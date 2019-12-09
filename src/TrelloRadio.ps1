﻿#Requires -Version 5
#Requires -Modules PowerTrello

Set-StrictMode -version Latest
$ErrorActionPreference = 'Stop'

. $PSScriptRoot\Utility.ps1

$TrelloBoardName = 'RadioDotNet'
$TrelloNewCardListName = 'Обсудили-'

$InformationPreference = 'Continue'

function Format-CardShowNote
{
    [CmdletBinding()]
    [OutputType([String])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [object] $Card
    )

    begin
    {
        $topicCount = 0
        $linkCount = 0
    }
    process
    {
        Write-Information "- $($Card.name)"

        $desc = $Card.desc -replace "`n","`r`n"
@"
$($Card.name)
$desc

"@

        $topicCount++
        $linkCount += ($desc -split 'https?://').Count - 1
    }
    end
    {
        Write-Information "Found: $topicCount topics, $linkCount links"
    }
}

function Format-ShowNoteHeader
{
    [CmdletBinding()]
    [OutputType([String])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [int] $EpisodeNumber
    )

    process
    {
        Write-Information "Format header for episode №«$EpisodeNumber"

@"
Подкаст RadioDotNet, выпуск №$EpisodeNumber

https://anchor.fm/radiodotnet/episodes/RadioDotNet-$($EpisodeNumber.ToString("000")) <--------!!! Fix the link

Сайт подкаста:
http://Radio.DotNet.Ru

RSS подписка на подкаст:
https://anchor.fm/s/f0c0ef4/podcast/rss

Заметки к выпуску:

"@
    }
}

function Select-EpisodeNumber
{
    [CmdletBinding()]
    [OutputType([int])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $ListName
    )

    process
    {
        if ($ListName -match '\w+-(?<number>\d+)')
        {
            return $Matches['number']
        }

        throw "Can't extract episode number from «$ListName»"
    }
}

function New-ShowNote
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    process
    {
        $timer = Start-TimeOperation -Name 'Resolve show notes'

        $board = Get-TrelloBoard -Name $TrelloBoardName
        if (-not $board) { throw "Trello board «$TrelloBoardName» not found" }

        $list = $board | Get-TrelloList | Where-Object { $_.name.StartsWith($TrelloNewCardListName) }
        if (-not $list) { throw "Trello list «$TrelloNewCardListName» in board «$TrelloBoardName» not found" }

        Write-Information "Scan «$($list.name)» list in «$($board.name)» board"

        $list.name |
            Select-EpisodeNumber |
            Format-ShowNoteHeader |
            Set-Content -Path $Path -Encoding UTF8

        $board |
            Get-TrelloCard -List $list |
            Format-CardShowNote |
            Add-Content -Path $Path -Encoding UTF8

        $timer | Stop-TimeOperation
    }
}

Get-TrelloConfiguration
'C:\Users\akulakov\Desktop\RadioDotNet\e004\Notes.txt' | New-ShowNote
