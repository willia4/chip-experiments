require 'snmp'

SNMP::Manager.open(:host=>'router1', :community=>'main') do |manager|
  response = manager.get(["IF-MIB::ifHCInOctets.2"])

  puts (response.instance_eval { @varbind_list }).first
end