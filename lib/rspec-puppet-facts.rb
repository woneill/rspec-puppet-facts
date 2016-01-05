require 'puppet'
require 'facter'
require 'facterdb'
require 'json'

module RspecPuppetFacts

  def on_supported_os(metadata = nil, opts = {} )
    opts[:hardwaremodels] ||= ['x86_64']

    path = metadata[:absolute_file_path] || Dir.pwd
    opts[:supported_os] ||= RspecPuppetFacts.meta_supported_os(path)

    filter = []
    opts[:supported_os].map do |os_sup|
      if os_sup['operatingsystemrelease']
        os_sup['operatingsystemrelease'].map do |operatingsystemmajrelease|
          opts[:hardwaremodels].each do |hardwaremodel|

            if os_sup['operatingsystem'] =~ /BSD/
              hardwaremodel = 'amd64'
            elsif os_sup['operatingsystem'] =~ /Solaris/
              hardwaremodel = 'i86pc'
            end

            filter << {
              :facterversion          => "/^#{Facter.version[0..2]}/",
              :operatingsystem        => os_sup['operatingsystem'],
              :operatingsystemrelease => "/^#{operatingsystemmajrelease.split(" ")[0]}/",
              :hardwaremodel          => hardwaremodel,
            }
          end
        end
      else
        opts[:hardwaremodels].each do |hardwaremodel|
          filter << {
            :facterversion   => "/^#{Facter.version[0..2]}/",
            :operatingsystem => os_sup['operatingsystem'],
            :hardwaremodel   => hardwaremodel,
          }
        end
      end
    end

    h = {}
    FacterDB::get_facts(filter).map do |facts|
      facts.merge!({
        :puppetversion => Puppet.version,
        :rubysitedir   => RbConfig::CONFIG["sitelibdir"],
        :rubyversion   => RUBY_VERSION,
      })
      facts[:augeasversion] = Augeas.open(nil, nil, Augeas::NO_MODL_AUTOLOAD).get('/augeas/version') if Puppet.features.augeas?
      h["#{facts[:operatingsystem].downcase}-#{facts[:operatingsystemrelease].split('.')[0]}-#{facts[:hardwaremodel]}"] = facts
    end
    h
  end

  # @api private
  def self.meta_supported_os(path)
    @meta_supported_os ||= get_meta_supported_os(path)
  end

  # @api private
  def self.get_meta_supported_os(path)
    metadata = get_metadata(path)
    if metadata['operatingsystem_support'].nil?
      fail StandardError, "Unknown operatingsystem support"
    end
    metadata['operatingsystem_support']
  end

  # @api private
  def self.get_metadata(path)
    dir = File.dirname(path)

    while !dir.empty?
      if File.exists?("#{dir}/metadata.json")
        return JSON.parse(File.read("#{dir}/metadata.json"))
      end

      dir = dir.rpartition("/").first
    end

    fail StandardError, "Could not find metadata.json in #{Dir.pwd} or any of its parent directories"
  end
end
