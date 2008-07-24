# Copyright 2006-2008 by Mike Bailey. All rights reserved.
Capistrano::Configuration.instance(:must_exist).load do 
  namespace :deprec do 
    namespace :ejabberd do
        
      set :ejabberd_dir, '/etc/ejabberd'
      set :ejabberd_conf_dir, '/etc/ejabberd/conf'
      set :ejabberd_log_dir, '/var/log/ejabberd'
      set :ejabberd_conf , "#{ejabberd_dir}/ejabberd.cfg" 
  
      # Install 
      
      SRC_PACKAGES[:ejabberd] = {
        :filename => 'ejabberd-2.0.1.tar.gz',
        :md5sum => "c09a2ace3c91f45dabbb608b11e48ed1 ejabberd-2.0.1.tar.gz"
      }
      
      desc "Install ejabberd"
      task :install, :roles => :app do        
        install_deps
        deprec2.download_src(SRC_PACKAGES[:ejabberd], src_dir)
        deprec2.install_from_src(SRC_PACKAGES[:ejabberd], src_dir)
        create_ejabberd_user
        activate
      end
      
      task :symlink_logrotate_config, :roles => :web do
        sudo "ln -sf /etc/ejabberd/logrotate.conf /etc/logrotate.d/ejabberd"
      end  
    
      SYSTEM_CONFIG_FILES[:ejabberd] = [
    
        {:template => 'ejabberd-init-script',
         :path => '/etc/init.d/ejabberd',
         :mode => 0755,
         :owner => 'root:root'},
         
        {:template => 'ejabberd.cfg.erb',
         :path => ejabberd_dir,
         :mode => 0755,
         :owner => 'root:root'}         
      ]
      
      PROJECT_CONFIG_FILES[:ejabberd] = [

        {:template => "application.cfg.erb",
         :path => "#{application}.cfg",
         :mode => 0644,
         :owner => 'root:root'},
         
        {:template => 'logrotate.conf.erb',
         :path => "logrotate.conf", 
         :mode => 0644,
         :owner => 'root:root'}
      
      ]      
  
      desc "Generate configuration file(s) for ejabberd from template(s)"
      task :config_gen do
        config_gen_system
        config_gen_project
      end
      
      task :config_gen_system do
        SYSTEM_CONFIG_FILES[:ejabberd].each do |file|
          deprec2.render_template(:ejabberd, file)
        end  
      end
      
      task :config_gen_project do
        PROJECT_CONFIG_FILES[:ejabberd].each do |file|
          deprec2.render_template(:ejabberd, file)
        end  
      end
      
      desc 'Deploy configuration files(s) for ejabberd' 
      task :config, :roles => :app do
        config_system
        config_project
      end
      
      task :config_system, :roles => :app do
        deprec2.mkdir(ejabberd_log_dir, :via => :sudo)
        deprec2.push_configs(:ejabberd, SYSTEM_CONFIG_FILES[:ejabberd])
      end
      
      task :config_project, :roles => :app do
        deprec2.push_configs(:ejabberd, PROJECT_CONFIG_FILES[:ejabberd])
        symlink_application_config
        symlink_logrotate_config
      end
      
      task :symlink_application_config, :roles => :app do
        deprec2.mkdir(ejabberd_conf_dir, :via => :sudo)
        sudo "ln -sf #{deploy_to}/ejabberd/#{application}.cfg #{ejabberd_conf_dir}/#{application}.cfg"
      end
      
      task :unlink_application_config, :roles => :app do
        sudo "test -L #{ejabberd_conf_dir}/#{application}.cfg && unlink #{ejabberd_conf_dir}/#{application}.cfg"
      end
      
      desc "Start ejabberd"
      task :start, :roles => :app do
        sudo "/etc/init.d/ejabberd start"
      end

      desc "Stop ejabberd"
      task :stop, :roles => :app  do
        sudo "/etc/init.d/ejabberd stop"
      end

      desc "Restart ejabberd"
      task :restart, :roles => :app  do
        send "/etc/init.d/ejabberd restart"
      end

      desc "Reload ejabberd"
      task :reload, :roles => :app  do
        sudo "/etc/init.d/ejabberd reload"
      end
   
      desc <<-DESC
        Activate ejabberd start scripts on server.
        Setup server to start ejabberd on boot.
      DESC
      task :activate do
        sudo "update-rc.d ejabberd defaults"
      end
  
      desc <<-DESC
        Dectivate ejabberd start scripts on server.
        Setup server to start ejabberd on boot.
      DESC
      task :deactivate do
        sudo "update-rc.d -f ejabberd remove"
      end

    end 
  end
end