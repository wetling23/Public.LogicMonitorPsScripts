<#
    .DESCRIPTION
        Log into the SuccessWareASP XenApp page. Return 1 if successful, return 0 if the login fails.
    .NOTES
        Author: Mike Hashemi
        V1.0.0.0 date: 1 October 2020
        V1.0.0.1 date: 29 October 2020
        V1.0.0.2 date: 22 January 2021
        V1.0.0.3 date: 13 September 2021
        V1.0.0.4 date: 17 November 2021
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

    Try {
        $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
        Write-Host $message; $message | Out-File -FilePath $logFile -Append

        $date = ([datetime]::Now).ToString("yyyy-MM-dd`THH-mm-ss")
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
        } Else {
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
                If (Get-Process -Name chromedriver -ErrorAction SilentlyContinue) {
                    $message = ("{0}: Attempting to stop chromedriver.exe before extracting the replacement." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                    Write-Host $message; $message | Out-File -FilePath $logFile -Append

                    Try {
                        Get-Process -Name chromedriver | Stop-Process -Force
                    } Catch {
                        $message = ("{0}: Unexpected error stopping chromedriver. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
                        Write-Host $message; $message | Out-File -FilePath $logFile -Append

                        Return 1
                    }
                }

                (New-Object System.Net.WebClient).DownloadFile($chromeDriverZipLink, "$($ChromeDriverDir.FullName)\chromedriver_win32_$date.zip")
            } Catch {
                $message = ("{0}: Unexpected error downloading the file. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
                Write-Error $message; $message | Out-File -FilePath $logFile -Append

                Return 1
            }

            $message = ("{0}: Attempting to extract chromedriver.exe." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            Write-Host $message; $message | Out-File -FilePath $logFile -Append

            Try { ##need to test this section
                Expand-Archive -Path "$($ChromeDriverDir.FullName)\chromedriver_win32_$date.zip" -DestinationPath $ChromeDriverDir.FullName -Force -ErrorAction Stop
                Remove-Item -Path "$($ChromeDriverDir.FullName)\chromedriver_win32_$date.zip" -Force -ErrorAction Continue

                $message = ("{0}: Chromedriver.exe updated to version {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), (& $chromeDriverFileLocation --version))
                Write-Host $message; $message | Out-File -FilePath $logFile -Append

                Return 0
            } Catch {
                $message = ("{0}: Unexpected error extracting chromedriver.exe. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
                Write-Error $message; $message | Out-File -FilePath $logFile -Append

                Return 1
            }

        } Else {
            $message = ("{0}: Chromedriver.exe is up-to-date." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            Write-Host $message; $message | Out-File -FilePath $logFile -Append

            Return 0
        }
    }
    Catch {
        $message = ("{0}: Unexpected error in {1}. The error occurred at line {2}, the command was `"{3}`", and the specific error is: {4}" -f `
            ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.MyCommand.Name, $_.Exception.Message)
        Write-Host $message; $message | Out-File -FilePath $logFile -Append

        Return 1
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
    Write-Host $message; $message | Out-File -FilePath $logFile -Append

    Exit 1
}

$message = ("{0}: Starting Chrome." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
Write-Host $message; $message | Out-File -FilePath $logFile -Append

Try {
    # Invoke Selenium into our script!
    $env:PATH += ";$seleniumPath" # Adds the path for ChromeDriver.exe to the environmental variable 
    Add-Type -Path "$seleniumPath\WebDriver.dll" # Adding Selenium's .NET assembly (dll) to access it's classes in this PowerShell session
    $chromeOptions = New-Object OpenQA.Selenium.Chrome.ChromeOptions
    $chromeOptions.AddArgument("--headless")
    $chromeOptions.AddArgument("--disable-gpu")
    $chromedriver = New-Object OpenQA.Selenium.Chrome.ChromeDriver($chromeOptions) # Creates an instance of this class to control Selenium and stores it in an easy to handle variable
}
Catch {
    $message = ("{0}: Unexpected error starting Chrome. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
    Write-Error $message; $message | Out-File -FilePath $logFile -Append

    Exit 1
}

$message = ("{0}: Attempting to load {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $url)
Write-Host $message; $message | Out-File -FilePath $logFile -Append

Try {
    $startTime = $chromedriver.ExecuteScript("return performance.timing.navigationStart")
    $chromedriver.Navigate().GoToURL($Url)
    Start-Sleep 5 # waiting for page load
}
Catch {
    $message = ("{0}: Unexpected error loading the site. {1} will exit. If available, the exception is: {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message)
    Write-Error $message; $message | Out-File -FilePath $logFile -Append

    Write-Host ("LoginSuccess=0")

    Exit 1
}

If ($chromedriver.FindElementById("Enter user name")) {
    $message = ("{0}: Attempting to log into the site." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    Write-Host $message; $message | Out-File -FilePath $logFile -Append

    Try {
        $chromedriver.FindElementById("Enter user name").SendKeys($cred.Username) # Methods to find the input textbox for the username and type it into the textbox
        $chromedriver.FindElementById("passwd").SendKeys($cred.GetNetworkCredential().password) # Methods to find the input textbox for the password and type it into the textbox
        $chromedriver.FindElementById("passwd").Submit()
    }
    Catch {
        $message = ("{0}: Unexpected error logging into the site. If available, the exception is: {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
        Write-Error $message; $message | Out-File -FilePath $logFile -Append

        Write-Host ("LoginSuccess=0")

        Exit 1
    }
}
Else {
    $message = ("{0}: Unable to find the username field. {1} will exit" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    Write-Error $message; $message | Out-File -FilePath $logFile -Append

    Exit 1
}

$message = ("{0}: Waiting for login to complete." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
Write-Host $message; $message | Out-File -FilePath $logFile -Append

Start-Sleep 5

$message = ("{0}: Attempting to bypass XenApp client detection." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
Write-Host $message; $message | Out-File -FilePath $logFile -Append

Try {
    $chromedriver.FindElementById("protocolhandler-welcome-installButton").Click() # "Detect client" button
}
Catch {
    $message = ("{0}: Unexpected error dealing with XenApp client detection. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
    Write-Error $message; $message | Out-File -FilePath $logFile -Append

    $chromedriver.Close()
    $chromedriver.Quit()

    Exit 1
}

$message = ("{0}: Waiting for page load complete." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
Write-Host $message; $message | Out-File -FilePath $logFile -Append

Start-Sleep 3

$message = ("{0}: Attempting to access the list of published applications." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
Write-Host $message; $message | Out-File -FilePath $logFile -Append

Try {
    $chromedriver.FindElementById("legalstatement-checkbox2").Click() # Accept the license to clear any hover text
    $chromedriver.FindElementById("protocolhandler-detect-alreadyInstalledLink").Click() # Skip the client install
    $endTime = $chromedriver.ExecuteScript("return window.performance.timing.domComplete")
    $duration = $endTime - $startTime
}
Catch {
    $message = ("{0}: Unexpected error accessing the list of published applications. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
    Write-Error $message; $message | Out-File -FilePath $logFile -Append

    $chromedriver.Close()
    $chromedriver.Quit()

    Exit 1
}

$message = ("{0}: Waiting for page load complete." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
Write-Host $message; $message | Out-File -FilePath $logFile -Append

Start-Sleep 10

$message = ("{0}: Attempting to logoff." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
Write-Host $message; $message | Out-File -FilePath $logFile -Append

Try {
    $chromedriver.FindElementById("userMenuBtn").Click()
    $chromedriver.FindElementById("dropdownLogOffBtn").Click()
}
Catch {
    $message = ("{0}: Unexpected error logging off. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
    Write-Error $message; $message | Out-File -FilePath $logFile -Append

    $chromedriver.Close()
    $chromedriver.Quit()

    Exit 1
}

$message = ("{0}: Closing Chrome." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
Write-Host $message; $message | Out-File -FilePath $logFile -Append

$chromedriver.Close()
$chromedriver.Quit()

$message = ("{0}: Test complete, returning data to LogicMonitor." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
Write-Host $message; $message | Out-File -FilePath $logFile -Append

Write-Host ("LoginSuccess=1")
Write-Host ("LogonDurationMs={0}" -f $duration)

Exit 0
#endregion Main