import com.santaba.agent.groovyapi.win32.WMI

// Initialize variables.
def hostname = "##system.hostname##"
def service = "##WILDVALUE##"
def namespace = "CIMv2";
def timeout = 30;

// Try the following code.
try
{
    // This is our WMI query.
    def wmi_query = "select state from win32_service where name ='" + service + "'";

    // maybe you only want the first result (same parameters as queryAll())
    def first_result = WMI.queryFirst(hostname, namespace, wmi_query, timeout)

    switch (first_result.STATE) {
        case "Running":
            return 0;
            break
        default:
            return 1;
            break
    }
}
// Catch any exceptions that may have occurred.
catch (Exception e)
{
    // Print exception out.
    println e
    return 1;
}