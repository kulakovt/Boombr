. "$PSScriptRoot\..\src\Serialization.ps1"

Describe 'Xml serialization' {
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
}
