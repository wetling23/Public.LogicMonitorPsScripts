<#
    .DESCRIPTION
        Log into the SuccessWareASP XenApp page. Return 1 if successful, return 0 if the login fails.
    .NOTES
        Author: Mike Hashemi
        V1.0.0.0 date: 1 October 2020
        V1.0.0.1 date: 29 October 2020
        V1.0.0.2 date: 22 January 2021
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/DataSourceScripts/Selenium/SuccessWareASP
#>
[CmdletBinding()]
param()

#region Setup
# Initialize variables.
$seleniumPath = 'C:\it\selenium' # Path to the selenium WebDriver (and ChromeDriver) files.
$computerName = '##system.hostname##'
$url = '##successware.url##'
$username = '##successware.user##'
$pass = @'
##successware.pass##
'@
$cred = New-Object System.Management.Automation.PSCredential ($username, $($pass | ConvertTo-SecureString -AsPlainText -Force))

Function Test-ChromeDriverVersion {
    [CmdletBinding()]
    param(
        [ValidateScript( {
                If (-NOT ($_ | Test-Path) ) {
                    Throw "File or folder does not exist."
                }
                If (-NOT ($_ | Test-Path -PathType Container) ) {
                    Throw "The Path argument must be a folder. Folder paths are not allowed."
                }
                Return $true
            })]
        [System.IO.FileInfo]$ChromeDriverDir
    )

    $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    Write-Host $message; $message | Out-File -FilePath $logFile -Append

    $chromeDriverFileLocation = $(Join-Path $ChromeDriverDir "chromedriver.exe")
    $chromeVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo("C:\Program Files (x86)\Google\Chrome\Application\chrome.exe").FileVersion
    $chromeMajorVersion = $chromeVersion.split(".")[0]

    If (-NOT($chromeMajorVersion -gt 0)) {
        $message = ("{0}: Google Chrome not installed. {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
        Write-Error $message; $message | Out-File -FilePath $logFile -Append

        Return 1
    }

    If (Test-Path -Path $chromeDriverFileLocation -ErrorAction SilentlyContinue) {
        $message = ("{0}: Getting chromedriver.exe version." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        Write-Host $message; $message | Out-File -FilePath $logFile -Append

        $chromeDriverFileVersion = (& $chromeDriverFileLocation --version)
        $chromeDriverFileVersionHasMatch = $chromeDriverFileVersion -match "ChromeDriver (\d+\.\d+\.\d+(\.\d+)?)"
        $chromeDriverCurrentVersion = $matches[1]

        If (-NOT $chromeDriverFileVersionHasMatch) {
            $message = ("{0}: No chromedriver.exe version identified. To prevent errors, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
            Write-Error $message; $message | Out-File -FilePath $logFile -Append

            Return 1
        }
    }
    Else {
        $message = ("{0}: Chromedriver.exe not found. {1} will attempt to download it." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
        Write-Host $message; $message | Out-File -FilePath $logFile -Append

        $chromeDriverCurrentVersion = '' # Need this here, to compare versions later.
    }

    $message = ("{0}: Determining latest Chrome/chromedriver version information." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    Write-Host $message; $message | Out-File -FilePath $logFile -Append

    $chromeDriverExpectedVersion = $chromeVersion.split(".")[0..2] -join "."
    $chromeDriverVersionUrl = "https://chromedriver.storage.googleapis.com/LATEST_RELEASE_" + $chromeDriverExpectedVersion

    $chromeDriverLatestVersion = Invoke-RestMethod -Uri $chromeDriverVersionUrl

    $needUpdateChromeDriver = $chromeDriverCurrentVersion -ne $chromeDriverLatestVersion

    If ($needUpdateChromeDriver) {
        $message = ("{0}: Chromedriver.exe does not match the version of Google Chrome, attempting to download the correct version." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        Write-Host $message; $message | Out-File -FilePath $logFile -Append

        $chromeDriverZipLink = "https://chromedriver.storage.googleapis.com/$chromeDriverLatestVersion/chromedriver_win32.zip"

        $message = ("{0}: Attempting to download from {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $chromeDriverZipLink)
        Write-Host $message; $message | Out-File -FilePath $logFile -Append

        Try {
            Invoke-WebRequest -Uri $chromeDriverZipLink -OutFile $(Join-Path $ChromeDriverDir "chromedriver_win32.zip") -ErrorAction Stop
        }
        Catch {
            $message = ("{0}: Unexpected error downloading the file. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
            Write-Error $message; $message | Out-File -FilePath $logFile -Append

            Return 1
        }

        $message = ("{0}: Attempting to extract chromedriver.exe." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        Write-Host $message; $message | Out-File -FilePath $logFile -Append

        Try {
            Expand-Archive -Path $(Join-Path $ChromeDriverDir "chromedriver_win32.zip") -DestinationPath $ChromeDriverDir -Force -ErrorAction Stop
            Remove-Item -Path $(Join-Path $ChromeDriverDir "chromedriver_win32.zip") -Force -ErrorAction Continue

            $message = ("{0}: Chromedriver.exe updated to version {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), (& $chromeDriverFileLocation --version))
            Write-Host $message; $message | Out-File -FilePath $logFile -Append

            Return 0
        }
        Catch {
            $message = ("{0}: Unexpected error extracting chromedriver.exe. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
            Write-Error $message; $message | Out-File -FilePath $logFile -Append

            Return 1
        }

    }
    Else {
        $message = ("{0}: Chromedriver.exe is up-to-date." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        Write-Host $message; $message | Out-File -FilePath $logFile -Append

        Return 0
    }
}

If (Test-Path -Path "C:\Program Files (x86)\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "C:\Program Files (x86)\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
}
Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\datasource-SuccessWareASP_Login_Availability-collection-$computerName.log"
#endregion Setup

#region Main
$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
Write-Host $message; $message | Out-File -FilePath $logFile

$result = Test-ChromeDriverVersion -ChromeDriverDir $seleniumPath

If ($result -eq 1) {
    $message = ("{0}: Unable to validate chromedriver.exe version. To prevent errors, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    Write-Host $message; $message | Out-File -FilePath $logFile

    Exit 1
}

$message = ("{0}: Starting chromedriver.exe." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
Write-Host $message; $message | Out-File -FilePath $logFile -Append

Try {
    # Invoke Selenium into our script!
    $env:PATH += ";$seleniumPath" # Adds the path for ChromeDriver.exe to the environmental variable 
    Add-Type -Path "$seleniumPath\WebDriver.dll" # Adding Selenium's .NET assembly (dll) to access it's classes in this PowerShell session
    $chromedriver = New-Object OpenQA.Selenium.Chrome.ChromeDriver # Creates an instance of this class to control Selenium and stores it in an easy to handle variable
}
Catch {
    $message = ("{0}: Unexpected error creating Chrome driver. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
    Write-Host $message; $message | Out-File -FilePath $logFile -Append

    Exit 1
}

$message = ("{0}: Attempting to load {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $url)
Write-Host $message; $message | Out-File -FilePath $logFile -Append

Try {
    $startTime = $chromedriver.ExecuteScript("return performance.timing.navigationStart")
    $chromedriver.Navigate().GoToURL($Url)
    Start-Sleep 5 # waiting for page load
    $chromedriver.FindElementById("Enter user name").SendKeys($cred.Username) # Methods to find the input textbox for the username and type it into the textbox
    $chromedriver.FindElementById("passwd").SendKeys($cred.GetNetworkCredential().password) # Methods to find the input textbox for the password and type it into the textbox
    $chromedriver.FindElementById("passwd").Submit()
    Start-Sleep 5
    $chromedriver.FindElementById("protocolhandler-welcome-installButton").Click() # "Detect client" button
    Start-Sleep 3
    $chromedriver.FindElementById("legalstatement-checkbox2").Click() # Accept the license to clear any hover text
    $chromedriver.FindElementById("protocolhandler-detect-alreadyInstalledLink").Click() # Skip the client install
    $endTime = $chromedriver.ExecuteScript("return window.performance.timing.domComplete")
    $duration = $endTime - $startTime
}
Catch {
    $message = ("{0}: Unexpected error loading {1}. Error: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $url, $_.Exception.Message)
    Write-Error $message; $message | Out-File -FilePath $logFile -Append

    $chromedriver.Close()
    $chromedriver.Quit()

    Write-Host ("LoginSuccess=0")

    Exit 0
}

# Giving the page time to load.
Start-Sleep 10

$message = ("{0}: Looking for logoff link." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
Write-Host $message; $message | Out-File -FilePath $logFile -Append

Try {
    $chromedriver.FindElementById("userMenuBtn").Click()
    $chromedriver.FindElementById("dropdownLogOffBtn").Click()

    $chromedriver.Close()
    $chromedriver.Quit()

    Write-Host ("LoginSuccess=1")
    Write-Host ("LogonDurationMs={0}" -f $duration)

    Exit 0
}
Catch {
    $message = ("{0}: Unexpected error logging off. If available, the exception is: {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
    Write-Error $message; $message | Out-File -FilePath $logFile -Append

    Write-Host ("LoginSuccess=0")

    Exit 0
}
#endregion Main