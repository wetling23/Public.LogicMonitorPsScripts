<#
    .DESCRIPTION
        Log into the SuccessWareASP XenApp page. Return 1 if successful, return 0 if the login fails.
    .NOTES
        Author: Mike Hashemi
        V1.0.0.0 date: 1 October 2020
    .LINK
        https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/DataSourceScripts/Selenium/SuccessWareASP
#>

#region Setup
# Initialize variables.
$computerName = '##system.hostname##'
$url = '##successware.url##'
$username = '##successware.user##'
$pass = @'
##successware.pass##
'@
$cred = New-Object System.Management.Automation.PSCredential ($username, $($pass | ConvertTo-SecureString -AsPlainText -Force))

Function Stop-ChromeDriver { Get-Process -Name chromedriver -ErrorAction SilentlyContinue | Stop-Process -ErrorAction SilentlyContinue }

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

$message = ("{0}: Creating Chrome driver." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
Write-Host $message; $message | Out-File -FilePath $logFile -Append

Try {
    # Invoke Selenium into our script!
    $env:PATH += ";C:\it\selenium\" # Adds the path for ChromeDriver.exe to the environmental variable 
    Add-Type -Path "C:\it\selenium\WebDriver.dll" # Adding Selenium's .NET assembly (dll) to access it's classes in this PowerShell session
    $ChromeDriver = New-Object OpenQA.Selenium.Chrome.ChromeDriver # Creates an instance of this class to control Selenium and stores it in an easy to handle variable
}
Catch {
    $message = ("{0}: Unexpected error creating Chrome driver. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
    Write-Host $message; $message | Out-File -FilePath $logFile -Append

    Exit 1
}

$message = ("{0}: Attempting to load {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $url)
Write-Host $message; $message | Out-File -FilePath $logFile -Append

Try {
    $ChromeDriver.Navigate().GoToURL($Url)
    $ChromeDriver.FindElementByName("user").SendKeys($cred.Username) # Methods to find the input textbox for the username and type it into the textbox
    $ChromeDriver.FindElementByName("password").SendKeys($cred.GetNetworkCredential().password) # Methods to find the input textbox for the password and type it into the textbox
    $ChromeDriver.FindElementByName("password").Submit() # We are submitting this info to linkedin for login # From the same textbox, submit this information to Linkedin for logging in
}
Catch {
    $message = ("{0}: Unexpected error loading {1}. Error: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $url, $_.Exception.Message)
    Write-Host $message; $message | Out-File -FilePath $logFile -Append

    $ChromeDriver.Close()
    $ChromeDriver.Quit()
    Stop-ChromeDriver # Function to make sure Chromedriver process is really ended.

    Write-Host ("LoginSuccess=0")

    Exit 0
}

# Giving the page time to load.
Start-Sleep 10

$message = ("{0}: Looking for log off link." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
Write-Host $message; $message | Out-File -FilePath $logFile -Append

Try {
    $link = $ChromeDriver.FindElementById("logoffLink")
    $link.click()

    $ChromeDriver.Close()
    $ChromeDriver.Quit()
    Stop-ChromeDriver # Function to make sure Chromedriver process is really ended.

    Write-Host ("LoginSuccess=1")

    Exit 0
}
Catch {
    $message = ("{0}: Looking for log off link." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    Write-Host $message; $message | Out-File -FilePath $logFile -Append

    Write-Host ("LoginSuccess=0")

    Exit 0
}
#endregion Main