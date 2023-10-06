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
        V1.0.0.5 date: 12 September 2022
        V2023.10.06.0
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

Function Test-BrowserDriverVersion {
    <#
        .DESCRIPTION
            Accept a browser and check if the installed version matches the available browser driver .exe file. If not, attempt to download the latest stable browser driver .exe file.
        .NOTES
            Author: Mike Hashemi
            V2023.02.02.0
            V2023.02.02.1
            V2023.10.06.0
        .LINK
            https://github.com/Synoptek-ServiceEnablement/Synoptek.PsIntegrations/blob/master/Selenium/
        .PARAMETER BrowserDriverDir
            The directory in which the browser driver (e.g. chromedriver.exe) is stored.
        .PARAMETER Browser
            The browser, to test for version compatiblity.
        .PARAMETER EventLogSource
            When included, (and when LogPath is null), represents the event log source for the Application log. If no event log source or path are provided, output is sent only to the host.
        .PARAMETER LogPath
            When included (when EventLogSource is null), represents the file, to which the function will output will be logged. If no path or event log source are provided, output is sent only to the host.
        .EXAMPLE
            PS C:\> Test-BrowserDriverVersion -BrowserDriverDir C:\it\selenium -Browser Chrome

            In this example, the function will check the installed version of Chrome against the version of chromedriver.exe stored in C:\it\selenium. If the versions do not match, the function will try to download the latest chromedriver.exe. Logging output is written to the host only.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateScript( {
                If (-NOT ($_ | Test-Path) ) {
                    Throw "File or folder does not exist."
                }
                If (-NOT ($_ | Test-Path -PathType Container) ) {
                    Throw "The Path argument must be a folder. Folder paths are not allowed."
                }
                Return $true
            })]
        [System.IO.FileInfo]$BrowserDriverDir,

        [Parameter(Mandatory)]
        [ValidateSet('Chrome', 'Edge')]
        $Browser,

        [string]$EventLogSource,

        [string]$LogPath
    )

    Try {
        #region Initialize variables
        $date = ([datetime]::Now).ToString("yyyy-MM-dd`THH-mm-ss")
        $driverName = $(If ($Browser -eq 'Chrome') { 'chromedriver.exe' } ElseIf ($Browser -eq 'Edge') { 'msedgedriver.exe' })
        $browserVersionRegex = $(If ($Browser -eq 'Chrome') { 'ChromeDriver (\d+\.\d+\.\d+(\.\d+)?)' } ElseIf ($Browser -eq 'Edge') { 'Microsoft Edge WebDriver (\d+\.\d+\.\d+(\.\d+)?)' })
        $processName = $(If ($Browser -eq 'Chrome') { 'chromedriver' } ElseIf ($Browser -eq 'Edge') { 'msedgedriver' })
        #endregion Initialize variables

        $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
        If ($LogPath) { Write-Host $message; $message | Out-File -FilePath $logFile -Append } ElseIf ($EventLogSource) { <#Not supporting this right now, maybe later.#> } Else { Write-Host $message; }

        #region Test browser/driver version match
        If ($Browser -eq 'Chrome') {
            If (Test-Path -Path "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe") {
                $browserExePath = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
                $architecture = 'win32'
            } ElseIf (Test-Path -Path "C:\Program Files\Google\Chrome\Application\chrome.exe") {
                $browserExePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
                $architecture = 'win64'
            } Else {
                $message = ("{0}: Google Chrome not installed. {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
                If ($LogPath) { Write-Error $message; $message | Out-File -FilePath $logFile -Append } ElseIf ($EventLogSource) { <#Not supporting this right now, maybe later.#> } Else { Write-Error $message; }
            }
        } ElseIf ($Browser -eq 'Edge') {
            If (Test-Path -Path "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe") {
                $browserExePath = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
            } ElseIf (Test-Path -Path "C:\Program Files\Microsoft\Edge\Application\msedge.exe") {
                $browserExePath = "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
            } Else {
                $message = ("{0}: Microsoft Edge not installed. {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
                If ($LogPath) { Write-Error $message; $message | Out-File -FilePath $logFile -Append } ElseIf ($EventLogSource) { <#Not supporting this right now, maybe later.#> } Else { Write-Error $message; }
            }
        }

        $message = ("{0}: {1} is installed at: {2}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $Browser, $browserExePath)
        If ($LogPath) { Write-Host $message; $message | Out-File -FilePath $logFile -Append } ElseIf ($EventLogSource) { <#Not supporting this right now, maybe later.#> } Else { Write-Host $message; }

        $driverFileLocation = $(Join-Path $BrowserDriverDir $driverName)

        $browserVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($browserExePath).FileVersion
        $browserMajorVersion = $browserVersion.split(".")[0]

        If (-NOT($browserMajorVersion -gt 0)) {
            $message = ("{0}: {1} not installed. {2} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $Browser, $MyInvocation.MyCommand)
            If ($LogPath) { Write-Error $message; $message | Out-File -FilePath $logFile -Append } ElseIf ($EventLogSource) { <#Not supporting this right now, maybe later.#> } Else { Write-Error $message; }

            Return 1
        }

        If (Test-Path -Path $driverFileLocation -ErrorAction SilentlyContinue) {
            $message = ("{0}: Getting the version of {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $driverName)
            If ($LogPath) { Write-Host $message; $message | Out-File -FilePath $logFile -Append } ElseIf ($EventLogSource) { <#Not supporting this right now, maybe later.#> } Else { Write-Host $message; }

            $driverFileVersion = (& $driverFileLocation --version)
            $driverFileVersionHasMatch = $driverFileVersion -match $browserVersionRegex

            If (-NOT $driverFileVersionHasMatch) {
                $message = ("{0}: No {1} version identified. To prevent errors, {2} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $driverName, $MyInvocation.MyCommand)
                If ($LogPath) { Write-Error $message; $message | Out-File -FilePath $logFile -Append } ElseIf ($EventLogSource) { <#Not supporting this right now, maybe later.#> } Else { Write-Error $message; }

                Return 1
            } Else {
                $driverCurrentVersion = $matches[1]

                $message = ("{0}: The installed version of the browser driver is: {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $driverCurrentVersion)
                If ($LogPath) { Write-Host $message; $message | Out-File -FilePath $logFile -Append } ElseIf ($EventLogSource) { <#Not supporting this right now, maybe later.#> } Else { Write-Host $message; }
            }
        } Else {
            $message = ("{0}: {1} not found. {2} will attempt to download it." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $driverName, $MyInvocation.MyCommand)
            If ($LogPath) { Write-Host $message; $message | Out-File -FilePath $logFile -Append } ElseIf ($EventLogSource) { <#Not supporting this right now, maybe later.#> } Else { Write-Host $message; }

            $driverCurrentVersion = '' # Need this here, to compare versions later.
        }
        #endregion Test browser/driver version match

        #region Id browser driver URL
        $message = ("{0}: Identifying the latest available version of the browser driver." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        If ($LogPath) { Write-Host $message; $message | Out-File -FilePath $logFile -Append } ElseIf ($EventLogSource) { <#Not supporting this right now, maybe later.#> } Else { Write-Host $message; }

        $driverExpectedVersion = $(If ($Browser -eq 'Chrome') { $browserVersion.split(".")[0..2] -join "." } ElseIf ($Browser -eq 'Edge') { $browserVersion.split(".")[0..3] -join "." })

        If ($Browser -eq 'Chrome') {
            If ($browserMajorVersion -ge 115) {
                # The driver download page changed after version 115.
                $html = (Invoke-WebRequest -Uri 'https://googlechromelabs.github.io/chrome-for-testing/#stable' -UseBasicParsing).Content
                $regexPattern = "<code>chromedriver</code><th><code>$architecture</code><td><code>(.*?)</code><td><code>200</code>"
                $match = [regex]::Match($html, $regexPattern)

                If ($match.Success) {
                    $driverZipLink = $match.Groups[1].Value
                    $regexPattern = '/(\d+\.\d+\.\d+\.\d+)/'
                    $match = [regex]::Match($driverZipLink, $regexPattern)

                    If ($match.Success) {
                        $driverLatestVersion = $match.Groups[1].Value
                    } Else {
                        $message = ("{0}: Unexpected condition. To prevent errors, {2} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
                        If ($LogPath) { Write-Error $message; $message | Out-File -FilePath $logFile -Append } ElseIf ($EventLogSource) { <#Not supporting this right now, maybe later.#> } Else { Write-Error $message; }

                        Return 1
                    }
                } Else {
                    $message = ("{0}: No URL found, from which to download the updated driver. To prevent errors, {2} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
                    If ($LogPath) { Write-Error $message; $message | Out-File -FilePath $logFile -Append } ElseIf ($EventLogSource) { <#Not supporting this right now, maybe later.#> } Else { Write-Error $message; }

                    Return 1
                }
            } Else {
                $driverLatestVersion = Invoke-RestMethod -Uri ("https://chromedriver.storage.googleapis.com/LATEST_RELEASE_{0}" -f $driverExpectedVersion) -UseBasicParsing
            }
        } ElseIf ($Browser -eq 'Edge') {
            # Read the Edge webdriver page, looking for the latest version in the stable channel
            $edgeSiteCode = Invoke-WebRequest -UseBasicParsing -Uri 'https://developer.microsoft.com/en-us/microsoft-edge/tools/webdriver/'

            If ($edgeSiteCode.Content -match 'stable channel,.*\n.*version \d+\.\d+\.\d+\.\d+') {
                If ($matches[0] -match 'version.*') {
                    $driverLatestVersion = ($matches[0] -split ' ')[1]
                }
            }
        }

        $message = ("{0}: The latest browser driver version is: {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $driverLatestVersion)
        If ($LogPath) { Write-Host $message; $message | Out-File -FilePath $logFile -Append } ElseIf ($EventLogSource) { <#Not supporting this right now, maybe later.#> } Else { Write-Host $message; }
        #endregion Id browser driver URL

        #region Download browser driver
        If ($driverCurrentVersion -ne $driverLatestVersion) {
            $message = ("{0}: {1} does not match the installed version of {2}, attempting to download the correct driver file." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $driverName, $Browser)
            If ($LogPath) { Write-Host $message; $message | Out-File -FilePath $logFile -Append } ElseIf ($EventLogSource) { <#Not supporting this right now, maybe later.#> } Else { Write-Host $message; }

            If ($Browser -eq 'Chrome') {
                If ($browserMajorVersion -ge 115) {
                    # $driverZipLink was defined above, nothing to do here.
                } Else { $driverZipLink = ("https://chromedriver.storage.googleapis.com/{0}/chromedriver_$architecture.zip" -f $driverLatestVersion) }
            } ElseIf ($Browser -eq 'Edge') {
                $driverZipLink = ("https://msedgedriver.azureedge.net/{0}/edgedriver_$architecture.zip" -f $driverLatestVersion)
            }

            $message = ("{0}: Attempting to download from {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $driverZipLink)
            If ($LogPath) { Write-Host $message; $message | Out-File -FilePath $logFile -Append } ElseIf ($EventLogSource) { <#Not supporting this right now, maybe later.#> } Else { Write-Host $message; }

            Try {
                If (Get-Process -Name $processName -ErrorAction SilentlyContinue) {
                    $message = ("{0}: Attempting to stop {1} before extracting the replacement." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $processName)
                    If ($LogPath) { Write-Host $message; $message | Out-File -FilePath $logFile -Append } ElseIf ($EventLogSource) { <#Not supporting this right now, maybe later.#> } Else { Write-Host $message; }

                    Try {
                        Get-Process -Name $processName | Stop-Process -Force
                    } Catch {
                        $message = ("{0}: Unexpected error stopping {1}. Error: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $processName, $_.Exception.Message)
                        If ($LogPath) { Write-Host $message; $message | Out-File -FilePath $logFile -Append } ElseIf ($EventLogSource) { <#Not supporting this right now, maybe later.#> } Else { Write-Host $message; }

                        Return 1
                    }
                }

                (New-Object System.Net.WebClient).DownloadFile($driverZipLink, ("$(($BrowserDriverDir.FullName).TrimEnd('\'))\{0}driver_{1}.zip" -f $browser, $date))
            } Catch {
                $message = ("{0}: Unexpected error downloading the file. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
                If ($LogPath) { Write-Error $message; $message | Out-File -FilePath $logFile -Append } ElseIf ($EventLogSource) { <#Not supporting this right now, maybe later.#> } Else { Write-Error $message; }

                Return 1
            }
        } Else {
            $message = ("{0}: {1} is up-to-date." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $driverName)
            If ($LogPath) { Write-Host $message; $message | Out-File -FilePath $logFile -Append } ElseIf ($EventLogSource) { <#Not supporting this right now, maybe later.#> } Else { Write-Host $message; }

            Return 0
        }
        #endregion Download browser driver

        #region Extract browser driver
        $message = ("{0}: Attempting to extract {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $driverName)
        If ($LogPath) { Write-Host $message; $message | Out-File -FilePath $logFile -Append } ElseIf ($EventLogSource) { <#Not supporting this right now, maybe later.#> } Else { Write-Host $message; }

        Try {
            Expand-Archive -Path ("$(($BrowserDriverDir.FullName).TrimEnd('\'))\{0}driver_{1}.zip" -f $browser, $date) -DestinationPath $BrowserDriverDir.FullName -Force -ErrorAction Stop
            Remove-Item -Path ("$(($BrowserDriverDir.FullName).TrimEnd('\'))\{0}driver_{1}.zip" -f $browser, $date) -Force -ErrorAction Continue

            If (-NOT (Test-Path -Path "$($BrowserDriverDir.FullName)\$driverName")) {
                Try {
                    Get-ChildItem -Path $BrowserDriverDir.FullName -Recurse -Include $driverName | Move-Item -Destination $BrowserDriverDir -ErrorAction Stop
                    Remove-Item
                } Catch {
                    $message = ("{0}: Unexpected error searching for and/or moving {1} to {2}. Error: {3}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $driverName, $BrowserDriverDir.FullName, $_.Exception.Message)
                    If ($LogPath) { Write-Error $message; $message | Out-File -FilePath $logFile -Append } ElseIf ($EventLogSource) { <#Not supporting this right now, maybe later.#> } Else { Write-Error $message; }

                    Return 1
                }
            }

            $message = ("{0}: {1} updated to version {2}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $driverName, (& $driverFileLocation --version))
            If ($LogPath) { Write-Host $message; $message | Out-File -FilePath $logFile -Append } ElseIf ($EventLogSource) { <#Not supporting this right now, maybe later.#> } Else { Write-Host $message; }

            Return 0
        } Catch {
            $message = ("{0}: Unexpected error extracting {1}. Error: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $driverName, $_.Exception.Message)
            If ($LogPath) { Write-Error $message; $message | Out-File -FilePath $logFile -Append } ElseIf ($EventLogSource) { <#Not supporting this right now, maybe later.#> } Else { Write-Error $message; }

            Return 1
        }
        #endregion Extract browser driver
    } Catch {
        $message = ("{0}: Unexpected error in {1}. The error occurred at line {2}, the command was `"{3}`", and the specific error is: {4}" -f `
            ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.MyCommand.Name, $_.Exception.Message)
        If ($LogPath) { Write-Host $message; $message | Out-File -FilePath $logFile -Append } ElseIf ($EventLogSource) { <#Not supporting this right now, maybe later.#> } Else { Write-Host $message; }

        Return 1
    }
}

If (Test-Path -Path "${env:ProgramFiles}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
} ElseIf (Test-Path -Path "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" -ErrorAction SilentlyContinue) {
    $logDirPath = "${env:ProgramFiles(x86)}\LogicMonitor\Agent\Logs" # Directory, into which the log file will be written.
} Else {
    $logDirPath = "$([System.Environment]::SystemDirectory)" # Directory, into which the log file will be written.
}
$logFile = "$logDirPath\datasource-SuccessWareASP_Login_Availability-collection-$computerName.log"
#endregion Setup

#region Main
$message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
Write-Host $message; $message | Out-File -FilePath $logFile

$result = Test-BrowserDriverVersion -BrowserDriverDir $seleniumPath -Browser Chrome

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