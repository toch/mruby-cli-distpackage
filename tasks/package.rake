namespace :package do
  require 'fileutils'
  require 'tmpdir'
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

  def check_msi_installed?
    `wixl --version`
    $?.success?
  end

  def check_dmg_installed?
    true
  end

  def wxs_content(version, arch)
    arch_wxs = case arch
      when "x86_64"
        {
          string: "64-bit",
          program_files_folder: "ProgramFiles64Folder",
          define: "<?define Win64 = \"yes\"?>"
        }
      else
        {
          string: "32-bit",
          arch_program_files_folder: "ProgramFilesFolder",
          define: "<?define Win64 = \"no\"?>"
        }
    end

    <<-EOF
<?xml version='1.0' encoding='utf-8'?>
<Wix xmlns='http://schemas.microsoft.com/wix/2006/wi'>

  #{arch_wxs[:define]}

  <Product
    Name='mruby-cli #{arch_wxs[:string]}'
    Id='*'
    Version='#{version}'
    Language='1033'>

    <Package InstallerVersion="200" Compressed="yes" Comments="comments" InstallScope="perMachine"/>

    <Media Id="1" Cabinet="cabinet.cab" EmbedCab="yes"/>

    <Directory Id='TARGETDIR' Name='SourceDir'>
      <Directory Id='#{arch_wxs[:program_files_folder]}' Name='PFiles'>
        <Directory Id='INSTALLDIR' Name='mruby-cli'>
          <Component Id='MainExecutable' Guid='3DCA4C4D-205C-4FA4-8BB1-C0BF41CA5EFA'>
            <File Id='mruby-cliEXE' Name='mruby-cli.exe' DiskId='1' Source='mruby-cli.exe' KeyPath='yes'/>
          </Component>
        </Directory>
      </Directory>
    </Directory>

    <Feature Id='Complete' Level='1'>
      <ComponentRef Id='MainExecutable' />
    </Feature>

  </Product>
</Wix>
    EOF
  end

  def info_plist_content(version, arch)
    <<-EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>mruby-cli</string>
  <key>CFBundleGetInfoString</key>
  <string>mruby-cli #{version} #{arch}</string>
  <key>CFBundleName</key>
  <string>mruby-cli</string>
  <key>CFBundleIdentifier</key>
  <string>mruby-cli</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>#{version}</string>
  <key>CFBundleSignature</key>
  <string>mrbc</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
</dict>
</plist>
    EOF
  end

  desc "create deb package"
  task :deb => [:release] do
    abort("fpm is not installed. Please check your docker install.") unless check_fpm_installed?

    ["x86_64", "i686"].each do |arch|
      release_tar_file = "mruby-cli-#{version}-#{arch}-pc-linux-gnu.tgz"
      puts "Packaging deb for #{arch} into #{package_dir}"
      `fpm -s tar -t deb -a #{arch} -n mruby-cli -v #{version} --prefix /usr/bin -p #{package_path} #{release_path}/#{release_tar_file}`
    end
  end

  desc "create rpm package"
  task :rpm => [:release] do
    abort("fpm is not installed. Please check your docker install.") unless check_fpm_installed?

    ["x86_64", "i686"].each do |arch|
      release_tar_file = "mruby-cli-#{version}-#{arch}-pc-linux-gnu.tgz"
      puts "Packaging rpm for #{arch} into #{package_dir}"
      `fpm -s tar -t rpm -a #{arch} -n mruby-cli -v #{version} --prefix /usr/bin -p #{package_path} #{release_path}/#{release_tar_file}`
    end
  end

  desc "create msi package"
  task :msi => [:release] do
    abort("msitools is not installed.  Please check your docker install.") unless check_msi_installed?
    ["x86_64", "i686"].each do |arch|
      puts "Packaging msi for #{arch} into #{package_dir}"
      release_tar_file = "mruby-cli-#{version}-#{arch}-w64-mingw32.tgz"
      Dir.mktmpdir do |dest_dir|
        Dir.chdir dest_dir
        `tar -zxf #{release_path}/#{release_tar_file}`
        File.write("mruby-cli-#{version}-#{arch}.wxs", wxs_content(version, arch))
        `wixl -v mruby-cli-#{version}-#{arch}.wxs && mv mruby-cli-#{version}-#{arch}.msi #{package_path}`
      end
    end
  end

  desc "create dmg package"
  task :dmg => [:release] do
    abort("dmg tools are not installed.  Please check your docker install.") unless check_dmg_installed?
    ["x86_64", "i386"].each do |arch|
      puts "Packaging msi for #{arch} into #{package_dir}"
      release_tar_file = "mruby-cli-#{version}-#{arch}-apple-darwin14.tgz"
      Dir.mktmpdir do |dest_dir|
        Dir.chdir dest_dir
        `tar -zxf #{release_path}/#{release_tar_file}`
        FileUtils.chmod 0644, "mruby-cli"
        FileUtils.mkdir_p "mruby-cli.app/Contents/MacOs"
        FileUtils.mv "mruby-cli", "mruby-cli.app/Contents/MacOs"
        File.write("mruby-cli.app/Contents/Info.plist", info_plist_content(version, arch))
        `genisoimage -V mruby-cli -D -R -apple -no-pad -o #{package_path}/mruby-cli-#{version}-#{arch}.dmg #{dest_dir}`
      end
    end
  end

end

desc "create all packages"
task :package => ["package:deb", "package:rpm", "package:msi", "package:dmg"]
