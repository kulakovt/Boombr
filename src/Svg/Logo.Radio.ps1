. $PSScriptRoot\Svg.ps1

function New-SvgWaveLine([int] $X, [int] $Y, [int] $Width, [int] $Height, [bool] $Invert, [Hashtable] $Attributes = @{})
{
    $width1 = $Width - ($Height / 2)
    if ($width1 -lt 0)
    {
        $width1 = 0
    }

    $sweep = 1
    if ($Invert)
    {
        $width1 *= -1
        $sweep = 0
    }
    $width2 = $width1 * -1
    [int] $radius = $Height / 2

    '<path d="m{0},{1}h{2} a{3},{3} 0 1,{4} 0,{5}h{6}z"{7}/>' -f "$X","$Y","$width1","$radius","$sweep","$Height","$width2",($Attributes | Format-XmlAttributeLine)
}

function Select-SvgWaveLine
{
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)] [double] $PartitionRation,
        [Parameter(Mandatory)] [double] $X,
        [Parameter(Mandatory)] [double] $Y,
        [Parameter(Mandatory)] [double] $Width,
        [Parameter(Mandatory)] [double] $PartitionHeight,
        [Parameter(Mandatory)] [double] $Space,
        [Parameter(Mandatory)] [bool] $Invert
    )

    begin
    {
        $position = 0
    }
    process
    {
        [int] $partitionWidth = $Width * $PartitionRation
        $partitionX = $X
        $partitionY = $Y + ($PartitionHeight + $Space) * $position

        if ($Invert)
        {
            $partitionX = $X + $Width
        }

        New-SvgWaveLine -X $partitionX -Y $partitionY -Width $partitionWidth -Height $PartitionHeight -Invert $Invert

        $position++
    }
}

function New-SvgWave(
    [double] $X,
    [double] $Y,
    [double] $Width,
    [double] $Height,
    [string] $FirstColor = '#fff',
    [string] $SecondColor = '#cf18fd',
    [string] $FirstId = $null,
    [string] $SecondId = $null,
    [array] $Partitions = @(0.29,0.67,0.41,0.71,1.0,0.59,0.19,0.47,0.73))
{
    # Magic formula, means: the height of a partition is the entire height divided by the number of partitions
    # with spaces, except for the last one. The size of the space is one-third of the height of the partition.
    # H = ((h + h/3) + (h + h/3) + ... + (h + h/3)) + h
    $partitionHeight = (3 * $Height) / (4 * ($Partitions.Length - 1) + 3)
    $space = $partitionHeight / 3
    $halfWidth = $Width / 2 - $space / 2

    &{
        $Partitions |
        Select-SvgWaveLine -X $X -Y $Y -Width $halfWidth -PartitionHeight $partitionHeight -Space $space -Invert $true
    } |
    New-SvgGroup -Id $FirstId -Attributes @{ 'fill' = $FirstColor }

    &{
        $secondX = $X + $halfWidth + $space
        $Partitions |
        Select-SvgWaveLine -X $secondX -Y $Y -Width $halfWidth -PartitionHeight $partitionHeight -Space $space -Invert $false
    } |
    New-SvgGroup -Id $SecondId -Attributes @{ 'fill' = $SecondColor }
}
