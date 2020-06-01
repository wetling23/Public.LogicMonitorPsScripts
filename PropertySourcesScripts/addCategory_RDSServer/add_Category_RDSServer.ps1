// Get the value of TSAdvertise, from the registry, to determine if a server is operating as a terminal server.

def hostname = hostProps.get('system.hostname')

String regValue = ('reg query \"\\\\' + hostname + '\\HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Control\\Terminal Server\" -v TSAdvertise').execute().text
String outValue = (regValue.tokenize(' ')[-1]).trim() // Need to trim(), because there is some extra character (a \n, I assume) otherwise.

if (outValue == '0x1')
    {
        println 'system.categories=RdsServer'
    }

return 0