<#
    .DESCRIPTION
        Uses the auto.exchangeVersion property, to export a list of Exchange servers (hostname and displayName) and their Exchange version, to a .csv file
#>
$accessId = ''
$accessKey = ''
$account = ''
$outPath = 'C:\it\test.csv'

$allDevices = Get-LogicMonitorDevices -AccessId $accessId -AccessKey $accessKey -AccountName $account -BlockLogging

$exchangeServers = Foreach ($server in $alllmdevices) {
    Foreach ($prop in $server.autoproperties) {
        If ($prop.name -eq 'auto.exchangeversion') {
            $objectProperty = [ordered]@{
                LmDisplayName       = $server.displayname
                LmHostName          = $server.hostname
                ExchangeVersion     = $prop.value
            }

            $ourObject = New-Object -TypeName psobject -Property $objectProperty

            $ourObject
        }
    }
}

$exchangeServers | Export-Csv -Path $outPath -NoTypeInformation