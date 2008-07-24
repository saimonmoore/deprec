#thin_cluster Copyright 2006-2008 by Mike Bailey. All rights reserved.
Capistrano::Configuration.instance(:must_exist).load do 
  
  namespace :deprec do
    namespace :thin do
        
      set :thin_servers, 4
      set :thin_port, 9001
      set :thin_address, "127.0.0.1"
#      set(:thin_socket) { "#{deploy_to}/shared/thin.sock" }
      set(:thin_environment) { rails_env }
      set(:thin_log_dir) { "#{deploy_to}/shared/log" }
      set(:thin_pid_dir) { "#{deploy_to}/shared/pids" }
      set :thin_conf_dir, '/etc/thin'
      set(:thin_conf) { "/etc/thin/#{application}.yml" } 

      set(:thin_swiftiply_conf) { "/etc/swiftiply/#{application}.yml" } 
      set :thin_swiftiply, true

      set :thin_user_prefix,  'thin_'
      set(:thin_user) { thin_user_prefix + application }
      set :thin_group_prefix,  'app_'
      set(:thin_group) { thin_group_prefix + application }
      
      # Install
      desc "Install thin"
      task :install, :roles => :app do
        gem2.install 'thin'
      end
    
    
      # Configure
      
      SYSTEM_CONFIG_FILES[:thin] = [   

        {:template => 'thin-init-script',
         :path => '/etc/init.d/thin',
         :mode => 0755,
         :owner => 'root:root'}
      
      ]
        
      PROJECT_CONFIG_FILES[:thin] = [

        {:template => 'thin.yml.erb',
         :path => 'thin.yml',
         :mode => 0644,
         :owner => 'root:root'}
      
      ]

      PROJECT_CONFIG_FILES[:swiftiply] = [

        {:template => 'swiftiply.yml.erb',
          :path => 'swiftiply.yml',
          :mode => 0644,
          :owner => 'root:root'}
      
      ]
       
      desc "Generate configuration file(s) for thin from template(s)"
      task :config_gen do
        config_gen_system
        config_gen_project
      end
      
      task :config_gen_system do
        SYSTEM_CONFIG_FILES[:thin].each do |file|
          deprec2.render_template(:thin, file)
        end  
      end
      
      task :config_gen_project do
        PROJECT_CONFIG_FILES[:thin].each do |file|
          deprec2.render_template(:thin, file)
        end
        PROJECT_CONFIG_FILES[:swiftiply].each do |file|
          deprec2.render_template(:thin, file)
        end
      end
      
      desc 'Deploy configuration files(s) for thin' 
      task :config, :roles => :app do
        config_system
        config_project
      end
      
      task :config_system, :roles => :app do
        deprec2.push_configs(:thin, SYSTEM_CONFIG_FILES[:thin])
      end
      
      task :config_project, :roles => :app do
        create_thin_user_and_group
        deprec2.push_configs(:thin, PROJECT_CONFIG_FILES[:thin])
        deprec2.push_configs(:thin, PROJECT_CONFIG_FILES[:swiftiply])
        symlink_thin_cluster
      end
      
      task :symlink_thin_cluster, :roles => :app do
        deprec2.mkdir(thin_conf_dir, :via => :sudo)
        sudo "ln -sf #{deploy_to}/thin/thin.yml #{thin_conf}"
        sudo "ln -sf #{deploy_to}/thin/swiftiply.yml #{thin_swiftiply_conf}"
      end
      
      task :unlink_thin_cluster, :roles => :app do
        deprec2.mkdir(thin_conf_dir, :via => :sudo)
        sudo "test -L #{thin_conf} && unlink #{thin_conf}"
        sudo "test -L #{thin_swiftiply_conf} && unlink #{thin_swiftiply_conf}"
      end
      
      
      # Control
      
      desc "Start application server."
      task :start, :roles => :app do
        send(run_method, "thin start -C #{thin_conf}")
      end
      
      desc "Stop application server."
      task :stop, :roles => :app do
        send(run_method, "thin stop -C #{thin_conf}")
      end
      
      desc "Restart application server."
      task :restart, :roles => :app do
        send(run_method, "thin restart -C #{thin_conf}")
      end
      
      task :activate, :roles => :app do
        activate_system
        activate_project
      end  
      
      task :activate_system, :roles => :app do
        send(run_method, "update-rc.d thin defaults")
      end
      
      task :activate_project, :roles => :app do
        symlink_thin_cluster
      end
      
      task :deactivate, :roles => :app do
        puts
        puts "******************************************************************"
        puts
        puts "Danger!"
        puts
        puts "Do you want to deactivate just this project or all thin"
        puts "clusters on this server? Try a more granular command:"
        puts
        puts "cap deprec:thin:deactivate_system  # disable all clusters"
        puts "cap deprec:thin:deactivate_project # disable only this project"
        puts
        puts "******************************************************************"
        puts
      end
      
      task :deactivate_system, :roles => :app do
        send(run_method, "update-rc.d -f thin remove")
      end
      
      task :deactivate_project, :roles => :app do
        unlink_thin_cluster
        restart
      end
      
      task :backup, :roles => :app do
      end
      
      task :restore, :roles => :app do
      end
      
      desc "create user and group for mongel to run as"
      task :create_thin_user_and_group, :roles => :app do
        deprec2.groupadd(thin_group) 
        deprec2.useradd(thin_user, :group => thin_group, :homedir => false)
        # Set the primary group for the thin user (in case user already existed
        # when previous command was run)
        sudo "usermod --gid #{thin_group} #{thin_user}"
      end
      
      desc "set group ownership and permissions on dirs thin needs to write to"
      task :set_perms_for_thin_dirs, :roles => :app do
        tmp_dir = "#{deploy_to}/current/tmp"
        shared_dir = "#{deploy_to}/shared"
        files = ["#{thin_log_dir}/thin.log", "#{thin_log_dir}/#{rails_env}.log"]

        sudo "chgrp -R #{thin_group} #{tmp_dir} #{shared_dir}"
        sudo "chmod -R g+w #{tmp_dir} #{shared_dir}" 
        # set owner and group of log files 
        files.each { |file|
          sudo "touch #{file}"
          sudo "chown #{thin_user} #{file}"   
          sudo "chgrp #{thin_group} #{file}" 
          sudo "chmod g+w #{file}"   
        } 
      end
      
    end
  end
end
