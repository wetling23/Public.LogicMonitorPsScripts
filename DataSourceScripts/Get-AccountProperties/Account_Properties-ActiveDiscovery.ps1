$accounts = '##custom.pwchangeaccts##'

If ($accounts -match ',') {
    $accounts = $accounts.Split(',')
}

Foreach ($account in $accounts) {
    Write-Host "$account##$account"
}

Exit 0