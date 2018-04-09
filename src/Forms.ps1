. $PSScriptRoot\YamlSerialization.ps1

function Get-LastMeetupSample()
{
    $entities = Read-All $Config.AuditDir

    $entities |
    Where-Object { $_ -is [Meetup] } |
    Where-Object { $_.CommunityId -eq 'SpbDotNet' } |
    Sort-Object -Property @{ Expression = { $_.Sessions[0].StartTime } } |
    Select-Object -Last 1 |
    ForEach-Object {
        $meetup = $_
        $meetup
        $entities | Where-Object { $_.Id -eq $meetup.FriendIds[0] }
        $entities | Where-Object { $_.Id -eq $meetup.VenueId }

        $talk = $entities | Where-Object { $_.Id -eq $meetup.Sessions[0].TalkId }
        $talk
        $entities | Where-Object { $_.Id -eq $talk.SpeakerIds[0] }
    }
}

function New-Meetup()
{
    $file = Join-Path $Config.ArtifactsDir 'New Meetup.txt'
    if (-not (Test-Path $file))
    {
        Get-LastMeetupSample |
        Write-NiceYaml -FilePath $file
    }

    Start-Process -FilePath 'notepad.exe' -ArgumentList $file -Wait

    $timer = Start-TimeOperation -Name 'New Meetup'

    $file |
        Read-NiceYaml |
        # TODO: Add content validation
        Save-Entity $Config.AuditDir -CreateOnly

    $timer | Stop-TimeOperation
}
