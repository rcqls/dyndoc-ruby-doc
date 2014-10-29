require 'rubygems'
require 'rubygems/package_task'

PKG_NAME='dyndoc-ruby-doc'
PKG_VERSION='1.0.0'

PKG_FILES=FileList[
    'lib/dyndoc/**/*.rb'
]

spec = Gem::Specification.new do |s|
    s.platform = Gem::Platform::RUBY
    s.summary = "dyndoc document"
    s.name = PKG_NAME
    s.version = PKG_VERSION
    s.licenses = ['MIT', 'GPL-2']
    s.requirements << 'none'
    s.require_path = 'lib'
    s.files = PKG_FILES.to_a
    s.description = <<-EOF
  Provide templating in text document.
  EOF
    s.author = "CQLS"
    s.email= "rdrouilh@gmail.com"
    s.homepage = "http://cqls.upmf-grenoble.fr"
    s.rubyforge_project = nil
end

## this allows to produce some parameter for task like  Gem::PackageTask (without additional argument!)
opt={};ARGV.select{|e| e=~/\=/ }.each{|e| tmp= e.split("=");opt[tmp[0]]=tmp[1]}

PKG_INSTALL_DIR=opt["pkgdir"] || ENV["RUBYGEMS_PKGDIR"]  || "pkg"


task :default => :package

task :package => [:ruby]

##########################################
# this is for gem specific_install
desc "Create #{PKG_NAME+'-'+PKG_VERSION+'.gem'} for specific_install"
task :gemspec => [:ruby_only]
##########################################

desc "Create #{PKG_NAME+'-'+PKG_VERSION+'.gem'}" 
task :ruby_only do |t|
  #Gem::Builder.new(spec_client).build
  Gem::Package.build(spec)
end

# NEW: it is less verbose than the previous one
desc "Create #{PKG_NAME+'-'+PKG_VERSION+'.gem'} in #{PKG_INSTALL_DIR}" 
task :ruby do |t|
  #Gem::Builder.new(spec_client).build
  unless File.directory? PKG_INSTALL_DIR
    require 'fileutils'
    FileUtils.mkdir_p PKG_INSTALL_DIR
  end
  Gem::Package.build(spec)
  `mv #{PKG_NAME+'-'+PKG_VERSION+'.gem'} #{PKG_INSTALL_DIR}`
end

## quick install task
desc "Quick install #{File.join(PKG_INSTALL_DIR,PKG_NAME+'-'+PKG_VERSION+'.gem')}"
task :install => :package do |t|
    `gem install #{File.join(PKG_INSTALL_DIR,PKG_NAME+'-'+PKG_VERSION+'.gem')} --local --no-rdoc --no-ri`
end

