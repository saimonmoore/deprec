# Copyright 2006-2008 by Mike Bailey. All rights reserved.
Capistrano::Configuration.instance(:must_exist).load do 
  namespace :deprec do 
    namespace :god do
        
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
        deprec2.mkdir(god_dir, :via => :sudo)        
        deprec2.mkdir(god_log_dir, :via => :sudo)        
        deprec2.mkdir(god_pid_dir, :via => :sudo)        
        deprec2.push_configs(:god, SYSTEM_CONFIG_FILES[:god])
      end
      
      task :config_project, :roles => :app do
        deprec2.push_configs(:god, PROJECT_CONFIG_FILES[:god])
        symlink_mongrel_config
        symlink_mysql_config
        symlink_nginx_config
        symlink_nginx_config
        symlink_logrotate_config
      end
      
      task :symlink_mongrel_config, :roles => :app do
        deprec2.mkdir(god_conf_dir, :via => :sudo)
        sudo "ln -sf #{deploy_to}/god/god_mongrel.god #{god_conf_dir}/mongrel_#{application}.god"
      end
      
      task :unlink_mongrel_config, :roles => :app do
        sudo "test -L #{god_conf_dir}/mongrel_#{application}.god && unlink #{god_conf_dir}/mongrel_#{application}.god"
      end
      
      task :symlink_mysql_config, :roles => :app do
        deprec2.mkdir(god_conf_dir, :via => :sudo)
        sudo "ln -sf #{deploy_to}/god/god_mysql.god #{god_conf_dir}/mysql_#{application}.god"
      end
      
      task :unlink_mysql_config, :roles => :app do
        sudo "test -L #{god_conf_dir}/mysql_#{application}.god && unlink #{god_conf_dir}/mysql_#{application}.god"
      end
      
      task :symlink_nginx_config, :roles => :app do
        deprec2.mkdir(god_conf_dir, :via => :sudo)
        sudo "ln -sf #{deploy_to}/god/god_nginx.god #{god_conf_dir}/nginx_#{application}.god"
      end
      
      task :unlink_nginx_config, :roles => :app do
        sudo "test -L #{god_conf_dir}/nginx_#{application}.god && unlink #{god_conf_dir}/nginx_#{application}.god"
      end
      
      task :symlink_thin_config, :roles => :app do
        deprec2.mkdir(god_conf_dir, :via => :sudo)
        sudo "ln -sf #{deploy_to}/god/god_thin.god #{god_conf_dir}/thin_#{application}.god"
      end
      
      task :unlink_thin_config, :roles => :app do
        sudo "test -L #{god_conf_dir}/thin_#{application}.god && unlink #{god_conf_dir}/thin_#{application}.god"
      end
      
      desc "Start god"
      task :start, :roles => :app do
        sudo "/etc/init.d/god start"
      end

      desc "Stop god"
      task :stop, :roles => :app  do
        sudo "/etc/init.d/god stop"
      end

      desc "Restart god"
      task :restart, :roles => :app  do
        send "/etc/init.d/god restart"
      end

      desc "Reload god"
      task :reload, :roles => :app  do
        sudo "/etc/init.d/god reload"
      end
   
      desc <<-DESC
        Activate god start scripts on server.
        Setup server to start god on boot.
      DESC
      task :activate do
        sudo "update-rc.d god defaults"
      end
  
      desc <<-DESC
        Dectivate god start scripts on server.
        Setup server to start god on boot.
      DESC
      task :deactivate do
        sudo "update-rc.d -f god remove"
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