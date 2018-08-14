$username = "##wmi.user##"
$password = "##wmi.pass##"
$domainCred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, ($password | ConvertTo-SecureString -AsPlainText -Force)
$server = "##system.hostname##"
$emailDomain = "##synoptek.EmailDomain##"

If ($emailDomain -match "@") {
    $emailDomain = $emailDomain.Trim("@")
}

Try {
    Get-ADUser -Filter "(EmailAddress -like `"*@$emailDomain`") -AND (Enabled -ne 'True') -AND ((SAMAccountName -notlike '*srvc*') -OR (SAMAccountName -notlike '*synadmin*')) -AND (objectCategory -eq 'person') -AND (objectClass -eq 'user')" -Properties EmailAddress, GivenName, Surname, DisplayName, Title, Department, Office, OfficePhone, MobilePhone, Fax, StreetAddress, City, State, PostalCode, Country, Enabled -Credential $domainCred -Server $server -ErrorAction Stop
}
Catch {
    $_.Exception.Message

    Exit 1
}

Exit 0