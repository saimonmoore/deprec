# Copyright 2006-2008 by Mike Bailey. All rights reserved.
Capistrano::Configuration.instance(:must_exist).load do 
  namespace :deprec do 
    namespace :ejabberd do
        
      set :ejabberd_conf_dir, '/usr/local/etc/ejabberd'
      set :ejabberd_conf_apps_dir, '/usr/local/etc/ejabberd/conf'
      set :ejabberd_log_dir, '/usr/local/var/log/ejabberd'
      set :ejabberd_executable, '/usr/local/sbin/ejabberdctl'
      set :ejabberd_init_script, '/etc/init.d/ejabberd'
      set :ejabberd_lib_dir, '/usr/local/var/lib/ejabberd'
      set :ejabberd_conf , "#{ejabberd_conf_dir}/ejabberd.cfg" 
  
      # Install 
      
      SRC_PACKAGES[:ejabberd] = {
        :filename => 'ejabberd-2.0.1_2.tar.gz',
        :dir => 'ejabberd-2.0.1',
        :url => "http://www.process-one.net/downloads/ejabberd/2.0.1/ejabberd-2.0.1_2.tar.gz",        
        :md5sum => "9c9417ab8dc334094ec7a611016c726e ejabberd-2.0.1_2.tar.gz",
        :configure => %w(
            cd src;
            ./configure
            --prefix=/usr/local 
            ;
          ).reject{|arg| arg.match '#'}.join(' '),        
      }
      
      SRC_PACKAGES[:erlang] = {
        :filename => 'otp_src_R12B-3.tar.gz',
        :url => "http://erlang.org/download/otp_src_R12B-3.tar.gz",        
        :md5sum => "c2e7f0ad54b8fadebde2d94106608d97 otp_src_R12B-3.tar.gz"
      }      
      
      desc "Install ejabberd"
      task :install, :roles => :app do        
        install_ejabberd_deps
        deprec2.download_src(SRC_PACKAGES[:ejabberd], src_dir)
        deprec2.install_from_src(SRC_PACKAGES[:ejabberd], src_dir)
        activate
      end
      
      desc "Install deps for ejabberd"      
      task :install_ejabberd_deps do
        apt.install( {:base => %w(openssl libssl-dev libexpat1-dev zlib1g-dev libtext-iconv-perl erlang)}, :stable )
      end
      
      desc "Install deps for Erlang"
      task :install_erlang_deps do
       apt.install( {:base => %w(libncurses-dev libssl-dev m4 tk tcl gcj)}, :stable )
      end
            
      task :install_erlang_from_src do
        install_erlang_deps
        # apt.build_dep( {:base => %w(erlang)}, :stable )        
        deprec2.download_src(SRC_PACKAGES[:erlang], src_dir)
        deprec2.install_from_src(SRC_PACKAGES[:erlang], src_dir)        
      end
      
      task :uninstall do
        sudo <<-CMD
        rm -rf #{ejabberd_conf_dir}
        rm -rf #{ejabberd_conf_apps_dir}
        rm -rf #{ejabberd_log_dir}
        rm -rf #{ejabberd_executable}
        rm -rf #{ejabberd_lib_dir}
        rm -rf #{ejabberd_init_script}
        CMD
      end
                      
      SYSTEM_CONFIG_FILES[:ejabberd] = [
          
        {:template => 'ejabberd-init-script',
         :path => '/etc/init.d/ejabberd',
         :mode => 0755,
         :owner => "root:root"},
         
        {:template => 'ejabberd.cfg.erb',
         :path => ejabberd_conf,
         :mode => 0755,
         :owner => "root:root"},
         
         {:template => 'logrotate.conf.erb',
          :path => "#{ejabberd_conf_dir}/logrotate.conf", 
          :mode => 0644,
          :owner => 'root:root'}            
      ]
      
      PROJECT_CONFIG_FILES[:ejabberd] = [
      
        {:template => "application.cfg.erb",
         :path => "application.cfg",
         :mode => 0644,
         :owner => "root:root"}
      
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
        symlink_logrotate_config        
      end
      
      task :config_project, :roles => :app do
        deprec2.push_configs(:ejabberd, PROJECT_CONFIG_FILES[:ejabberd])
        symlink_application_config
      end
      
      task :symlink_application_config, :roles => :app do
        deprec2.mkdir(ejabberd_conf_apps_dir, :via => :sudo)
        sudo "ln -sf #{deploy_to}/ejabberd/application.cfg #{ejabberd_conf_apps_dir}/#{application}.cfg"
      end
      
      task :unlink_application_config, :roles => :app do
        sudo "test -L #{ejabberd_conf_apps_dir}/#{application}.cfg && unlink #{ejabberd_conf_apps_dir}/#{application}.cfg"
      end
      
      task :symlink_logrotate_config, :roles => :app do
        sudo "ln -sf #{ejabberd_conf_dir}/logrotate.conf /etc/logrotate.d/ejabberd"
      end
      
      desc "Register an admin user with ejabberd to access web interface"
      task :register_admin_user, :roles => :app do
        target_user = Capistrano::CLI.ui.ask "Enter userid for admin user" do |q|
          q.default = user
        end
        
        target_domain = Capistrano::CLI.ui.ask "Enter jabber domain for admin user" do |q|
          q.default = "jabber.#{domain}"
        end
        
        admin_password = Capistrano::CLI.ui.ask("Enter password for #{target_user}") { |q| q.echo = false }
                
        sudo "ejabberdctl register #{target_user} #{target_domain} #{admin_password}"
        
        puts "Don't forget to update ejabberd.cfg with:"
        puts
        puts <<-TXT
        {acl, admins, {user, "#{target_user}", "#{target_domain}"}}.
          {access, configure, [{allow, admins}]}.
        
        TXT
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