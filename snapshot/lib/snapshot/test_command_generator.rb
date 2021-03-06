require 'snapshot/test_command_generator_base'

module Snapshot
  # Responsible for building the fully working xcodebuild command
  # Xcode 9 introduced the ability to run tests in parallel on multiple simulators
  # This TestCommandGenerator constructs the appropriate `xcodebuild` command
  # to be used for executing simultaneous tests
  class TestCommandGenerator < TestCommandGeneratorBase
    class << self
      def generate(devices: nil, language: nil, locale: nil, log_path: nil)
        parts = prefix
        parts << "xcodebuild"
        parts += options
        parts += destination(devices)
        parts += build_settings
        parts += actions
        parts += suffix
        parts += pipe(language: language, locale: locale, log_path: log_path)

        return parts
      end

      def pipe(language: nil, locale: nil, log_path: nil)
        tee_command = ['tee']
        tee_command << '-a' if log_path && File.exist?(log_path)
        tee_command << log_path.shellescape if log_path
        return ["| #{tee_command.join(' ')} | xcpretty #{Snapshot.config[:xcpretty_args]}"]
      end

      def destination(devices)
        unless verify_devices_share_os(devices)
          UI.user_error!('All devices provided to snapshot should run the same operating system')
        end
        # on Mac we will always run on host machine, so should specify only platform
        return ["-destination 'platform=macOS'"] if devices.first.to_s =~ /^Mac/

        os = devices.first.to_s =~ /^Apple TV/ ? "tvOS" : "iOS"

        os_version = Snapshot.config[:ios_version] || Snapshot::LatestOsVersion.version(os)

        destinations = devices.map do |d|
          device = find_device(d, os_version)
          UI.user_error!("No device found named '#{d}' for version '#{os_version}'") if device.nil?
          "-destination 'platform=#{os} Simulator,name=#{device.name},OS=#{os_version}'"
        end

        return [destinations.join(' ')]
      end

      def verify_devices_share_os(devices)
        # Check each device to see if it is an iOS device
        all_ios = devices.map do |device|
          device = device.downcase
          device.start_with?('iphone', 'ipad')
        end
        # Return true if all devices are iOS devices
        return true unless all_ios.include?(false)
        # There should only be more than 1 device type if
        # it is iOS, therefore, if there is more than 1
        # device in the array, and they are not all iOS
        # as checked above, that would imply that this is a mixed bag
        return devices.count == 1
      end
    end
  end
end
