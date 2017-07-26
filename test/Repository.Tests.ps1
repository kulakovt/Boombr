Set-StrictMode -version Latest
$ErrorActionPreference = 'Stop'

$root = Join-Path $PSScriptRoot '..' -Resolve

Describe 'Repository verification' {

    Context 'All text files in repository' {

        function Get-AllTextFile()
        {
            Get-ChildItem -Path $root -File -Recurse |
            Where-Object { $_.FullName -notlike '*\artifacts\*' }
        }

        It 'Should have windows like end of file' {
            filter Select-UnixEndOfLine()
            {
                $file = $_
                $content = $file | Get-Content -Raw
                if ($content -match '[^\r]\n')
                {
                    $file
                }
            }

            $unixFiles = Get-AllTextFile |
            Select-UnixEndOfLine |
            ForEach-Object { Resolve-Path $_.FullName -Relative }

            $unixFiles | Should BeNullOrEmpty
        }
    }

    Context 'All PowerShell files in repository' {

        function Get-AllSourceFile()
        {
            Get-ChildItem -Path $root -Filter '*.ps1' -File -Recurse
        }

        It 'Should pass script analysis' {

            $diagnostic = Invoke-ScriptAnalyzer -Path $root -Recurse
            $diagnostic | Format-Table -AutoSize | Out-Host
            $diagnostic | Should BeNullOrEmpty
        }
    }
}
