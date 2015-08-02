namespace :package do
  require 'fileutils'
  require_relative "#{MRUBY_ROOT}/../mrblib/version"

  version = MRubyCLI::Version::VERSION
  release_dir = "releases/v#{version}"
  package_dir = "packages/v#{version}"
  release_path = Dir.pwd + "/../#{release_dir}"
  package_path = Dir.pwd + "/../#{package_dir}"
  FileUtils.mkdir_p(package_path)

  def check_fpm_installed?
    `gem list -i fpm`.chomp == "true"
  end

  desc "create deb package"
  task :deb => [:release] do
    abort("fpm is not installed. Type gem install fpm.") unless check_fpm_installed?

    ["x86_64", "i686"].each do |arch|
      release_tar_file = "mruby-cli-#{version}-#{arch}-pc-linux-gnu.tgz"
      `fpm -s tar -t deb -a #{arch} -n mruby-cli -v #{version} --prefix /usr/bin -p #{package_path} #{release_path}/#{release_tar_file}`
    end
  end

  desc "create rpm package"
  task :rpm => [:release] do
    abort("fpm is not installed. Type gem install fpm.") unless check_fpm_installed?

    ["x86_64", "i686"].each do |arch|
      release_tar_file = "mruby-cli-#{version}-#{arch}-pc-linux-gnu.tgz"
      `fpm -s tar -t rpm -a #{arch} -n mruby-cli -v #{version} --prefix /usr/bin -p #{package_path} #{release_path}/#{release_tar_file}`
    end
  end

end

desc "create all packages"
task :package => ["package:deb", "package:rpm"]
