# Copyright 2006-2008 by Mike Bailey. All rights reserved.
Capistrano::Configuration.instance(:must_exist).load do 
  namespace :deprec do 
    namespace :god do
        
      set :god_user,  'god'
      set :god_group, 'god'
      set(:god_log_dir) { "#{deploy_to}/shared/log" }
      set(:god_pid_dir) { "#{deploy_to}/shared/pids" }
      set :god_dir, '/etc/god'
      set :god_conf_dir, '/etc/god/conf'
      set(:god_conf) { "/etc/god/god.conf" }
  
      set :god_check_interval, 60
      set :god_log, 'syslog facility log_daemon'
      set :god_mailserver, nil
      set :god_mail_from, "god@#{domain}"
      set :god_alert_recipients, %w(root@localhost)
      set :god_timeout_recipients, %w(root@localhost)
      set :god_webserver_enabled, true
      set :god_webserver_port, 2812
      set :god_webserver_address, 'localhost'
      set :god_webserver_allowed_hosts_and_networks, %w(localhost)
      set :god_webserver_auth_user, 'admin'
      set :god_webserver_auth_pass, 'god'
  
      # Install 
      
      desc "Install god"
      task :install, :roles => :app do
        gem2.install 'god'
      end
      
      task :symlink_logrotate_config, :roles => :web do
        sudo "ln -sf /etc/god/logrotate.conf /etc/logrotate.d/god-#{application}"
      end
  
    
      SYSTEM_CONFIG_FILES[:god] = [
    
        {:template => 'god-init-script',
         :path => '/etc/init.d/god',
         :mode => 0755,
         :owner => 'root:root'},
         
        {:template => 'god.conf.erb',
         :path => '/etc/god',
         :mode => 0755,
         :owner => 'root:root'}         
      ]
      
      PROJECT_CONFIG_FILES[:god] = [

        {:template => 'god_mongrel.god.erb',
         :path => 'god_mongrel.god',
         :mode => 0644,
         :owner => 'root:root'},

        {:template => 'god_mysql.god.erb',
         :path => "god_mysql.god", 
         :mode => 0600,
         :owner => 'root:root'},
         
        {:template => 'god_nginx.god.erb',
         :path => "god_nginx.god", 
         :mode => 0600,
         :owner => 'root:root'},         
         
        {:template => 'god_thin.god.erb',
         :path => "god_thin.god", 
         :mode => 0600,
         :owner => 'root:root'},         
         
        {:template => 'logrotate.conf.erb',
         :path => "logrotate.conf", 
         :mode => 0644,
         :owner => 'root:root'}
      
      ]      
  
      desc "Generate configuration file(s) for god from template(s)"
      task :config_gen do
        config_gen_system
        config_gen_project
      end
      
      task :config_gen_system do
        SYSTEM_CONFIG_FILES[:god].each do |file|
          deprec2.render_template(:god, file)
        end  
      end
      
      task :config_gen_project do
        PROJECT_CONFIG_FILES[:god].each do |file|
          deprec2.render_template(:god, file)
        end  
      end
      
      desc 'Deploy configuration files(s) for god' 
      task :config, :roles => :app do
        config_system
        config_project
      end
      
      task :config_system, :roles => :app do
        deprec2.push_configs(:god, SYSTEM_CONFIG_FILES[:god])
      end
      
      task :config_project, :roles => :app do
        create_god_user_and_group
        deprec2.push_configs(:god, PROJECT_CONFIG_FILES[:god])
        symlink_mongrel_cluster
        symlink_monit_config
        symlink_logrotate_config
      end
      
      task :symlink_monit_config, :roles => :app do
        deprec2.mkdir(monit_confd_dir, :via => :sudo)
        sudo "ln -sf #{deploy_to}/mongrel/monit.conf #{monit_confd_dir}/mongrel_#{application}.conf"
      end
      
      task :unlink_monit_config, :roles => :app do
        sudo "test -L #{monit_confd_dir}/mongrel_#{application}.conf && unlink #{monit_confd_dir}/mongrel_#{application}.conf"
      end
      
      
      desc "create user and group for god to run as"
      task :create_god_user_and_group, :roles => :app do
        deprec2.groupadd(god_group) 
        deprec2.useradd(god_user, :group => god_group, :homedir => false)
        # Set the primary group for the mongrel user (in case user already existed
        # when previous command was run)
        sudo "usermod --gid #{god_group} #{god_user}"
      end
      
      desc "set group ownership and permissions on dirs god needs to write to"
      task :set_perms_for_god_dirs, :roles => :app do
        tmp_dir = "#{deploy_to}/current/tmp"
        shared_dir = "#{deploy_to}/shared"
        files = ["#{god_log_dir}/god.log"]

        sudo "chgrp -R #{god_group} #{tmp_dir} #{shared_dir}"
        sudo "chmod -R g+w #{tmp_dir} #{shared_dir}" 
        # set owner and group of log files 
        files.each { |file|
          sudo "touch #{file}"
          sudo "chown #{god_user} #{file}"   
          sudo "chgrp #{god_group} #{file}" 
          sudo "chmod g+w #{file}"   
        } 
      end            

      desc "Start god"
      task :start, :roles => :app do
        send(run_method, "/home/techimp/testing/etc/init.d/god start")
      end

      desc "Stop god"
      task :stop, :roles => :app  do
        send(run_method, "/home/techimp/testing/etc/init.d/god stop")
      end

      desc "Restart god"
      task :restart, :roles => :app  do
        send(run_method, "/home/techimp/testing/etc/init.d/god restart")
      end

      desc "Reload god"
      task :reload, :roles => :app  do
        send(run_method, "/home/techimp/testing/etc/init.d/god reload")
      end
   
      desc <<-DESC
        Activate god start scripts on server.
        Setup server to start god on boot.
      DESC
      task :activate do
        send(run_method, "update-rc.d god defaults")
      end
  
      desc <<-DESC
        Dectivate god start scripts on server.
        Setup server to start god on boot.
      DESC
      task :deactivate do
        send(run_method, "update-rc.d -f god remove")
      end
  
      task :backup do
        # there's nothing to backup for god
      end
  
      task :restore do
        # there's nothing to restore for god
      end

    end 
  end
end