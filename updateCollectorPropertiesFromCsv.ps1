$lmAccessId = ''
$lmAccessKey = ''
$lmAccountName = ''
$collectorList = Import-Csv -Path c:\it\allCollectors.csv

Foreach ($coll in $collectorList) {
   # $params = @{}
    $params = @{"description" = $coll.description; "escalatingChainId" = 1}

    If ($coll.backupAgentId -ne 0) {
        $params.Add("backupAgentId", $coll.backupAgentId)
    }

    If ($coll.enableFailBack -eq $True) {
        $params.Add("enableFailBack", $True)
    }

    If ($coll.resendIval -ne 15) {
        $params.Add("resendIval", $coll.resendIval)
    }

    If ($coll.enableFailOverOnCollectorDevice -ne "False") {
        $params.Add("enableFailOverOnCollectorDevice", $True)
    }

    Update-LogicMonitorCollectorProperties -AccessId $lmAccessId -AccessKey $lmAccessKey -AccountName $lmAccountName -CollectorId $coll.id -PropertyNames $params.keys -PropertyValues $params.values -Verbose -Blocklogging -OpType PATCH | Out-File c:\it\log2.txt -Append
}