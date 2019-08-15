$parentGroupId = ''
$allSites = @(
    'site1'
    'site2'
)

Foreach ($site in $allSites) {
    $props = @{
        name     = $site
        parentId = $parentGroupId
    }

    $newGroup = Add-LogicMonitorDeviceGroup -AccessId $accessid -AccessKey $accesskey -AccountName synoptek -Properties $props -Verbose

    $props = @{
        name     = 'Server'
        parentId = $newGroup.id
    }

    Add-LogicMonitorDeviceGroup -AccessId $accessid -AccessKey $accesskey -AccountName synoptek -Properties $props -Verbose

    $props = @{
        name     = 'Network'
        parentId = $newGroup.id
    }

    Add-LogicMonitorDeviceGroup -AccessId $accessid -AccessKey $accesskey -AccountName synoptek -Properties $props -Verbose
}


