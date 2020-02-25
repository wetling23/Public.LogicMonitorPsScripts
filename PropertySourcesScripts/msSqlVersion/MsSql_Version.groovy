def hostname = hostProps.get('system.hostname')

String regValue = ('reg query \"\\\\' + hostname + '\\HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Microsoft SQL Server\\Instance Names\\SQL\" -v MSSQLSERVER').execute().text
String instance = regValue.tokenize(' ')[-1]

String regValue2 = ('reg query \"\\\\' + hostname + '\\HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Microsoft SQL Server\\' + instance.replaceAll("[^a-zA-Z0-9_.]+","") + '\\MSSQLServer\\CurrentVersion\" -v CurrentVersion').execute().text
String version = regValue2.tokenize(' ')[-1]

println 'custom.sqlversion=' + version

return 0