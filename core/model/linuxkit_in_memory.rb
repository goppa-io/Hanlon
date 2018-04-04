module ProjectHanlon
  module ModelTemplate

    class LinuxkitInMemory < InMemory
      include(ProjectHanlon::Logging)

      # setup an accessor for the ssh_key instance var
      # attr_accessor :ssh_key

      def initialize(hash)
        super(hash)
        # Static config
        @hidden      = false
        @name        = "linuxkit_in_memory"
        @description = "Linuxkit In-Memory"
        # Default: no cloud config
        @cloud_config = nil

        @req_metadata_hash = {
            "@hostname_prefix" => {
                :default     => "node",
                :example     => "node",
                :validation  => '^[a-zA-Z0-9][a-zA-Z0-9\-]*$',
                :required    => true,
                :description => "node hostname prefix (will append node number)"
            },
            "@domainname" => {
                :default     => "localdomain",
                :example     => "example.com",
                :validation  => '^[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9](\.[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9])*$',
                :required    => true,
                :description => "local domain name (will be used in /etc/hosts file)"
            }
        }
        @opt_metadata_hash = {
            "@cloud_config" => {
                :default      => "",
                :example      => "",
                :validation   => '',
                :required     => false,
                :description  => "A yaml containing Linuxkit cloud config options"
            }
        }
        from_hash(hash) unless hash == nil
      end

      def callback
        {
            "postinstall"  => :postinstall_call,
            "cloud-config" => :cloud_config_call,
        }
      end

      def cloud_config_call
        return generate_cloud_config(@policy_uuid)
      end

      def postinstall_call
        @arg = @args_array.shift
        case @arg
          when "complete"
            fsm_action(:install_complete, :os_complete)
            return
          when "install_fail"
            fsm_action(:post_error, :os_complete)
            return
          else
            fsm_action(@arg.to_sym, :postinstall)
            return
        end
      end

      def boot_call(node, policy_uuid)
        super(node, policy_uuid)
        case @current_state
          when :init, :postinstall, :os_complete, :broker_check, :broker_fail, :broker_success, :complete_no_broker
            @result = "Starting Linuxkit In-Memory model boot"
            ret = start_install(node, policy_uuid)
          when :timeout_error, :error_catch
            engine = ProjectHanlon::Engine.instance
            ret = engine.default_mk_boot(node.uuid)
          else
            engine = ProjectHanlon::Engine.instance
            ret = engine.default_mk_boot(node.uuid)
        end
        fsm_action(:boot_call, :boot_call)
        ret
      end

      # will perform an "install" of Linuxkit by booting
      # into an in-memory image
      def start_install(node, policy_uuid)
        filepath = template_filepath('boot_install')
        ERB.new(File.read(filepath)).result(binding)
      end

      # ERB.result(binding) is failing in Ruby 1.9.2 and 1.9.3 so template is processed in the def block.
      def template_filepath(filename)
        filepath = File.join(File.dirname(__FILE__), "linuxkit/#{filename}.erb")
      end

      def kernel_args(policy_uuid)
        filepath = template_filepath('kernel_args')
        ERB.new(File.read(filepath)).result(binding)
      end

      def hostname
        "#{@hostname_prefix}#{@counter.to_s}"
      end

      def cloud_config_yaml
        if @cloud_config
          # perform a deep copy of the @cloud_config instance variable
          # (we'll be adding to it, below, so we need a copy to avoid
          # adding to the instance variable itself)
          config_hash = Marshal.load(Marshal.dump(@cloud_config))
        else
          config_hash = {}
        end
        if @current_state == :init
          config_hash['linuxkit'] = {} unless config_hash['linuxkit']
          config_hash['linuxkit']['units'] = [] unless config_hash['linuxkit']['units']
          config_hash['linuxkit']['units'] << {
              'name' => 'callback.service',
              'command' => 'start',
              'content' => "[Unit]\nDescription=Runs the OS Complete Callback\n\n[Service]\nType=oneshot\nExecStart=/bin/sh -c \"curl #{callback_url("postinstall", "complete")} || curl #{callback_url("postinstall", "install_fail")}\"\n"
          }
        end
        bson_ordered_hash_to_hash(config_hash).to_yaml.strip
      end

      def kernel_path
        "kernel"
      end

      def initrd_path
        "initrd.img"
      end

      # TODO: make optional
      # This will only affect the boot for install. It is helpful to debug errors
      # def autologin_kernel_args
      #   "console=tty0 console=ttyS0"
      # end

      def config
        ProjectHanlon.config
      end

      def generate_cloud_config(policy_uuid)
        filepath = template_filepath('cloud_config_in_memory')
        ERB.new(File.read(filepath)).result(binding)
      end

    end
  end
end
