require 'rubygems'
require 'rubygems/package_task'

pkg_NAME='dyndoc-ruby-doc'
pkg_VERSION='1.1.2'

pkg_FILES=FileList[
    'lib/dyndoc/**/*.rb'
]

spec = Gem::Specification.new do |s|
    s.platform = Gem::Platform::RUBY
    s.summary = "dyndoc document"
    s.name = pkg_NAME
    s.version = pkg_VERSION
    s.licenses = ['MIT', 'GPL-2.0']
    s.requirements << 'none'
    s.require_path = 'lib'
    s.files = pkg_FILES.to_a
    s.description = <<-EOF
  Provide templating in text document.
  EOF
    s.author = "CQLS"
    s.email= "rdrouilh@gmail.com"
    s.homepage = "http://cqls.upmf-grenoble.fr"
end
