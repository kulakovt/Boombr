function Export-Entity([string] $entityPath, [string[]] $fileNames)
{
    $srcDir = [io.path]::combine($Config.AuditDir, $entityPath)
    $dstDir = [io.path]::combine($Config.ArtifactsDir, $entityPath)

    New-Item -Path $dstDir -ItemType directory -Force

    Get-ChildItem -path $srcDir | ForEach-Object {
        $dbImageDir = [io.path]::combine($srcDir, $_.Name)

        $fileNames | ForEach-Object {
            Export-File -srcDir $dbImageDir -fileName $_ -dstDir $dstDir
        }
    }

    # Perform lossless compression
    ..\third-party\Leanify.exe --quiet $dstDir
}

function Export-File ([string] $srcDir, [string] $fileName, [string] $dstDir) {
    $srcFile = [io.path]::combine($srcDir, $fileName)
    $dstFile = [io.path]::combine($dstDir, $fileName)

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
