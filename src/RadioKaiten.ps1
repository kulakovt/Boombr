. $PSScriptRoot\Utility.ps1

$KaitenApiEndpoint = 'https://dotnetru.kaiten.ru/api/v1'

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
            Title = "RadioDotNet №${EpisodeNumber}"
            Authors = @('Анатолий Кулаков', 'Игорь Лабутин')
            Mastering = 'Игорь Лабутин' # 'Максим Шошин'
            Music = @{ 'Максим Аршинов «Pensive yeti.0.1»' = 'https://hightech.group/ru/about' }
            Patrons = @(
                'Александр', 'Сергей', 'Владислав', 'Гурий Самарин', 'Александр Лапердин', 'Виктор',
                'Руслан Артамонов', 'Сергей Бензенко', 'Шевченко Антон',
                'Ольга Бондаренко', 'Сергей Краснов', 'Константин Ушаков', 'Постарнаков Андрей', 'Дмитрий Сорокин',
                'Дмитрий Павлов', 'Александр Ерыгин', 'Егор Сычёв', 'Гольдебаев Александр', 'Лазарев Илья',
                'Тимофей', 'Виталий'
            )
        }
    }
}

function Select-EpisodeNumber
{
    [CmdletBinding()]
    [OutputType([int])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $EpisodeTitle
    )

    process
    {
        if ($EpisodeTitle -match '\w+-(?<number>\d+)')
        {
            return [int]$Matches['number']
        }

        throw "Can't extract episode number from «$EpisodeId»"
    }
}

function Get-LinksFromMarkDown()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $Description
    )

    process
    {
        $Description -split "`n" |
        ForEach-Object {

            $line = $_.Trim()
            if ($line -match '\[(?<Link>https?://[^\]]+)')
            {
                $Matches['Link']
            }
            elseif ($line -match '^https?://')
            {
                $line
            }
        }
    }
}

function Invoke-KaitenMethod
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Resource,

        [Hashtable]
        $QueryParts = @{}
    )

    process
    {
        $token = 'KaitenBearerToken' | Get-Secret
        $headers = @{
            Authorization = "Bearer ${token}"
            Accept = 'application/json'
            'Content-Type' = 'application/json'
        }

        $resourceWithQuery = $Resource
        $query = $QueryParts | Format-UriQuery
        if ($query)
        {
            $resourceWithQuery += "?${query}"
        }

        $url = $KaitenApiEndpoint | Join-Uri -RelativeUri $resourceWithQuery

        Invoke-RestMethod $url -Headers $headers
    }
}

function New-KaitenTopic
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
        $subject = $Card.title.Trim()
        Write-Information "- $subject"

        [string[]] $links = $Card.description | Get-LinksFromMarkDown

        $timestamp = '00:00:00'
        if ($PodcastTimestamps)
        {
            $timestamp = $PodcastTimestamps[$topicCount]
        }

        @{
            Subject = $subject
            Timestamp = $timestamp
            Links = $links
        }

        $topicCount++
        $linkCount += $links.Count
    }
    end
    {
        if ($PodcastTimestamps)
        {
            if ($PodcastTimestamps.Length -ne $topicCount)
            {
                Write-Error "Podcast timestamps count mismatch"
            }
        }
        Write-Information "Found: $topicCount topics, $linkCount links"
    }
}

function New-KaitenPodcast
{
    [CmdletBinding()]
    param ()

    process
    {
        # https://developers.kaiten.ru/
        $column =
            'spaces' |
            Invoke-KaitenMethod | Select-Many |
            Where-Object { $_.title -eq 'RadioDotNet' } |
            ForEach-Object { "spaces/$($_.id)/boards" } |
            Invoke-KaitenMethod | Select-Many |
            Where-Object { $_.title -eq 'RadioDotNet' } |
            ForEach-Object { "boards/$($_.id)/columns" } |
            Invoke-KaitenMethod | Select-Many |
            Where-Object { $_.title -like 'Обсуждаем-*' } |
            Select-Single

        $episodeNumber = $column.title | Select-EpisodeNumber
        Write-Information "Scan «$($column.title)» column for episode №$episodeNumber"

        $podcast = $episodeNumber | Format-PodcastHeader

        $cardsQuery = @{
            column_id = $column.id
            additional_card_fields = 'description'
        }
        $podcast['Topics'] = 'cards' |
             Invoke-KaitenMethod -QueryParts $cardsQuery | Select-Many |
             Sort-Object 'sort_order' |
             New-KaitenTopic

        $podcast
    }
}
