$AnnouncementRepository = @{
    Communities = @{}
    Meetups = @{}
    Talks = @{}
    Speakers = @{}
    Friends = @{}
    Venues = @{}
}

function Format-Meetup()
{
    process
    {
        $meetup = [Meetup]$_

        "#### Программа $($meetup.Name -replace 'Встреча','встречи')"
        $meetup | Format-Program
        ''
        '#### Подробности'
        $meetup.Sessions.TalkId |
            ForEach-Object { $AnnouncementRepository.Talks[$_] } |
            Format-Talk
    }
}

function Format-Program
{
    process
    {
        $meetup = [Meetup]$_

        foreach ($session in $meetup.Sessions)
        {
            # TODO: Use Community TimeZone
            $startTime = $session.StartTime.ToLocalTime().ToString('HH:mm')
            $endTime = $session.EndTime.ToLocalTime().ToString('HH:mm')
            $title = $AnnouncementRepository.Talks[$session.TalkId] | Format-TalkTitle -IncludeCompany
            "$startTime - $endTime $title"
        }
    }
}

function Format-Talk()
{
    process
    {
        $talk = [Talk]$_

        $talk | Format-TalkTitle
        $talk.Description
        ''
        '#### Об авторе'
        foreach ($speakerId in $talk.SpeakerIds)
        {
            $speaker = $AnnouncementRepository.Speakers[$speakerId]
            Join-Path $Config.ArtifactsDir "speakers/$($speaker.Id)/avatar.small.jpg"
            $speaker.Description
            ''
        }
        ''
    }
}

function Format-TalkTitle([switch] $IncludeCompany)
{
    process
    {
        $talk = [Talk]$_

        $speakers = $talk.SpeakerIds |
            ForEach-Object { $AnnouncementRepository.Speakers[$_] } |
            ForEach-Object { $_.Name + $(if ($IncludeCompany) { " ($($_.CompanyName))" } else { '' }) } |
            Join-ToString -Delimeter ', '

        "$speakers «$($talk.Title)»"
    }
}

function Invoke-BuildAnnouncement()
{
    $timer = Start-TimeOperation -Name 'Build Announcement'

    # Load All
    $entities = Read-All -AuditDir $Config.AuditDir

    $AnnouncementRepository.Communities = $entities | Where-Object { $_ -is [Community] } | ConvertTo-Hashtable { $_.Id }
    $AnnouncementRepository.Meetups = $entities | Where-Object { $_ -is [Meetup] } | ConvertTo-Hashtable { $_.Id }
    $AnnouncementRepository.Talks  = $entities | Where-Object { $_ -is [Talk] } | ConvertTo-Hashtable { $_.Id }
    $AnnouncementRepository.Speakers = $entities | Where-Object { $_ -is [Speaker] } | ConvertTo-Hashtable { $_.Id }
    $AnnouncementRepository.Friends = $entities | Where-Object { $_ -is [Friend] } | ConvertTo-Hashtable { $_.Id }
    $AnnouncementRepository.Venues = $entities | Where-Object { $_ -is [Venue] } | ConvertTo-Hashtable { $_.Id }

    $meetup =
        $entities |
        Where-Object { $_ -is [Meetup] } |
        Sort-Object -Property @{ Expression = { $_.Sessions[0].StartTime } } |
        Select-Object -Last 1

    $path = Join-Path $Config.ArtifactsDir "Announce-$($meetup.Id).txt"
    $meetup |
        Format-Meetup |
        Join-ToString |
        Set-Content -Path $path -Encoding UTF8

    # HACK: Convert EOL to Windows Style
    $content = Get-Content -Path $path -Encoding UTF8
    $content | Set-Content -Path $path -Encoding UTF8

    $timer | Stop-TimeOperation

    Start-Process -FilePath 'notepad.exe' -ArgumentList $path
}
