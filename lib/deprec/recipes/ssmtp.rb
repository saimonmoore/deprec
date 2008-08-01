Capistrano::Configuration.instance(:must_exist).load do 
  namespace :deprec do
    namespace :ssmtp do
    
      SYSTEM_CONFIG_FILES[:ssmtp] = [

        {:template => 'ssmtp.conf.erb',
         :path => '/etc/ssmtp/ssmtp.conf',
         :mode => 0755,
         :owner => 'root:root'}         
      ]
  
      desc "Generate configuration file for ssmtp from template"
      task :config_gen do
      
        set :ssmtp_email, Capistrano::CLI.ui.ask "ssmtp email?" {|q| q.default = "#{user}@#{domain}"}
        set :ssmtp_mailhub, Capistrano::CLI.ui.ask "ssmtp mail hub (smtp.#{domain})?" {|q| q.default = "smtp.#{domain}"}
        set :ssmtp_user, Capistrano::CLI.ui.ask "ssmtp user?" {|q| q.default = user}
        set :ssmtp_password, Capistrano::CLI.ui.ask "ssmtp password?" {|q| q.echo = false}
        set :ssmtp_domain, Capistrano::CLI.ui.ask "ssmtp domain?" {|q| q.default = domain}
        set :ssmtp_tls, Capistrano::CLI.ui.ask "ssmtp tls?" {|q| q.default = "NO"}
      
        SYSTEM_CONFIG_FILES[:ssmtp].each do |file|
          deprec2.render_template(:ssmtp, file)
        end  
      end

      desc "Push ssmtp config to servers"  
      task :config, :roles => :app do
        deprec2.mkdir('/etc/ssmtp', :via => :sudo)        
        deprec2.push_configs(:ssmtp, SYSTEM_CONFIG_FILES[:ssmtp])
      end    
      
      # Installation
  
      desc "Install ssmtp mail transport agent"
      task :install, :roles => :app do
        apt.install( {:base => %w(ssmtp)}, :stable )
      end
    end
  end
end