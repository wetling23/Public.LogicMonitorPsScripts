/*
   NAME: Cisco_IOS_Logs_Collection.groovy
   DESCRIPTION: Connects to the IOS device via ssh using the ssh.user and ssh.pass properties.
   The script will determine if it is in PRIV EXEC mode, which is typically required
   for complete show commands. If it is not in PRIV EXEC mode, check for the
   ssh.enable.pass property. If it exists, use that to enter PRIV EXEC, otherwise use the
   ssh.pass value.

   After in PRIV EXEC, run the ##custom.showlogscommand## command, capturing and returning the output.

   https://github.com/wetling23/Public.LogicMonitorPsScripts/tree/master/ConfigSourceScripts
*/

import com.santaba.agent.groovyapi.expect.Expect;

def host, user, pass
def enable_pass = null
def priv_exec_mode = false
def enable_level = null // This is the assumed default. If the property "config.enable.level" is set, we'll use that value.

def logcommand = hostProps.get("custom.showlogscommand")
logcommand = logcommand.replace("\n","")

def logs = [:]

try {
    host = hostProps.get("system.hostname")
}
catch (all) {
    println "(debug::fatal) Could not retrieve the system.hostname value. Exiting."
    return 1
}

try {
    user = hostProps.get("ssh.user")
}
catch (all) {
    println "(debug::fatal) Could not retrieve the ssh.user device property. This is required for authentication. Exiting."
    return 1
}

try {
    pass = hostProps.get("ssh.pass")
}
catch (all) {
    println "(debug::fatal) Could not retrieve the ssh.pass device property. This is required for authentication. Exiting."
    return 1
}

try {
    enable_pass = hostProps.get("ssh.enable.pass")
}
catch (all){
    println "(debug) Could not retrieve the config.enable.pass device property. This is most likely fine, and implies that the provided user already has sufficient default privileges."
}

try {
    enable_level = hostProps.get("config.enable.level")
}
catch (all) {
    println "(debug) Enable level not defined. This is fine. We'll assume level 15."
}

//println "host: ${host}"
//println "user: ${user}"
//println "pass: ${pass}"
//println "enablepass: ${enable_pass}"
//println "enablelevel: ${enable_level}"

// Open an ssh connection and wait for the prompt
cli = Expect.open(host, user, pass);
cli.expect(">", "#");

// Check to see what the previous expect command matched. This will us which user mode we have been dropped into.
if (cli.matched() == "#") {
    priv_exec_mode = true
}

// Let's determine the console prompt, sans the exec mode identifier.
def prompt = ""
cli.before().eachLine() { line -> if ( !line.isEmpty() ) { prompt = line.trim().replaceFirst("^\\.+", "") } }

//println "prompt: ${prompt}"

// If we are not in privileged exec mode, we need to be in order to show the configurations.
if (!priv_exec_mode) {
    // We need privileged exec mode in order to grab the logs.

    // If an enable_level is specified, send it with the command, otherwise just send "enable".
    if (enable_level) {
        cli.send("enable ${enable_level}\n")
    }
    else {
        cli.send("enable\n")
    }

    // Next check for the Password: prompt. If we get a timeout exception thrown, then something with the enable step failed.
    try {
        cli.expect("Password:")
    }
    catch (TimeoutException) {
        println "(debug::fatal) Timed out waiting for the Password prompt. Exiting."
        return 1
    }

    // If we made it this far, we have received the prompt for a password. If an enable_password has been specified, use it.
    if (enable_pass) {
        cli.send("${enable_pass}\n")
    }
    else {
        cli.send("${pass}\n")
    }

    try {
        cli.expect("#")
    }
    catch (TimeoutException) {
        println "(debug::fatal) Timed out waiting for PRIV EXEC prompt (#) after providing the enable password. Exiting."
        return 1
    }
    catch (all) {
        println "(debug:fatal) Something occurred while waiting for the PRIV EXEC prompt. Exiting."
        println "${all.getMessage()}"
        return 1
    }

    priv_exec_mode = true
}

// Ensure the page-by-page view doesn't foul the log output.
cli.send("terminal length 0\n")
cli.expect("#")
cli.send("terminal width 0\n")
cli.expect("#")

// Display the logs.
//println "running \"${logcommand}\""
cli.send(logcommand + "\n")
cli.expect(prompt)

logs = cli.before()

// Logout from the device.
cli.send("\nexit\n")
cli.expect("#exit")

// Remove the trailing prompt that gets captured, while avoiding the removal of the hostname property.
logs = logs.replaceAll(/(?m)^${prompt}[$,#]/, "")

// Close the ssh connection handle then print the logs.
//cli.expectClose();
println logs

return 0