#Requires -Version 5
#Requires -Modules PowerTrello

Set-StrictMode -version Latest
$ErrorActionPreference = 'Stop'

. $PSScriptRoot\Utility.ps1
. $PSScriptRoot\YamlCuteSerialization.ps1

$PodcastName = 'RadioDotNet'
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
            return [int]$Matches['number']
        }

        throw "Can't extract episode number from «$ListName»"
    }
}

function Format-PodcastHeader
{
    [CmdletBinding()]
    #[OutputType([ordered])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [int] $EpisodeNumber
    )

    process
    {
        [ordered]@{
            Number = $EpisodeNumber
            Title = "${PodcastName} №${EpisodeNumber}"
            PublishDate = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ', [Globalization.CultureInfo]::InvariantCulture)
            Authors = @('Анатолий Кулаков', 'Игорь Лабутин')
            Mastering = 'Максим Шошин'
            # TODO: Update from RSS
            # PublishDate
            # Home: https://anchor.fm/radiodotnet/episodes/RadioDotNet-005-eatsfn
            # Audio: https://anchor.fm/s/f0c0ef4/podcast/play/10465207/https%3A%2F%2Fd3ctxlq1ktw2nl.cloudfront.net%2Fproduction%2F2020-1-18%2F50774460-44100-2-9ba7f03739b75.mp3
        }
    }
}

function Format-PodcastTopic
{
    [CmdletBinding()]
    #[OutputType([ordered])]
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
        $subject = $Card.name.Trim()
        Write-Information "- $subject"

        [string[]] $links = $Card.desc -split "`n" |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -match '^https?://' }

        [ordered]@{
            Subject = $subject
            Links = $links
        }

        $topicCount++
        $linkCount += $links.Count
    }
    end
    {
        Write-Information "Found: $topicCount topics, $linkCount links"
    }
}

function ConvertTo-PodcastMarkDowm
{
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(ValueFromPipeline)]
        [string] $Yaml
    )

    begin
    {
        '---'
    }
    process
    {
        $Yaml
    }
    end
    {
        '---'
    }
}

function New-PodcastNote
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    process
    {
        $timer = Start-TimeOperation -Name 'Format podcast show notes'

        $board = Get-TrelloBoard -Name $TrelloBoardName
        if (-not $board) { throw "Trello board «$TrelloBoardName» not found" }

        $list = $board | Get-TrelloList | Where-Object { $_.name.StartsWith($TrelloNewCardListName) }
        if (-not $list) { throw "Trello list «$TrelloNewCardListName» in board «$TrelloBoardName» not found" }

        $episodeNumber = $list.name | Select-EpisodeNumber
        $filePath = Join-Path -Path $Path ('e{0:D3}.md' -f $episodeNumber)

        if (Test-Path -Path $filePath)
        {
            Write-Warning "Episode notes already exists at $filePath"
            return
        }

        Write-Information "Scan «$($list.name)» list in «$($board.name)» board for episode №$episodeNumber"

        $podcast = $episodeNumber | Format-PodcastHeader
        $podcast['Topics'] = $board |
             Get-TrelloCard -List $list |
             Format-PodcastTopic

        ConvertTo-CuteYaml -Data $podcast |
        ConvertTo-PodcastMarkDowm |
        Set-Content -Path $filePath -Encoding UTF8

        $timer | Stop-TimeOperation
    }
}

Get-TrelloConfiguration | Out-Null
Join-Path $PSScriptRoot '..\..\Site\input\Radio' -Resolve | New-PodcastNote
