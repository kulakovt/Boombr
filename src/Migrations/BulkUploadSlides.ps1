Clear-Host

Set-StrictMode -version Latest
$ErrorActionPreference = 'Stop'

. $PSScriptRoot\..\Model.ps1
. $PSScriptRoot\..\Utility.ps1
. $PSScriptRoot\..\Serialization.ps1

$auditDir = Join-Path $PSScriptRoot '..\..\..\Audit\db' -Resolve

# http://knowledgevault-sharing.blogspot.ru/2017/05/selenium-webdriver-with-powershell.html
$lib = Join-Path $PSScriptRoot 'lib'
Add-Type -Path "$lib\Selenium.WebDriverBackedSelenium.dll"
Add-Type -Path "$lib\WebDriver.dll"
Add-Type -Path "$lib\WebDriver.Support.dll"
$slidesDir = Join-Path $PSScriptRoot 'slides'

$password = '<Password for SpeakerDeck>'

class Slides
{
    [string] $Name
    [string] $Description
    [DateTime] $PublishDate
    [string] $LocalPath
}

function Get-WebTalk([Uri] $Address)
{
    1..10 |
    ForEach-Object {

        $talkAddress = "${Address}?page=$_"
        $content = Invoke-WebRequest $talkAddress

        $content.ParsedHtml.getElementsByTagName('div') | Where-Object { $_.className -eq 'talks'} |
        ForEach-Object { $_.getElementsByTagName('h3') } | Where-Object { $_.className -eq 'title' } |
        ForEach-Object { $_.getElementsByTagName('a') } |
        ForEach-Object {
            [PSCustomObject] @{
                Name = $_.textContent.Trim()
                LocalPath = $_.href.TrimStart('about:')
            }
        }
    }
}

filter Select-WebElement([string] $ById)
{
    $waiter = $_
    if ((-not $waiter) -or (-not $ById))
    {
        return
    }

    $waiter.Until([OpenQA.Selenium.Support.UI.ExpectedConditions]::ElementIsVisible([OpenQA.Selenium.By]::Id($ById)))
}

function Set-WebText([string] $Text)
{
    process
    {
        $webElement = $_
        if ((-not $webElement) -or (-not $Text))
        {
            return
        }

        $webElement.Clear()
        $webElement.SendKeys($Text)
    }
}

function Add-Slide()
{
    begin
    {
        $options = New-Object OpenQA.Selenium.Chrome.ChromeOptions
        $options.AddArguments(@('--allow-running-insecure-content', '--disable-infobars', '--enable-automation', "--lang=en"))
        $options.AddUserProfilePreference("credentials_enable_service", $false)
        $options.AddUserProfilePreference("profile.password_manager_enabled", $false)
        $driver = New-Object OpenQA.Selenium.Chrome.ChromeDriver($options)
        $page = New-Object -TypeName OpenQA.Selenium.Support.UI.WebDriverWait($driver, (New-TimeSpan -Seconds 30))

        ### Login

        $driver.Navigate().GoToUrl('https://speakerdeck.com/signin')

        $page | Select-WebElement -ById 'email' | Set-WebText -Text 'hi@dotnet.ru'
        $page | Select-WebElement -ById 'password' | Set-WebText -Text $password

        $sigInControl = $page.Until([OpenQA.Selenium.Support.UI.ExpectedConditions]::ElementIsVisible([OpenQA.Selenium.By]::XPath('//button[text()="Sign In"]')))
        $sigInControl.Click()
    }
    process
    {
        $slides = [Slides]$_
        Write-Host "Upload: $($slides.Name)"

        ### Upload

        $driver.Navigate().GoToUrl('https://speakerdeck.com/new')

        $driver.ExecuteScript('$("#file").attr("style","font-size: 12px; opacity: 1;");')
        $page | Select-WebElement -ById 'file' | Set-WebText -Text $slides.LocalPath

        $page | Select-WebElement -ById 'talk_name' | Set-WebText -Text $slides.Name
        $page | Select-WebElement -ById 'talk_description' | Set-WebText -Text $slides.Description

        $category = $page | Select-WebElement -ById 'talk_category_id'
        $categorySelector = New-Object -TypeName OpenQA.Selenium.Support.UI.SelectElement($category)
        $categorySelector.SelectByText('Programming')

        $datePolicy = $page | Select-WebElement -ById 'talk_view_policy'
        $datePolicy.Click()

        $dateText = $slides.PublishDate.ToUniversalTime().ToString('yyyy/MM/dd', [Globalization.CultureInfo]::InvariantCulture)
        $page | Select-WebElement -ById 'talk_published_at' | Set-WebText -Text $dateText

        $saveControl = $page.Until([OpenQA.Selenium.Support.UI.ExpectedConditions]::ElementIsVisible([OpenQA.Selenium.By]::XPath('//button[text()="Save the Details"]')))
        $saveControl.Click()

        Start-Sleep -Seconds 60
    }
    end
    {
        ### Quit

        $driver.Close()
        $driver.Dispose()
        $driver.Quit()
    }
}

$existingTalks = Get-WebTalk -Address 'https://speakerdeck.com/dotnetru' |
Select-Object -ExpandProperty 'Name'
Write-Host "Found $($existingTalks.Count) existing slides"

$entities = Read-All -AuditDir $auditDir

$talkToDate = $entities | Where-Object { $_ -is [Meetup] } | % { $_.Sessions } | ConvertTo-Hashtable { $_.TalkId } { $_.StartTime }
$speakerToName = $entities | Where-Object { $_ -is [Speaker] } | ConvertTo-Hashtable { $_.Id } { $_.Name }

$entities |
Where-Object { $_ -is [Talk] } |
ForEach-Object {
    $talk = [Talk]$_

    if (-not $talk.SlidesUrl)
    {
        return
    }
    $slidesPath = Join-Path $slidesDir $talk.Id
    $slidesPath += '.pdf'
    if (-not (Test-Path $slidesPath))
    {
        throw "Slides not found in $slidesPath"
    }

    $speakers = $talk.SpeakerIds |
    ForEach-Object { $speakerToName[$_] } |
    Join-ToString -Delimeter ', '

    $slides = [Slides]::new()
    $slides.PublishDate = $talkToDate[$talk.Id]
    $slides.Name = "$speakers «$($talk.Title)»"
    $slides.Description = $talk.Description
    $slides.LocalPath = $slidesPath
    $slides
} |
Where-Object { -not $existingTalks.Contains($_.Name) } |
Select-Object -First 20 |
Add-Slide
