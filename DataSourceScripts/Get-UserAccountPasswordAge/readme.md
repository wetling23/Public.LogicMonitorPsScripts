# Document description
This DataSource describes the Get-UserAccountPasswordAge DataSource.

# Prerequisites
- The DataSource is written to be run on a LogicMonitor collector running Windows
- For local-account resets, on a remote device, PowerShell remoting must be enabled on the target device
-- If the collector is running on a workgroup machine, the remote machine IP or hostname should be added to the collector's TrustedHosts file
- For domain-account resets, the Active Directory PowerShell module must be installed on the collector
- The PowerShell script in this DataSource, can be run independent of LogicMonitor. In that case, a credential, with access to the target device, will be required

# Function
The PowerShell script in this DataSource queries a give device using either the Active Directory PowerShell module or WMI. The script returns the age (in days) of the provided user's password.
