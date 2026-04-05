$ArtifactRepository = @{
    Communities = @{}
    Meetups = @{}
    Talks = @{}
    Speakers = @{}
}

function Format-Meetup()
{
    process
    {
        $meetup = [Meetup]$_

        $meetupName = $meetup.Name -replace 'Встреча ',''

        $meetup.Sessions | Format-Session -MeetupName $meetupName
    }
}

function Format-Session([string] $MeetupName)
{
    process
    {
        $session = [Session]$_

        "Доступны материалы со встречи $MeetupName"
        ''

        $talk = $ArtifactRepository.Talks[$session.TalkId]
        $talk.SpeakerIds |
            ForEach-Object { $ArtifactRepository.Speakers[$_] } |
            ForEach-Object { $_.Name } |
            Join-ToString -Delimeter ', '
        "«$($talk.Title)»"
        ''

        if ($talk.VideoUrl)
        {
            "Видео: $($talk.VideoUrl)"
        }

        if ($talk.SlidesUrl)
        {
            "Слайды: $($talk.SlidesUrl)"
        }

        if ($talk.CodeUrl)
        {
            "Код: $($talk.CodeUrl)"
        }

        ''
        '---'
        ''
    }
}

function Invoke-BuildArtifact()
{
    $timer = Start-TimeOperation -Name 'Build Artifacts'

    # Load All
    $entities = Read-All -AuditDir $Config.AuditDir

    $ArtifactRepository.Communities = $entities | Where-Object { $_ -is [Community] } | ConvertTo-Hashtable { $_.Id }
    $ArtifactRepository.Meetups = $entities | Where-Object { $_ -is [Meetup] } | ConvertTo-Hashtable { $_.Id }
    $ArtifactRepository.Talks  = $entities | Where-Object { $_ -is [Talk] } | ConvertTo-Hashtable { $_.Id }
    $ArtifactRepository.Speakers = $entities | Where-Object { $_ -is [Speaker] } | ConvertTo-Hashtable { $_.Id }

    $meetup =
        $entities |
        Where-Object { $_ -is [Meetup] } |
        Sort-Object -Property @{ Expression = { $_.Sessions[0].StartTime } } |
        Select-Object -Last 1

    $path = Join-Path $Config.ArtifactsDir "Artifacts-$($meetup.Id).txt"
    $meetup |
        Format-Meetup |
        Join-ToString -Delimeter "`n" |
        Set-Content -Path $path -Encoding UTF8

    # HACK: Convert EOL to Windows Style
    $content = Get-Content -Path $path -Encoding UTF8
    $content | Set-Content -Path $path -Encoding UTF8

    $timer | Stop-TimeOperation

    Start-Process -FilePath 'notepad.exe' -ArgumentList $path
}
