# Copyright 2006-2008 by Mike Bailey. All rights reserved.
Capistrano::Configuration.instance(:must_exist).load do 
  namespace :deprec do
    namespace :swiftiply do

      set(:swiftiply_conf_dir) { "/etc/swiftiply/" }
      set(:swiftiply_conf) { "/etc/swiftiply/swiftiply.conf" }
      set(:swiftiply_pid_file) { "/var/run/swiftiply/swiftiply.pid" }
      set :swiftiply_port, 9000

      # No Rubygems loading (citing reasons of speed)
      SRC_PACKAGES[:swiftiply] = {
        :filename => 'swiftiply-0.6.1.1.tar.bz2',   
        :md5sum => "c2ff6de68701f778fd7d3d40b907e562  swiftiply-0.6.1.1.tar.bz2", 
        :dir => 'swiftiply-0.6.1.1',  
        :url => "http://swiftiply.swiftcore.org/files/swiftiply-0.6.1.1.tar.bz2",
        :unpack => "tar jxf swiftiply-0.6.1.1.tar.bz2;",
        :install => 'ruby setup.rb;'
      }

      # No Rubygems loading (citing reasons of speed)
      SRC_PACKAGES[:event_machine] = {
        :filename => 'eventmachine-0.10.0.tar.gz',   
        :md5sum => "5f9dd6419c7ae0e3af569d315d8ee4f2  eventmachine-0.10.0.tar.gz", 
        :dir => 'eventmachine-0.10.0',  
        :url => "http://files.rubyforge.vm.bytemark.co.uk/eventmachine/eventmachine-0.10.0.tar.gz",
        :unpack => "tar zxf eventmachine-0.10.0.tar.gz;",
        :install => 'ruby setup.rb;'
      }


      desc "Install swiftiply"
      task :install, :roles => :web do
        install_deps
        deprec2.download_src(SRC_PACKAGES[:swiftiply], src_dir)
        deprec2.install_from_src(SRC_PACKAGES[:swiftiply], src_dir)
      end
      
      task :install_deps do
        deprec2.download_src(SRC_PACKAGES[:event_machine], src_dir)
        deprec2.install_from_src(SRC_PACKAGES[:event_machine], src_dir)
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
        send(run_method, "update-rc.d swiftiply defaults")
      end  
      
      task :deactivate, :roles => :web do
        send(run_method, "update-rc.d swiftiply defaults")
      end
      
      task :backup, :roles => :web do
      end
      
      task :restore, :roles => :web do
      end
      
    end
  end
end