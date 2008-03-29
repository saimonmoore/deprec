# Copyright 2006-2008 by Mike Bailey. All rights reserved.
Capistrano::Configuration.instance(:must_exist).load do 
  namespace :deprec do
    namespace :swiftiply do

      set(:swiftiply_conf_dir) { "/etc/swiftiply/" }  
      set(:swiftiply_conf) { "/etc/swiftiply/#{application}.yml" }  
      set(:swiftiply_pid_dir) { "/var/run/swiftiply" }  
      set(:swiftiply_pidfile) { "/var/run/swiftiply/swiftiply.pid" }  
      set :swiftiply_port, 9000

      desc "Install swiftiply"
      task :install, :roles => :web do
        gem2.install 'swiftiply'
      end
      
      task :install_deps do
      end
      
      SYSTEM_CONFIG_FILES[:swiftiply] = [
        
        {:template => "swiftiply-init-script",
         :path => '/etc/init.d/swiftiply',
         :mode => 0755,
         :owner => 'root:root'},

      ]

      desc "Generate configuration file(s) for swiftiply"
      task :config_gen do
        SYSTEM_CONFIG_FILES[:swiftiply].each do |file|
          deprec2.render_template(:swiftiply, file)
        end
      end

      desc 'Deploy configuration files(s) for swiftiply' 
      task :config, :roles => :web do
        deprec2.push_configs(:swiftiply, SYSTEM_CONFIG_FILES[:swiftiply])
        deprec2.mkdir(swiftiply_conf_dir, :via => :sudo)
      end
      
      task :start, :roles => :web do
        send(run_method, "/etc/init.d/swiftiply start")
      end
      
      task :stop, :roles => :web do
        send(run_method, "/etc/init.d/swiftiply stop")
      end
      
      task :restart, :roles => :web do
        send(run_method, "/etc/init.d/swiftiply restart")
      end
      
      task :reload, :roles => :web do
        send(run_method, "/etc/init.d/swiftiply reload")
      end

      # This task will be called from a handler's config_project
      # merges a yml file into the swiftiply conf
      task :config_merge, :roles => :web do
      end

      # This task will be called from a handler's config_project
      # unmerges a yml file into the swiftiply conf      
      task :config_unmerge, :roles => :web do
      end
      
      task :activate, :roles => :web do
      end  
      
      task :deactivate, :roles => :web do
      end
      
      task :backup, :roles => :web do
      end
      
      task :restore, :roles => :web do
      end
      
    end
  end
end