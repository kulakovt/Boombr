function Resolve-FullPath()
{
    if (-not $args)
    {
        throw 'Provide a paths to be joined'
    }

    if (-not [IO.Path]::IsPathRooted($args[0]))
    {
        throw "First part shoul be absolute path, but not: $($args[0])"
    }

    $path = [IO.Path]::Combine([string[]]$args)
    [IO.Path]::GetFullPath($path)
}

function Start-TimeOperation([string] $Name = $(throw 'Name required'))
{
    Write-Information "$Name..."
    @{
        Name = $Name
        Timer = [System.Diagnostics.Stopwatch]::StartNew()
    }
}

function Stop-TimeOperation()
{
    process
    {
        $operation = $_
        $operation.Timer.Stop()
        Write-Information "$($operation.Name) completed in $($operation.Timer.Elapsed)"
    }
}

filter Select-NotNull()
{
    if ($_)
    {
        $_
    }
}

function Select-Single($ElementNames = 'elements')
{
    begin
    {
        $count = 0
    }
    process
    {
        if ($_)
        {
            $count++
            $_
        }
    }
    end
    {
        if ($count -ne 1)
        {
            throw "Found $count $ElementNames in collection"
        }
    }
}

function ConvertTo-Hashtable([ScriptBlock] $KeySelector = $(throw "Key selector required"), [ScriptBlock] $ElementSelector = { $_ })
{
    begin
    {
        $hash = @{}
    }
    process
    {
        $item = $_
        $key = & $KeySelector $item
        $element = & $ElementSelector $item
        $hash[$key] = $element
    }
    end
    {
        $hash
    }
}
