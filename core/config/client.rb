require 'socket'
require 'fcntl'
require 'yaml'
require 'utility'
require 'logging/logger'

require 'config/common'

# This class represents the ProjectHanlon cli configuration. It is stored persistently in
# './cli/config/hanlon_client.conf' and edited by the user

module ProjectHanlon
  module Config
    class Client
      include ProjectHanlon::Utility
      include ProjectHanlon::Logging
      include ProjectHanlon::Config::Common
      extend  ProjectHanlon::Logging

      attr_accessor :hanlon_server
      attr_accessor :base_path
      attr_accessor :api_version
      attr_accessor :api_port
      attr_accessor :admin_port
      attr_accessor :hanlon_log_level
      attr_accessor :http_timeout

      attr_reader   :noun

      # Obtain our defaults
      def defaults

        {
            :hanlon_server    => get_an_ip,
            :base_path        => '/hanlon/api',
            :api_version      => 'v1',
            :api_port         => 8026,
            :admin_port       => 8025,
            :hanlon_log_level => 'Logger::ERROR',
            :http_timeout     => 6000
        }

      end

    end
  end
end
