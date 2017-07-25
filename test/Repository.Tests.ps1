Set-StrictMode -version Latest
$ErrorActionPreference = 'Stop'

$root = Join-Path $PSScriptRoot '..' -Resolve

Describe 'Repository verification' {

    Context 'All text files in repository' {

        function Get-AllTextFiles() {
            Get-ChildItem -Path "$root" -File -Recurse |
                ? { $_.FullName -notlike '*\artifacts\*' }
        }

        It 'Should have windows like end of file' {
            filter Select-UnixEndOfLine() {
                $file = $_
                $content = $file | Get-Content -Raw
                if ($content -match '[^\r]\n')
                {
                    $file
                }
            }

            $unixFiles = Get-AllTextFiles |
                Select-UnixEndOfLine |
                % { Resolve-Path $_.FullName -Relative }

            $unixFiles | Should BeNullOrEmpty
        }
    }
}