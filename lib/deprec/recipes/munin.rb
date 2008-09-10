# Copyright 2006-2008 by Mike Bailey. All rights reserved.
Capistrano::Configuration.instance(:must_exist).load do 
  namespace :deprec do
    namespace :munin do
            
      desc "Install munin"
      task :install do
        install_deps
      end
      
      desc "Post-Munin Tasks"
      task :post_munin do
        htpass
        puts "You must link /var/www/html/munin to a web-accessible location."
      end
               
      # Install dependencies for munin
      task :install_deps do
        apt.install( {:base => %w(apache2 munin-node munin)}, :stable )
      end
      
      SYSTEM_CONFIG_FILES[:munin] = [
        
        {:template => 'munin.conf.erb',
        :path => '/etc/munin/munin.conf',
        :mode => 0664,
        :owner => 'munin:munin'},
        
        {:template => 'munin-node.conf.erb',
        :path => '/etc/munin/munin-node.conf',
        :mode => 0664,
        :owner => 'munin:munin'},        
        
        {:template => 'munin_nginx_vhost.conf.erb',
         :path => "#{nginx_vhost_dir}/munin.conf",
         :mode => 0664,
         :owner => 'root:root'}
      
      ]

      desc "Generate configuration file(s) for munin from template(s)"
      task :config_gen do
        SYSTEM_CONFIG_FILES[:munin].each do |file|
          deprec2.render_template(:munin, file)
        end
        
        sudo "/etc/init.d/nginx reload"
      end
      
      desc "Push munin config files to server"
      task :config, :roles => :munin do
        deprec2.push_configs(:munin, SYSTEM_CONFIG_FILES[:munin])
        restart
      end
      
      desc "Set Munin to start on boot"
      task :activate, :roles => :munin do
        send(run_method, "update-rc.d munin defaults")
      end
      
      desc "Set munin to not start on boot and delete nginx config file"
      task :deactivate, :roles => :munin do
        send(run_method, "update-rc.d -f munin remove")
        link = "#{nginx_vhost_dir}/munin.conf"
        sudo "test -h #{link} && sudo rm #{link} || true"
        sudo "/etc/init.d/nginx reload"
      end
      
      desc "Upload and configure desired plugins for munin."
      task :munin_plugins do
        # Reset
        sudo "rm -f /etc/munin/plugins/*"

        # Configure
        {
          "cpu" => "cpu",
          "df" => "df",
          "fw_packets" => "fw_packets",
          "if_eth0" => "if_",
          "if_eth1" => "if_",
          "load" => "load",
          "memory" => "memory",
          "mysql_bytes" => "mysql_bytes",
          "mysql_queries" => "mysql_queries",
          "mysql_slowqueries" => "mysql_slowqueries",
          "mysql_threads" => "mysql_threads",
          "netstat" => "netstat",
          "processes" => "processes",
          "swap" => "swap",
          "users" => "users",
        }.each do |name, source|
          sudo "ln -s /usr/share/munin/plugins/#{source} /etc/munin/plugins/#{name}"
        end
        sudo "/etc/init.d/munin-node restart"
      end      
      
      # Control

      desc "Start munin"
      task :start, :roles => :munin do
        send(run_method, "/etc/init.d/munin start")
        send(run_method, "/etc/init.d/munin-node start")
      end

      desc "Stop munin"
      task :stop, :roles => :munin do
        send(run_method, "/etc/init.d/munin stop")
        send(run_method, "/etc/init.d/munin-node stop")
      end

      desc "Restart munin"
      task :restart, :roles => :munin do
        send(run_method, "/etc/init.d/munin restart")
        send(run_method, "/etc/init.d/munin-node restart")
      end

      desc "Reload munin"
      task :reload, :roles => :munin do
        send(run_method, "/etc/init.d/munin reload")
        send(run_method, "/etc/init.d/munin-node reload")
      end
      
      
      #
      # Service specific tasks
      #
      
      # XXX quick and dirty - clean up later
      desc "Grant a user access to the web interface"
      task :htpass, :roles => :munin do
        target_user = Capistrano::CLI.ui.ask "Userid" do |q|
          q.default = 'muninadmin'
        end
        system "htpasswd #{nginx_conf_dir}/htpasswd #{target_user}"
      end
    
  end
end    
