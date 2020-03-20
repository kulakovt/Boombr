#Requires -Version 5
#Requires -Modules PowerTrello

Set-StrictMode -version Latest
$ErrorActionPreference = 'Stop'

. $PSScriptRoot\Utility.ps1
. $PSScriptRoot\YamlCuteSerialization.ps1

$SiteUrl = 'http://Radio.DotNet.Ru'
$RssUrl = 'https://anchor.fm/s/f0c0ef4/podcast/rss'
$PodcastName = 'RadioDotNet'
$TrelloBoardName = 'RadioDotNet'
$TrelloNewCardListName = 'Обсудили-'

$InformationPreference = 'Continue'

$EpisodeSorter = { @('Number', 'Title', 'PublishDate', 'Authors', 'Mastering', 'Home', 'Audio', 'Topics', 'Subject', 'Links').IndexOf($_) }

function Select-EpisodeNumber
{
    [CmdletBinding()]
    [OutputType([int])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $EpisodeId
    )

    process
    {
        if ($EpisodeId -match '\w+-(?<number>\d+)')
        {
            return [int]$Matches['number']
        }

        throw "Can't extract episode number from «$EpisodeId»"
    }
}

function Format-PodcastHeader
{
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [int] $EpisodeNumber
    )

    process
    {
        @{
            Number = $EpisodeNumber
            Title = "${PodcastName} №${EpisodeNumber}"
            Authors = @('Анатолий Кулаков', 'Игорь Лабутин')
            Mastering = 'Максим Шошин'
        }
    }
}

function Format-PodcastTopic
{
    [CmdletBinding()]
    [OutputType([hashtable])]
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
        # TODO: Import Timestamps
        $subject = $Card.name.Trim()
        Write-Information "- $subject"

        [string[]] $links = $Card.desc -split "`n" |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -match '^https?://' }

        @{
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

function ConvertTo-RssPodcastItem
{
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [Xml.XmlElement] $RssItem
    )

    process
    {
        $title = $RssItem.title.'#cdata-section'.Trim()
        @{
            Number = $title | Select-EpisodeNumber
            Title = $title
            PublishDate = [datetime]$RssItem.pubDate
            Home = $RssItem.link.Trim()
            Audio = $RssItem.enclosure.url.Trim()
            AudioLength = $RssItem.enclosure.length.Trim()
        }
    }
}

function Format-PodcastRssHeader
{
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [hashtable]
        $Podcast
    )

    process
    {
        $rssItem = Invoke-RestMethod -Method Get -Uri $RssUrl |
            ConvertTo-RssPodcastItem |
            Where-Object { $_['Number'] -eq $Podcast['Number'] }

        if (-not $rssItem)
        {
            return
        }

        $Podcast['PublishDate'] = $rssItem['PublishDate']
        $Podcast['Home'] = $rssItem['Home']
        $Podcast['Audio'] = $rssItem['Audio']

        $Podcast
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

function Format-PodcastAnnouncement
{
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [hashtable]
        $Podcast
    )

    process
    {
        "Подкаст $PodcastName, выпуск №$($Podcast['Number'])"
        ''
        if ($Podcast.Contains('Home'))
        {
            $podcast['Home']
            ''
        }
        if ($Podcast.Contains('Description'))
        {
            $Podcast['Description']
            ''
        }
@"
Сайт подкаста:
$SiteUrl

RSS подписка на подкаст:
$RssUrl

Заметки к выпуску:

"@
        $Podcast['Topics'] |
        ForEach-Object {

            $topic = $_

            $timestamp = $topic['Timestamp']
            if ($timestamp)
            {
                '[{0}] {1}' -f $timestamp,$topic['Subject']
            }
            else
            {
                $topic['Subject']
            }

            $topic['Links'] |
            ForEach-Object { "- $_" }
            ''
        }
    }
}

function New-PodcastNoteBase
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    process
    {
        $timer = Start-TimeOperation -Name 'Create podcast show notes base'

        $board = Get-TrelloBoard -Name $TrelloBoardName
        if (-not $board) { throw "Trello board «$TrelloBoardName» not found" }

        $list = $board | Get-TrelloList | Where-Object { $_.name.StartsWith($TrelloNewCardListName) }
        if (-not $list) { throw "Trello list «$TrelloNewCardListName» in board «$TrelloBoardName» not found" }

        $episodeNumber = $list.name | Select-EpisodeNumber
        $filePath = Join-Path -Path $Path ('e{0:D3}.yaml' -f $episodeNumber)

        Write-Information "Scan «$($list.name)» list in «$($board.name)» board for episode №$episodeNumber"

        $podcast = $episodeNumber | Format-PodcastHeader
        $podcast['Topics'] = $board |
             Get-TrelloCard -List $list |
             Format-PodcastTopic

        ConvertTo-CuteYaml -Data $podcast -KeyOrderer $EpisodeSorter |
        Set-Content -Path $filePath -Encoding UTF8

        Format-PodcastAnnouncement -Podcast $podcast |
        Set-Content -Path ([IO.Path]::ChangeExtension($filePath, 'txt')) -Encoding UTF8

        $timer | Stop-TimeOperation
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
        $timer = Start-TimeOperation -Name 'Create podcast show notes'

        $baseFile = Get-Item -Path "${Path}/*" -Filter 'e*.yaml'
        if (-not ($baseFile -is [IO.FileInfo]))
        {
            Write-Warning "Base file not found at $Path"
            return
        }

        $podcast = $baseFile |
            Get-Content -Encoding UTF8 -Raw |
            ConvertFrom-Yaml

        $episodeNumber = $podcast.Number
        Write-Information "Enrich episode №$episodeNumber"
        $filePath = Join-Path -Path $Path ('e{0:D3}.md' -f $episodeNumber)

        if (Test-Path -Path $filePath)
        {
            # TODO: Preserve markdown description
            Write-Warning "Episode notes already exist at $filePath"
            return
        }

        $podcast = Format-PodcastRssHeader -Podcast $Podcast

        if (-not $podcast)
        {
            Write-Warning "Can't found episode №$episodeNumber in RSS feed"
            return
        }

        ConvertTo-CuteYaml -Data $podcast -KeyOrderer $EpisodeSorter |
        ConvertTo-PodcastMarkDowm |
        Set-Content -Path $filePath -Encoding UTF8

        Format-PodcastAnnouncement -Podcast $podcast |
        Set-Content -Path ([IO.Path]::ChangeExtension($filePath, 'txt')) -Encoding UTF8
        Write-Information "Write file $([System.IO.Path]::GetFileName($filePath))"

        $timer | Stop-TimeOperation
    }
}

Get-TrelloConfiguration | Out-Null
$PodcastHome = Join-Path $PSScriptRoot '..\..\Site\input\Radio' -Resolve
$PodcastHome | New-PodcastNoteBase
$PodcastHome | New-PodcastNote
