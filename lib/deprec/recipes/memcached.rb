# Copyright 2006-2008 by Mike Bailey. All rights reserved.
Capistrano::Configuration.instance(:must_exist).load do 
  namespace :deprec do
    namespace :memcached do
      set :memcached_port, 11211
      set :memcached_address, "127.0.0.1"
      set(:memcached_log) { "/var/log/memcached" }
      
      SRC_PACKAGES[:memcached] = {
        :filename => "memcached-1.2.2.tar.gz",
        :md5sum => "a08851f7fa7b15e92ee6320b7a79c321  memcached-1.2.2.tar.gz", 
        :dir => "memcached-1.2.2",
        :url => "http://www.danga.com/memcached/dist/memcached-1.2.2.tar.gz",
        :unpack => "tar zxf memcached-1.2.2.tar.gz;",
        :configure => %w(
            ./configure
            --prefix=/usr/local 
            ;
          ).reject{|arg| arg.match '#'}.join(' '),
        :make => 'make;',
        :install => 'make install;',
        :post_install => 'install -b scripts/memcached-init /etc/init.d/memcached;'
      }

      desc "Install memcached"
      task :install, :roles => :db do
        install_deps
        deprec2.download_src(SRC_PACKAGES[:memcached], src_dir)
        deprec2.install_from_src(SRC_PACKAGES[:memcached], src_dir)
      end
      
      task :install_deps do
        apt.install( {:base => %w(libevent-dev)}, :stable )
      end
      
      SYSTEM_CONFIG_FILES[:memcached] = [
        
        {:template => "memcached-init-script",
         :path => '/etc/init.d/memcached',
         :mode => 0755,
         :owner => 'root:root'},

         {:template => "start-memcached",
          :path => '/usr/local/share/memcached/scripts/start-memcached',
          :mode => 0755,
          :owner => 'root:root'},

         {:template => "memcached.conf.erb",
          :path => '/etc/memcached/memcached.conf',
          :mode => 0755,
          :owner => 'root:root'}
      ]

      desc "Generate configuration file(s) for memcached"
      task :config_gen do
        SYSTEM_CONFIG_FILES[:memcached].each do |file|
          deprec2.render_template(:memcached, file)
        end
      end

      desc 'Deploy configuration files(s) for memcached' 
      task :config, :roles => [:db, :app] do
        deprec2.push_configs(:memcached, SYSTEM_CONFIG_FILES[:memcached])
      end
      
      task :start, :roles => :db do
        send(run_method, "/etc/init.d/memcached start")
      end
      
      task :stop, :roles => :db do
        send(run_method, "/etc/init.d/memcached stop")
      end
      
      task :restart, :roles => :db do
        send(run_method, "/etc/init.d/memcached restart")
      end
      
      task :reload, :roles => :db do
        send(run_method, "/etc/init.d/memcached reload")
      end
      
      task :activate, :roles => :db do
      end  
      
      task :deactivate, :roles => :db do
      end
      
      task :backup, :roles => :db do
      end
      
      task :restore, :roles => :db do
      end
      
    end
  end
end