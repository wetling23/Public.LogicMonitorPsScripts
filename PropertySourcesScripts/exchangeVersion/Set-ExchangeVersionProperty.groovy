import com.santaba.agent.groovyapi.win32.WMI;
import com.santaba.agent.groovyapi.win32.WMISession;

hostname=hostProps.get("system.hostname");
my_query="Select * FROM Win32_Product where Name = 'Microsoft Exchange Server'"

def session = WMI.open(hostname);
def obj = session.queryFirst("CIMv2", my_query, 100); 

println "ExchangeVersion=" + obj.VERSION;
return 0