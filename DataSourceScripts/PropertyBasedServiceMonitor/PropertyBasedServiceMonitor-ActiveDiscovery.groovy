import com.santaba.agent.groovyapi.win32.WMI

// Initialize variables.
def hostname = "##system.hostname##"
def definedServices = "##custom.MonitoredServices##"
def List<String> services = definedServices.tokenize(',')
def namespace = "CIMv2";
def timeout = 30;

if (services.contains('SYN_Windows_Basic_Services')) {
    // Replace the string 'SYN_Windows_Basic_Services', with the actual services.
    services.remove('SYN_Windows_Basic_Services')
    services.add('lanmanserver')
    services.add('lanmanworkstation')
    services.add('LmHosts')
    services.add('RpcSs')
    services.add('SamSs')
    services.add('winmgmt')
}

for (String item : services) {
    // Try the following code.
    try
    {
        // This is our WMI query.
        //def wmi_query = 'select * from win32_operatingsystem';
        def wmi_query = "select name from win32_service where name ='" + item + "'";

        // maybe you only want the first result (same parameters as queryAll())
        def first_result = WMI.queryFirst(hostname, namespace, wmi_query, timeout)

        if (first_result.NAME)
        {
            // The service is installed.
            println first_result.NAME + "##" + first_result.NAME
        }
    }
    // Catch any exceptions that may have occurred.
    catch (Exception e)
    {
        // Don't do anything.
    }
}