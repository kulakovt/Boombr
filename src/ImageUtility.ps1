$DotNetRuAppStorage = Resolve-FullPath $PSScriptRoot '..\..\App\DotNetRu.DataStore.Audit\Storage'

function Export-Entity([string] $entityPath, [string[]] $fileNames)
{
    $srcDir = Join-Path $Config.AuditDir $entityPath
    $dstDir = Join-Path $DotNetRuAppStorage $entityPath

    New-Item -Path $dstDir -ItemType directory -Force

    Get-ChildItem -path $srcDir | ForEach-Object {
        $dbImageDir = $_.FullName
        $speakerName = $_.Name

        $fileNames | ForEach-Object {
            Export-File -srcDir $dbImageDir -fileName $_ -speakerName $speakerName -dstDir $dstDir
        }
    }
}

function Export-File ([string] $srcDir, [string] $fileName, [string] $speakerName, [string] $dstDir) {
    $srcFile = Join-Path $srcDir $fileName
    $dstFile = Join-Path $dstDir ($speakerName + "." + $fileName)

    Copy-Item -Path $srcFile -Destination $dstFile
}

function Export-Image()
{
    $timer = Start-TimeOperation -Name 'Export images'

    # Export speakers
    Export-Entity "speakers" @("avatar.jpg", "avatar.small.jpg")

    # Export friends
    Export-Entity "friends" @("logo.png", "logo.small.png")

    $timer | Stop-TimeOperation
}
