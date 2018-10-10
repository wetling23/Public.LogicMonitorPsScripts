# Active Discovery script.
[string]$pathList = '##custom.folderRoots##'
[System.Collections.ArrayList]$paths = $pathList.Split(',')

Foreach ($path in $paths) {
    Write-Host "$path##$path"
}



# DataSource script.
# Initialize variables.
$path = "##WildValue##"
$server = '##system.hostname##'
$user = '##wmi.user##'
$pass = '##wmi.pass##'
$secpasswd = ConvertTo-SecureString -String $pass -AsPlainText -Force
$mycreds = New-Object System.Management.Automation.PSCredential ($user, $secpasswd)
$current = (Get-Item WSMan:\localhost\Client\TrustedHosts).Value

If ($current.length -gt 0) {
    If ($current -notmatch $server) {
        $current += ",$server"
    }
}
Else {
    $current = "$server"
}
Set-Item WSMan:\localhost\Client\TrustedHosts -Value $current -Force

$count = Invoke-Command -ComputerName $server {(Get-ChildItem $args[0] -Recurse -ErrorAction SilentlyContinue | Where-Object {(-NOT $_.PSIsContainer) -and $_.LastWriteTime -gt (Get-Date).AddMinutes(-30)}).count} -Credential $mycreds -ArgumentList $path

Write-Host $count