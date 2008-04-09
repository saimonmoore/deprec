# Copyright 2006-2008 by Mike Bailey. All rights reserved.
Capistrano::Configuration.instance(:must_exist).load do 

  set :database_yml_in_scm, true
  set :app_symlinks, nil
  set :rails_env, 'production'
  set :gems_for_project, nil # Array of gems to be installed for app
  set :shared_dirs, nil # Array of directories that should be created under shared/
                        # and linked to in the project

  PROJECT_CONFIG_FILES[:rails] = [

    {:template => 'database.yml.erb',
     :path => 'database.yml',
     :mode => 0644,
     :owner => 'root:root'}

  ]

  PROJECT_CONFIG_FILES[:nginx] = [

    {:template => 'rails_nginx_vhost.conf.erb',
      :path => "rails_nginx_vhost.conf", 
      :mode => 0644,
      :owner => 'root:root'}
    ]
    
  # Hook into the default capistrano deploy tasks
  before 'deploy:setup', :except => { :no_release => true } do
    top.deprec.rails.setup_user_perms
    top.deprec.rails.setup_paths
    top.deprec.rails.setup_shared_dirs
    top.deprec.rails.install_gems_for_project
  end
  
  # Override default cap task using sudo to create dir
  namespace :deploy do
    task :setup, :except => { :no_release => true } do
      dirs = [deploy_to, releases_path, shared_path]
      dirs += %w(system log pids).map { |d| File.join(shared_path, d) }
      sudo "sh -c 'umask 02 && mkdir -p #{dirs.join(' ')}'"
    end
  end

  after 'deploy:setup', :except => { :no_release => true } do
    top.deprec.rails.setup_servers
    top.deprec.rails.create_config_dir
  end

  after 'deploy:symlink', :roles => :app do
    top.deprec.rails.symlink_shared_dirs
    top.deprec.rails.symlink_database_yml unless database_yml_in_scm
    top.deprec.thin.set_perms_for_thin_dirs
  end

  after :deploy, :roles => :app do
    deploy.cleanup
  end

  # redefine the reaper
  namespace :deploy do
    task :restart do
      top.deprec.thin.restart
      top.deprec.nginx.restart
    end
  end

  namespace :deprec do
    namespace :rails do

      task :install, :roles => :app do
        install_deps
        install_gems
      end

      task :install_deps do
        apt.install( {:base => %w(libmysqlclient15-dev sqlite3 libsqlite3-ruby libsqlite3-dev)}, :stable )
      end

      # install some required ruby gems
      task :install_gems do
        gem2.install 'sqlite3-ruby'
        gem2.install 'mysql'
        gem2.install 'rails'
        gem2.install 'rspec' # seems to be required to run rake db:migrate (???)
        # gem2.install 'builder' # XXX ? needed ?
      end
      
      task :install_gems_for_project do
          if gems_for_project
            gems_for_project.each { |gem| gem2.install(gem) }
          end
      end

      task :config_gen do
        PROJECT_CONFIG_FILES[:nginx].each do |file|
          deprec2.render_template(:nginx, file)
        end

        top.deprec.thin.config_gen_project
      end

      task :config, :roles => [:app, :web] do
        deprec2.push_configs(:nginx, PROJECT_CONFIG_FILES[:nginx])
        top.deprec.thin.config_project
        symlink_nginx_vhost
        symlink_logrotate_config
      end

      task :symlink_nginx_vhost, :roles => :web do
        sudo "ln -sf #{deploy_to}/nginx/rails_nginx_vhost.conf #{nginx_vhost_dir}/#{application}.conf"
      end
      
      task :symlink_logrotate_config, :roles => :web do
        sudo "ln -sf #{deploy_to}/nginx/logrotate.conf /etc/logrotate.d/nginx-#{application}"
      end

      task :create_config_dir do
        deprec2.mkdir("#{shared_path}/config", :group => group, :mode => 0775, :via => :sudo)
      end
      
      # create deployment group and add current user to it
      task :setup_user_perms do
        deprec2.groupadd(group)
        deprec2.add_user_to_group(user, group)
        deprec2.groupadd(thin_group)
        deprec2.add_user_to_group(user, thin_group)
        # we've just added ourself to a group - need to teardown connection
        # so that next command uses new session where we belong in group 
        deprec2.teardown_connections
      end

      # Setup database server.
      task :setup_db, :roles => :db, :only => { :primary => true } do
        top.deprec.mysql.setup
      end

      # setup extra paths required for deployment
      task :setup_paths, :roles => :app do
        deprec2.mkdir(deploy_to, :mode => 0775, :group => group, :via => :sudo)
        deprec2.mkdir(shared_path, :mode => 0775, :group => group, :via => :sudo)
      end
      
      # Symlink list of files and dirs from shared to current
      #
      # XXX write up explanation
      #
      desc "Setup shared dirs"
      task :setup_shared_dirs, :roles => [:app, :web] do
        if shared_dirs
          shared_dirs.each { |dir| deprec2.mkdir( "#{shared_path}/#{dir}", :via => :sudo ) }
        end
      end
      #
      desc "Symlink shared dirs."
      task :symlink_shared_dirs, :roles => [:app, :web] do
        if shared_dirs
          shared_dirs.each do |dir| 
            path = File.split(dir)[0]
            if path != '.'
              deprec2.mkdir("#{current_path}/#{path}")
            end
            run "ln -nfs #{shared_path}/#{dir} #{current_path}/#{dir}" 
          end
        end
      end
      
      # desc "Symlink shared files."
      # task :symlink_shared_files, :roles => [:app, :web] do
      #   if shared_files
      #     shared_files.each { |file| run "ln -nfs #{shared_path}/#{file} #{current_path}/#{file}" }
      #   end
      # end

      # database.yml stuff
      #
      task :generate_database_yml, :roles => :app do    
        host = Capistrano::CLI.ui.ask 'Enter database host' do |q| q.default = 'localhost' end
        db_name = Capistrano::CLI.ui.ask 'Enter database name'  do |q| q.default = "#{application}_#{rails_env}" end
        user = Capistrano::CLI.ui.ask 'Enter database user' do |q| q.default = 'root' end
        pass = Capistrano::CLI.ui.ask 'Enter database pass' do |q| q.default = '' end
        adapter = Capistrano::CLI.ui.ask 'Enter database adapter' do |q| q.default = 'mysql' end
        socket = Capistrano::CLI.ui.ask 'Enter database socket' do |q| q.default = '' end

        SYSTEM_CONFIG_FILES[:rails].each do |file|
          deprec2.render_template(:rails, file)
        end
        deprec2.push_configs(:thin, SYSTEM_CONFIG_FILES[:thin])
        run "mkdir -p #{deploy_to}/#{shared_dir}/config" 
        put database_configuration, "#{deploy_to}/#{shared_dir}/config/database.yml" 
      end

      desc "Link in the production database.yml" 
      task :symlink_database_yml, :roles => :app do
        run "ln -nfs #{shared_path}/config/database.yml #{release_path}/config/database.yml" 
      end

      desc <<-DESC
      install_rails_stack takes a stock standard ubuntu 'gutsy' 7.10 server
      and installs everything needed to be a Rails machine
      DESC
      task :install_rails_stack do

        # Generate configs first in case user input is required
        # Then we can go make a cup of tea.
        top.deprec.nginx.config_gen
        top.deprec.logrotate.config_gen
        top.deprec.thin.config_gen_system
#        top.deprec.mongrel.config_gen_system
#        top.deprec.monit.config_gen
        
        # Nginx as our web frontend
        top.deprec.nginx.install
        top.deprec.nginx.config
        
        # Subversion
        top.deprec.svn.install

        # Ruby
        top.deprec.ruby.install      
        top.deprec.rubygems.install      

        # Backend agnostic load balancing with Swiftiply
        top.deprec.swiftiply.install
        
        # Mongrel as our app server
        top.deprec.mongrel.install
        top.deprec.mongrel.config_system

        # Thin as our app server
        top.deprec.thin.install
        top.deprec.thin.config_system

=begin
        # Monit
        top.deprec.monit.install
        top.deprec.monit.config

        # God
        top.deprec.god.install
        top.deprec.god.config_gen
        top.deprec.god.config
=end

        # Install mysql
        top.deprec.mysql.install
        top.deprec.mysql.start
        
        # Install rails
        top.deprec.rails.install
        
        # Install logrotate
        top.deprec.logrotate.install
        top.deprec.logrotate.config
        
      end
      
      desc "setup and configure servers"
      task :setup_servers do
        top.deprec.nginx.activate       
        top.deprec.swiftiply.config_gen
        top.deprec.swiftiply.config
        top.deprec.thin.config_gen_system
        top.deprec.thin.config_system
        top.deprec.thin.activate_system
        top.deprec.rails.config_gen
        top.deprec.rails.config
      end
    end

    namespace :db do
      
      desc "Create database"
      task :create, :roles => :db do
        run "cd #{deploy_to}/current && rake db:create RAILS_ENV=#{rails_env}"
      end

      desc "Run database migrations"
      task :migrate, :roles => :db do
        run "cd #{deploy_to}/current && rake db:migrate RAILS_ENV=#{rails_env}"
      end
      
      desc "Run database migrations"
      task :schema_load, :roles => :db do
        run "cd #{deploy_to}/current && rake db:schema:load RAILS_ENV=#{rails_env}"
      end

      desc "Roll database back to previous migration"
      task :rollback, :roles => :db do
        run "cd #{deploy_to}/current && rake db:rollback RAILS_ENV=#{rails_env}"
      end

    end


    namespace :deploy do
      task :restart, :roles => :app, :except => { :no_release => true } do
        top.deprec.thin.restart
      end
    end
  end
end
