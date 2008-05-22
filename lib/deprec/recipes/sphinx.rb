# Copyright 2006-2008 by Mike Bailey. All rights reserved.
Capistrano::Configuration.instance(:must_exist).load do 
  namespace :deprec do 
    namespace :sphinx do
      
      SRC_PACKAGES[:sphinx] = {
        :filename => 'sphinx-0.9.8-rc2.tar.gz',   
        :dir => 'sphinx-0.9.8-rc2',  
        :url => "http://www.sphinxsearch.com/downloads/sphinx-0.9.8-rc2.tar.gz",
        :unpack => "tar zxf sphinx-0.9.8-rc2.tar.gz;",
        :configure => %w(
          ./configure
          ;
          ).reject{|arg| arg.match '#'}.join(' '),
        :make => 'make;',
        :install => 'make install;'
      }
      
      desc "install Sphinx Search Engine"
      task :install do
        deprec2.download_src(SRC_PACKAGES[:sphinx], src_dir)
        deprec2.install_from_src(SRC_PACKAGES[:sphinx], src_dir)
      end
    
      # install dependencies for nginx
      task :install_deps do
        # apt.install( {:base => %w(blah)}, :stable )
      end

      SYSTEM_CONFIG_FILES[:sphinx] = []
      
      PROJECT_CONFIG_FILES[:sphinx] = [

        {:template => 'monit.conf.erb',
         :path => 'monit.conf',
         :mode => 0644,
         :owner => 'root:root'}
      
      ]

      desc <<-DESC
      Generate nginx config from template. Note that this does not
      push the config to the server, it merely generates required
      configuration files. These should be kept under source control.            
      The can be pushed to the server with the :config task.
      DESC
      task :config_gen do
        PROJECT_CONFIG_FILES[:sphinx].each do |file|
          deprec2.render_template(:sphinx, file)
        end
      end

      desc "Push nginx config files to server"
      task :config, :roles => :sphinx do
        config_project
      end
      
      desc "Push nginx config files to server"
      task :config_project, :roles => :sphinx do
        deprec2.push_configs(:sphinx, PROJECT_CONFIG_FILES[:sphinx])
        symlink_monit_config
      end
      
      task :symlink_monit_config, :roles => :sphinx do
        sudo "ln -sf #{deploy_to}/sphinx/monit.conf #{monit_confd_dir}/sphinx_#{application}.conf"
      end

      desc <<-DESC
      Activate nginx start scripts on server.
      Setup server to start nginx on boot.
      DESC
      task :activate, :roles => :web do
        activate_system
      end

      task :activate_system, :roles => :web do
        send(run_method, "update-rc.d nginx defaults")
      end

      desc <<-DESC
      Dectivate nginx start scripts on server.
      Setup server to start nginx on boot.
      DESC
      task :deactivate, :roles => :web do
        send(run_method, "update-rc.d -f nginx remove")
      end


      # Control

      desc "Start Nginx"
      task :start, :roles => :web do
        send(run_method, "/etc/init.d/nginx start")
      end

      desc "Stop Nginx"
      task :stop, :roles => :web do
        send(run_method, "/etc/init.d/nginx stop")
      end

      desc "Restart Nginx"
      task :restart, :roles => :web do
        # So that restart will work even if nginx is not running
        # we call stop and ignore the return code. We then start it.
        send(run_method, "/etc/init.d/nginx stop; exit 0")
        send(run_method, "/etc/init.d/nginx start")
      end

      desc "Reload Nginx"
      task :reload, :roles => :web do
        send(run_method, "/etc/init.d/nginx reload")
      end

      task :backup, :roles => :web do
        # there's nothing to backup for nginx
      end

      task :restore, :roles => :web do
        # there's nothing to store for nginx
      end

    end 
  end
end