# Copyright 2006-2008 by Mike Bailey. All rights reserved.
Capistrano::Configuration.instance(:must_exist).load do 
  namespace :deprec do
    namespace :iptables do
      
      set(:ssh_port) { 
        Capistrano::CLI.ui.ask "ssh port"
      }

      set(:port_list) {(Capistrano::CLI.ui.ask "Enter a comma separated list of ports to ALLOW").split(',')}
      
      set(:iptables_rules) {'/etc/iptables.up.rules'}
      set(:interfaces) {'/etc/network/interfaces'}
            
      SYSTEM_CONFIG_FILES[:iptables] = [

         {:template => "iptables.up.erb",
           :path => '/etc/iptables.up.rules',
           :mode => 0644,
           :owner => 'root:root'}
    
       ]

      desc "Generate configuration file(s) for memcached"
      task :config_gen do
        SYSTEM_CONFIG_FILES[:iptables].each do |file|
          deprec2.render_template(:iptables, file)
        end
      end
      
      desc 'Deploy configuration files(s) for iptables configuration' 
      task :config do
        deprec2.push_configs(:iptables, SYSTEM_CONFIG_FILES[:iptables])
      end
      
      desc "Generate configuration file(s) for tables"
      task :config_gen do
        SYSTEM_CONFIG_FILES[:iptables].each do |file|
          deprec2.render_template(:iptables, file)
        end
      end

      desc "Load iptables rules and restart networking"
      task :activate_system do
        sudo "grep -q 'iptables-restore' interfaces || echo 'pre-up iptables-restore #{iptables_rules}' >> #{interfaces}"
        sudo "/etc/init.d/networking restart"
      end
      
      
    end
  end
  
end