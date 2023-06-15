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

        $meetup | Format-Comment
        $meetup | Format-ShortProgram
        $meetup | Format-LongProgram
        $meetup | Format-Footer
    }
}

function Format-Comment
{
    process
    {
        $meetup = [Meetup]$_

        $date = $meetup.Sessions[0].StartTime.ToLocalTime().ToString('dd.MM.yyyy')
        $name = $meetup.Name
        $venue = $null

        if ($meetup.VenueId)
        {
            $venue = $AnnouncementRepository.Venues[$meetup.VenueId].Address
        }
        else
        {
            $name += ' (Online)'
        }

@"
<!--
$name
$date
"@
        if ($venue)
        {
            "Адресс: $venue"
        }

        if ($meetup.FriendIds)
        {
            'Партнёры:'
            $meetup.FriendIds |
                ForEach-Object {

                    $friend = $AnnouncementRepository.Friends[$_]
                    $logo = Join-Path $Config.AuditDir "friends/$($friend.Id)/logo.small.png"
                    "  - $($friend.Name)"
                    "  - $($friend.Url)"
                    "  - $logo"
                }
        }
@'
-->

'@
    }
}

function Format-ShortProgram
{
    process
    {
        $meetup = [Meetup]$_
        $isOffline = $meetup.VenueId -ne $null
        $lastEndTime = $null

        '<h3>Программа встречи</h3>'
        '<p>'
        foreach ($session in $meetup.Sessions)
        {
            # TODO: Use Community TimeZone
            $startTime = $session.StartTime.ToLocalTime().ToString('HH:mm')
            $endTime = $session.EndTime.ToLocalTime().ToString('HH:mm')

            $talk = $AnnouncementRepository.Talks[$session.TalkId]
            $speakers = $talk.SpeakerIds |
                ForEach-Object { $AnnouncementRepository.Speakers[$_] } |
                ForEach-Object { $_.Name + $(if ($_.CompanyName) { " ($($_.CompanyName))" } else { '' }) } |
                Join-ToString -Delimeter ', ' |
                Format-HtmlEncode

            $title = $talk.Title | Format-HtmlEncode

            if ($lastEndTime -ne $null)
            {
                "$lastEndTime&nbsp;&ndash;&nbsp;$startTime Перерыв<br />"
            }

            $lastEndTime = $endTime

            "$startTime&nbsp;&ndash;&nbsp;$endTime $speakers &laquo;$title&raquo;<br />"
        }
        '</p>'

        if ($isOffline)
        {
            "<p>После этих вдохновляющих речей приглашаем всех желающих в бар для обсуждения накопившихся вопросов и идей!</p>"
        }
    }
}

function Format-LongProgram
{
    process
    {
        $meetup = [Meetup]$_

        '<table style="border:0;padding:0;"><tbody>'
        foreach ($session in $meetup.Sessions)
        {
            $talk = $AnnouncementRepository.Talks[$session.TalkId]
            $speakers = $talk.SpeakerIds |
                ForEach-Object { $AnnouncementRepository.Speakers[$_].Name } |
                Join-ToString -Delimeter ', ' |
                Format-HtmlEncode

            $title = $talk.Title | Format-HtmlEncode
            $description = $talk.Description | Format-HtmlEncode
            $aboutHeader = if ($talk.SpeakerIds.Length -eq 1) { 'Об авторе' } else { 'Об авторах' }
@"
  <tr><td>
    <h3>$speakers<br />&laquo;$title&raquo;</h3>
    <p>$description</p>
    <p><strong>$aboutHeader</strong></p>
  </td></tr>
"@
            foreach ($speakerId in $talk.SpeakerIds)
            {
                $speaker = $AnnouncementRepository.Speakers[$speakerId]
                $imagePath = Join-Path $Config.AuditDir "speakers/$($speaker.Id)/avatar.small.jpg"
                $about = $speaker.Description | Format-HtmlEncode
@"
  <tr><td>
  <p>
    <!-- $imagePath -->
    <img alt="Автор" src="https://fakeimg.pl/200x300/?text=$($speaker.Id)" style="margin:0 10px 0 0;float:left;width:200px;" />
    $about
  </p>
  </td></tr>
"@
            }
        }
        '</tbody></table>'
    }
}

function Format-Footer
{
    process
    {
        $meetup = [Meetup]$_
        $isOffline = $meetup.VenueId -ne $null
        $isOnline = -not $isOffline
        $limitPrefix = if ($isOffline) { '' } else { 'не ' }
@"
<p>&nbsp;</p>
<p><strong>Участие бесплатное, регистрация обязательна, количество мест ${limitPrefix}ограничено!</strong></p>
"@
        if ($isOnline)
        {
'<p>Встреча будет проходить во всемирной сети &laquo;Интернет&raquo;. Ссылка на трансляцию придёт&nbsp;к вам за час до мероприятия. Все вопросы к докладчикам можно будет задавать в <a href="https://t.me/SpbDotNetChat">нашем Telegram chat&#39;е</a>.</p>'
        }
@'
<p>Дополнительную информацию о встречах <strong>SpbDotNet Community</strong> (и не только) вы можете найти в группах сообщества:</p>
<ul>
  <li>VK: <a href="https://vk.com/spbdotnet">https://vk.com/SpbDotNet</a></li>
  <li>Telegram channel: <a href="https://t.me/spbdotnet">https://t.me/SpbDotNet</a></li>
  <li>Telegram chat: <a href="https://t.me/spbdotnet">https://t.me/SpbDotNetChat</a></li>
  <li>Meetup.com: <a href="https://www.meetup.com/SpbDotNet/">https://www.meetup.com/SpbDotNet</a></li>
</ul>

<p>Подписывайтесь на новости, задавайте вопросы, участвуйте в жизни сообщества!</p>
'@
        if ($isOnline)
        {
            # ITMeeting интересуют только online митапы или с трансляцией
@'
<p>&nbsp;</p>
<p><strong>Информационный партнёр</strong></p>
<p><img alt="" src="https://ucare.timepad.ru/aeb61c7a-80c1-4605-a544-50c1bb0a1a1b/-/preview/" style="width:100px;height:100px;" /><a href="https://itmeeting.ru/">ITMeeting</a>&nbsp;&mdash;&nbsp;телеграм-канал с анонсами бесплатных мероприятий для разработчиков</p>
'@
        }
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
        Join-ToString -Delimeter "`n" |
        Set-Content -Path $path -Encoding UTF8

    # HACK: Convert EOL to Windows Style
    $content = Get-Content -Path $path -Encoding UTF8
    $content | Set-Content -Path $path -Encoding UTF8

    $timer | Stop-TimeOperation

    Start-Process -FilePath 'notepad.exe' -ArgumentList $path
}
