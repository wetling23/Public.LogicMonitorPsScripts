/*******************************************************************************
Notes
    V1.0.0.0 date: 12 August 2021
        - Initial release
        - Based on input from Stuart Weenig and Michael Rodrigues (https://communities.logicmonitor.com/topic/7308-trouble-with-fortigate-propertysource-script/)
Link
    https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/PropertySourcesScripts/fortinet
******************************************************************************/

import com.santaba.agent.groovyapi.expect.Expect

hostname = hostProps.get("system.hostname")
userid = hostProps.get("ssh.user")
passwd = hostProps.get("ssh.pass")
def list = new ArrayList()

try {
    try {
        ssh_connection = Expect.open(hostname, userid, passwd)
    }
    catch (all) {
        println "Failed to connect to ${hostname} as ${userid}. Error: ${all.getMessage()}"

        return 1
    }

    //println "Running 'config vdom' command."
    try {
        ssh_connection.expect("# ")
        ssh_connection.send("config vdom\n")
        ssh_connection.expect("# ")
    }
    catch (all) {
        println "Failed to enter vdom config. Error: ${all.getMessage()}"

        return 1
    }

    //println "Collecting the output of 'config vdom'."
    try {
        cmd_output = ssh_connection.before()
    }
    catch (all) {
        println "Failed to collect output. Error: ${all.getMessage()}"

        return 1
    }

    try {
        if (cmd_output =~ /\(vdom\)/) {
            //println "Successfully entered vdom config, running the 'edit' command."
            ssh_connection.send("edit ?\n")
            ssh_connection.expect("# ")
        }
    }
    catch (all) {
        println "Unexpected error running 'edit'. Error: ${all.getMessage()}"

        return 1
    }

    //println "Collecting the output of 'edit'."
    try {
        cmd_output2 = ssh_connection.before()
    }
    catch (all) {
        println "Failed to collect output. Error: ${all.getMessage()}"

        return 1
    }

    //println "Attempting to parse the list of VDOMs."
    try {
        if (cmd_output2.contains("Command fail")) {
            println "No VDOMs in the list variable."

            return 0
        }
        else {
            cmd_output2.eachLine { line ->
                if (!(line =~ /\<vdom\>/) && !(line =~ /^\s*$/) && !(line =~ "edit") && !(line =~ /\(vdom\)/) && !(line =~ /config vdom/)) {
                    //println "Adding '${line}' to the list of configured VDOMs."
                    list.add(line)
                }
            }
        }
    }
    catch (all) {
        println "Unexpected error parsing the list of VDOMs. Error: ${all.getMessage()}"

        return 1
    }

    //println "Exiting VDOM config."
    try {
        ssh_connection.send("\025")
        ssh_connection.send("abort\n")
    }
    catch (all) {
        println "Unexpected error exiting VDOM config. Error: ${all.getMessage()}"

        return 1
    }

    if (list) {
        //println "Returning vdoms:"
        println "fortinet.vdomlist=${list.join(",")}"
    }
    else {
        println "No VDOMs in the list variable."
    }

    return 0
}
catch (Exception e) {println e;return 1}
finally {if (ssh_connection){ssh_connection.expectClose()}}