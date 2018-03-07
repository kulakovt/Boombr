. "$PSScriptRoot\..\src\Serialization.ps1"

Describe 'Xml serialization' {

    Context 'Basic' {

        It 'Should write Xml from Entity' {

            $enity = [Community]::new()
            $enity.Id = 'Posh'
            $enity.Name = 'PowerShell Community'

            $xml = ConvertTo-NiceXml -Entity $enity

            $xml | Should Not Be $null
        }

        It 'Should read Entity from Xml' {

            $text = @"
<Community>
  <Id>Posh</Id>
  <Name>PowerShell Community</Name>
</Community>
"@
            $xml = [System.Xml.Linq.XDocument]::Parse($text).Root

            $entity = ConvertFrom-NiceXml -XEntity $xml

            $entity | Should Not Be $null
        }

        It 'Should write Id first' {

            $enity = [Community]::new()
            $enity.Id = 'Posh'
            $enity.Name = 'PowerShell Community'

            $xml = (ConvertTo-NiceXml -Entity $enity).ToString()

            $xml.IndexOf('Id') | Should BeLessThan $xml.IndexOf('Name')
        }
    }

    Context 'Format Sessions list' {

        $start = [DateTime]'2017-01-15T16:00:00Z'

        $s1 = [Session]::new()
        $s1.TalkId = 'Talk-1'
        $s1.StartTime = $start
        $s1.EndTime = $s1.StartTime.AddHours(1)

        $s2 = [Session]::new()
        $s2.TalkId = 'Talk-2'
        $s2.StartTime = $s1.EndTime.AddMinutes(30)
        $s2.EndTime = $s2.StartTime.AddHours(1)

        $meetup = [Meetup]::new()
        $meetup.Sessions = @($s1, $s2)

        $xml = [xml](ConvertTo-NiceXml -Entity $meetup)
        $sessions = $xml.Meetup.Sessions

        It 'Should save Sessions' {

            $sessions | Should Not BeNullOrEmpty
            $sessions.Session.Count | Should Be 2
        }

        It 'Should save TalkId' {

            $sessions.Session.TalkId | Should Be @('Talk-1', 'Talk-2')
        }

        It 'Should save StartTime' {

            $sessions.Session.StartTime | Should Be @('2017-01-15T16:00:00Z', '2017-01-15T17:30:00Z')
        }

        It 'Should save EndTime' {

            $sessions.Session.EndTime | Should Be @('2017-01-15T17:00:00Z', '2017-01-15T18:30:00Z')
        }
    }

    Context 'Parse Session List' {

        $text =
@"
<Meetup>
<Sessions>
  <Session>
    <TalkId>Talk-1</TalkId>
    <StartTime>2017-01-15T16:00:00Z</StartTime>
    <EndTime>2017-01-15T17:00:00Z</EndTime>
  </Session>
  <Session>
    <TalkId>Talk-2</TalkId>
    <StartTime>2017-01-15T17:30:00Z</StartTime>
    <EndTime>2017-01-15T18:30:00Z</EndTime>
  </Session>
</Sessions>
</Meetup>
"@

            $xml = [System.Xml.Linq.XDocument]::Parse($text).Root
            $meetup = ConvertFrom-NiceXml -XEntity $xml
            $sessions = $meetup.Sessions

        It 'Should found Sessions' {

            $sessions | Should Not Be $null
            $sessions.Count | Should Be 2
        }
    }
}
