Capistrano::Configuration.instance(:must_exist).load do 
  namespace :ssmtp do
    
    SYSTEM_CONFIG_FILES[:ssmtp] = [

      {:template => 'ssmtp.conf.erb',
       :path => '/etc/ssmtp/ssmtp.conf',
       :mode => 0755,
       :owner => 'root:root'}         
    ]
  
    desc "Generate configuration file for ssmtp from template"
    task :config_gen do
      
      ssmtp_email = Capistrano::CLI.ui.ask "ssmtp email?" do |q|
        q.default = "#{user}@#{domain}"
      end

      ssmtp_mailhub = Capistrano::CLI.ui.ask "ssmtp mail hub (smtp.#{domain})?" do |q|
        q.default = "smtp.#{domain}"
      end

      ssmtp_user = Capistrano::CLI.ui.ask "ssmtp user?" do |q|
        q.default = user
      end    

      ssmtp_password = Capistrano::CLI.ui.ask "ssmtp password?" do |q|
        q.echo = false
      end

      ssmtp_domain = Capistrano::CLI.ui.ask "ssmtp domain?" do |q|
        q.default = domain
      end

      ssmtp_tls = Capistrano::CLI.ui.ask "ssmtp tls?" do |q|
        q.default = "NO"
      end

      
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