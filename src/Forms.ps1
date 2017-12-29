. $PSScriptRoot\YamlSerialization.ps1

function New-Meetup()
{
    $file = Join-Path $Config.ArtifactsDir 'New Meetup.txt'
    if (-not (Test-Path $file))
    {
        @(
            'meetups/SpbDotNet-8.xml'
            'friends/DataArt/index.xml'
            'venues/Spb-Telekom.xml'
            'talks/Structured-logging.xml'
            'talks/Design-of-RESTFul-API.xml'
            'speakers/Anatoly-Kulakov/index.xml'
        ) |
        ForEach-Object { Join-Path $Config.AuditDir $_ } |
        Read-NiceXml |
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
