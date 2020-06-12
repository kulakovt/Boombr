Set-StrictMode -version Latest
$ErrorActionPreference = 'Stop'

Describe 'Repository verification' {

    BeforeAll {

        $root = Join-Path $PSScriptRoot '..' -Resolve

        function Get-AllTextFile()
        {
            Get-ChildItem -Path $root -Exclude '.gitignore' -File -Recurse |
            Where-Object { $_.FullName -notlike '*\artifacts\*' }
        }

        function Get-AllSourceFile()
        {
            $src = Join-Path $root 'src'
            Get-ChildItem -Path $src -Filter '*.ps1' -File -Recurse |
            Where-Object { -not $_.FullName.Contains('Migrations') }
        }

        filter Select-UnixEndOfLine()
        {
            $file = $_
            $content = $file | Get-Content -Raw
            if ($content -match '[^\r]\n')
            {
                $file
            }
        }
    }

    Context 'All text files in repository' {

        It 'Should have windows like end of file' {

            $unixFiles = Get-AllTextFile |
            Select-UnixEndOfLine |
            ForEach-Object { Resolve-Path $_.FullName -Relative }

            $unixFiles | Should -BeNullOrEmpty
        }
    }

    Context 'All PowerShell files in repository' {

        It 'Should pass script analysis' {

            $diagnostic = Get-AllSourceFile | Invoke-ScriptAnalyzer
            $diagnostic | Format-Table -AutoSize | Out-Host
            $diagnostic | Should -BeNullOrEmpty
        }
    }
}
