# Copyright 2006-2008 by Mike Bailey. All rights reserved.
Capistrano::Configuration.instance(:must_exist).load do 
  namespace :deprec do namespace :god do
        
  set :god_user,  'god'
  set :god_group, 'god'
  set :god_confd_dir, '/home/techimp/testing/etc/god'
  
  set :god_check_interval, 60
  set :god_log, 'syslog facility log_daemon'
  set :god_mailserver, nil
  set :god_mail_from, 'god@deprec.enabled.slice'
  set :god_alert_recipients, %w(root@localhost)
  set :god_timeout_recipients, %w(root@localhost)
  set :god_webserver_enabled, true
  set :god_webserver_port, 2812
  set :god_webserver_address, 'localhost'
  set :god_webserver_allowed_hosts_and_networks, %w(localhost)
  set :god_webserver_auth_user, 'admin'
  set :god_webserver_auth_pass, 'god'
  
  desc "Install god"
  task :install do
    # install_deps
    gem2.install 'god'
  end
  
  task :install_deps do
    # there are no dependencies for god
  end
    
  SYSTEM_CONFIG_FILES[:god] = [
    
    {:template => 'god-init-script',
     :path => '/home/techimp/testing/etc/init.d/god',
     :mode => 0755,
     :owner => 'root:root'},
     
    {:template => 'nothing',
     :path => "/home/techimp/testing/etc/god/nothing",
     :mode => 0700,
     :owner => 'root:root'}
  ]
  
  desc <<-DESC
  Generate nginx config from template. Note that this does not
  push the config to the server, it merely generates required
  configuration files. These should be kept under source control.            
  The can be pushed to the server with the :config task.
  DESC
  task :config_gen do
    SYSTEM_CONFIG_FILES[:god].each do |file|
      deprec2.render_template(:god, file)
    end
  end
  
  desc "Push god config files to server"
  task :config do
    deprec2.push_configs(:god, SYSTEM_CONFIG_FILES[:god])
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

  end end
end