# Copyright 2006-2008 by Mike Bailey. All rights reserved.
Capistrano::Configuration.instance(:must_exist).load do 
  namespace :deprec do
    namespace :nagios do
      
      set :nagios_user, 'nagios'
      set :nagios_group, 'nagios'
      set :nagios_cmd_group, 'nagcmd' # Allow external commands to be submitted through the web interface
      
      SRC_PACKAGES[:nagios] = {
        :filename => 'nagios-3.0rc1.tar.gz',   
        :md5sum => "d8b4fbf1c2527ddcc18a39372a41dba3  nagios-3.0rc1.tar.gz", 
        :dir => 'nagios-3.0rc1',  
        :url => "http://osdn.dl.sourceforge.net/sourceforge/nagios/nagios-3.0rc1.tar.gz",
        :unpack => "tar zxfv nagios-3.0rc1.tar.gz;",
        :configure => %w(
          ./configure 
          --with-command-group=nagcmd
          ;
          ).reject{|arg| arg.match '#'}.join(' '),
        :make => 'make all;',
        :install => 'make install install-init install-commandmode'
      }
      
      desc "Install nagios"
      task :install do
        install_deps
        create_nagios_user
        deprec2.add_user_to_group(nagios_user, apache_user)
        deprec2.mkdir('/usr/local/nagios/etc', :owner => "#{nagios_user}.#{nagios_group}", :via => :sudo)
        deprec2.mkdir('/usr/local/nagios/objects', :owner => "#{nagios_user}.#{nagios_group}", :via => :sudo)
        deprec2.download_src(SRC_PACKAGES[:nagios], src_dir)
        deprec2.install_from_src(SRC_PACKAGES[:nagios], src_dir)
      end
      
      task :create_nagios_user do
        deprec2.groupadd(nagios_group)
        deprec2.useradd(nagios_user, :group => nagios_group, :homedir => false)
        deprec2.groupadd(nagios_cmd_group)
        deprec2.add_user_to_group(nagios_user, nagios_cmd_group)
      end
         
      # Install dependencies for nagios
      task :install_deps do
        apt.install( {:base => %w(mailx)}, :stable )
      end
      
      SYSTEM_CONFIG_FILES[:nagios] = [
        
        {:template => 'nagios.cfg.erb',
        :path => '/usr/local/nagios/etc/nagios.cfg',
        :mode => 0664,
        :owner => 'nagios:nagios'},

        {:template => 'resource.cfg.erb',
        :path => '/usr/local/nagios/etc/resource.cfg',
        :mode => 0660,
        :owner => 'nagios:nagios'},
        
        {:template => 'cgi.cfg.erb',
        :path => '/usr/local/nagios/etc/cgi.cfg',
        :mode => 0664,
        :owner => 'nagios:nagios'},

        {:template => 'htpasswd.users',
        :path => '/usr/local/nagios/etc/htpasswd.users',
        :mode => 0664,
        :owner => 'nagios:nagios'},

        {:template => 'templates.cfg.erb',
        :path => '/usr/local/nagios/etc/objects/templates.cfg',
        :mode => 0664,
        :owner => 'nagios:nagios'},
        
        {:template => 'commands.cfg.erb',
        :path => '/usr/local/nagios/etc/objects/commands.cfg',
        :mode => 0664,
        :owner => 'nagios:nagios'},
        
        {:template => 'timeperiods.cfg.erb',
        :path => '/usr/local/nagios/etc/objects/timeperiods.cfg',
        :mode => 0664,
        :owner => 'nagios:nagios'},
        
        {:template => 'localhost.cfg.erb',
        :path => '/usr/local/nagios/etc/objects/localhost.cfg',
        :mode => 0664,
        :owner => 'nagios:nagios'},
        
        {:template => 'contacts.cfg.erb',
        :path => '/usr/local/nagios/etc/objects/contacts.cfg',
        :mode => 0664,
        :owner => 'nagios:nagios'},
        
        {:template => 'hosts.cfg.erb',
        :path => '/usr/local/nagios/etc/objects/hosts.cfg',
        :mode => 0664,
        :owner => 'nagios:nagios'},
        
        {:template => 'services.cfg.erb',
        :path => '/usr/local/nagios/etc/objects/services.cfg',
        :mode => 0664,
        :owner => 'nagios:nagios'},
        
        {:template => 'localhost.cfg.erb',
        :path => '/usr/local/nagios/etc/objects/localhost.cfg',
        :mode => 0664,
        :owner => 'nagios:nagios'},
        
        {:template => 'nagios_apache_vhost.conf.erb',
         :path => "conf/nagios_apache_vhost.conf",
         :mode => 0644,
         :owner => 'root:root'}
      
      ]

      desc "Generate configuration file(s) for nagios from template(s)"
      task :config_gen do
        SYSTEM_CONFIG_FILES[:nagios].each do |file|
          deprec2.render_template(:nagios, file)
        end
      end
      
      desc "Push nagios config files to server"
      task :config, :roles => :nagios do
        deprec2.push_configs(:nagios, SYSTEM_CONFIG_FILES[:nagios])
        sudo "ln -sf #{deploy_to}/nagios/conf/nagios_apache_vhost.conf /usr/local/apache2/conf/apps"
        config_check
        restart
      end
      
      desc "Run Nagios config check"
      task :config_check, :roles => :nagios do
        send(run_method, "/usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg")
      end
      
      desc "Set Nagios to start on boot"
      task :activate, :roles => :nagios do
        send(run_method, "update-rc.d nagios defaults")
        sudo "ln -sf #{deploy_to}/nagios/conf/nagios_apache_vhost.conf #{apache_vhost_dir}/nagios_#{application}.conf"
      end
      
      desc "Set Nagios to not start on boot"
      task :deactivate, :roles => :nagios do
        send(run_method, "update-rc.d -f nagios remove")
        link = "#{apache_vhost_dir}/nagios_#{application}.conf"
        sudo "test -h #{link} && sudo unlink #{link} || true"
      end
      
      
      # Control

      desc "Start Nagios"
      task :start, :roles => :nagios do
        send(run_method, "/etc/init.d/nagios start")
      end

      desc "Stop Nagios"
      task :stop, :roles => :nagios do
        send(run_method, "/etc/init.d/nagios stop")
      end

      desc "Restart Nagios"
      task :restart, :roles => :nagios do
        send(run_method, "/etc/init.d/nagios restart")
      end

      desc "Reload Nagios"
      task :reload, :roles => :nagios do
        send(run_method, "/etc/init.d/nagios reload")
      end
      
      task :backup, :roles => :web do
        # not yet implemented
      end
      
      task :restore, :roles => :web do
        # not yet implemented
      end
      
      #
      # Service specific tasks
      #
      
      # XXX quick and dirty - clean up later
      desc "Grant a user access to the web interface"
      task :htpass, :roles => :nagios do
        target_user = Capistrano::CLI.ui.ask "Userid" do |q|
          q.default = 'nagiosadmin'
        end
        system "htpasswd config/nagios/usr/local/nagios/etc/htpasswd.users #{target_user}"
      end
    
    end
    
    
    SRC_PACKAGES[:nagios_plugins] = {
      :filename => 'nagios-plugins-1.4.11.tar.gz',   
      :md5sum => "042783a2180a6987e0b403870b3d01f7  nagios-plugins-1.4.11.tar.gz", 
      :dir => 'nagios-plugins-1.4.11',  
      :url => "http://osdn.dl.sourceforge.net/sourceforge/nagiosplug/nagios-plugins-1.4.11.tar.gz",
      :unpack => "tar zxfv nagios-plugins-1.4.11.tar.gz;",
      :configure => "./configure --with-nagios-user=#{nagios_user} --with-nagios-group=#{nagios_group};",
      :make => 'make;',
      :install => 'make install;'
    }   
          
    namespace :nagios_plugins do
    
      task :install do
        install_deps
        top.deprec.nagios.create_nagios_user
        deprec2.download_src(SRC_PACKAGES[:nagios_plugins], src_dir)
        deprec2.install_from_src(SRC_PACKAGES[:nagios_plugins], src_dir)        
      end
      
      # Install dependencies for nagios plugins
      task :install_deps do
        apt.install( {:base => %w(libmysqlclient15-dev)}, :stable )
      end
      
      
    end
    
    SRC_PACKAGES[:nrpe] = {
      :filename => 'nrpe-2.11.tar.gz',   
      :md5sum => "dcf3b7c5b7c94c0ba6cbb4999c1161f0  nrpe-2.11.tar.gz", 
      :dir => 'nrpe-2.11',  
      :url => "http://easynews.dl.sourceforge.net/sourceforge/nagios/nrpe-2.11.tar.gz",
      :unpack => "tar zxfv nrpe-2.11.tar.gz;",
      :configure => "./configure --with-nagios-user=#{nagios_user} --with-nagios-group=#{nagios_group} #{ '--enable-command-args' if nrpe_enable_command_args};",
      :make => 'make all;',
      :install => 'make install-plugin; make install-daemon; make install-daemon-config;'
    }
    
    namespace :nrpe do
      
      set :nrpe_enable_command_args, false # set to true to compile nrpe to accept arguments
	                                       # note that you'll need to set it before these recipes are loaded (e.g. in .caprc)
    
      task :install do
        install_deps
        top.deprec.nagios.create_nagios_user
        deprec2.download_src(SRC_PACKAGES[:nrpe], src_dir)
        deprec2.install_from_src(SRC_PACKAGES[:nrpe], src_dir)
        # XXX this should only be run on the nrpe clients
        # XXX currently it's run on the nagios server too 
        # XXX shouldn't do any harm but we should split them up later 
        deprec2.append_to_file_if_missing('/etc/services', 'nrpe            5666/tcp # NRPE')    
      end
      
      task :install_deps do
        apt.install( {:base => %w(xinetd libssl-dev openssl)}, :stable )
      end
      
      SYSTEM_CONFIG_FILES[:nrpe] = [
        
        {:template => 'nrpe.xinetd.erb',
         :path => "/etc/xinetd.d/nrpe",
         :mode => 0644,
         :owner => 'root:root'},
         
        {:template => 'nrpe.cfg.erb',
         :path => "/usr/local/nagios/etc/nrpe.cfg",
         :mode => 0644,
         :owner => 'nagios:nagios'} # XXX hard coded file owner is bad...
                                    # It's done here because we aren't using 
                                    # lazy eval in hash constant.
      
      ]
      
      desc "Generate configuration file(s) for nrpe from template(s)"
      task :config_gen do
        SYSTEM_CONFIG_FILES[:nrpe].each do |file|
          deprec2.render_template(:nagios, file)
        end
      end
      
      desc "Push nrpe config files to server"
      task :config do
        deprec2.push_configs(:nagios, SYSTEM_CONFIG_FILES[:nrpe])
        # XXX should really only do this on targets
        sudo "/etc/init.d/xinetd stop"  
        sudo "/etc/init.d/xinetd start"  
      end
      
      task :test_local do
        run "/usr/local/nagios/libexec/check_nrpe -H localhost"
      end
      
      task :test_remote, :roles => :nagios do
        target_host = Capistrano::CLI.ui.ask "target hostname"
        run "/usr/local/nagios/libexec/check_nrpe -H #{target_host}"
      end
  
    end
      
    
  end
end