require 'policy/base'

module ProjectHanlon
  module PolicyTemplate
    # ProjectHanlon Policy Default class
    # Used for default booting of Hanlon MK
    class BootMK < ProjectHanlon::PolicyTemplate::Base
      include(ProjectHanlon::Logging)

      # @param hash [Hash]
      def initialize(hash)
        super(nil)

        @hidden = :true
        @template = :hidden
        @description = "Default MK boot object. Hidden"

        @data = ProjectHanlon::Data.instance  if $app_type=="server"
        @data.check_init                      if $app_type=="server"
        @config = ProjectHanlon.config
      end

      # TODO - add logging ability from iPXE back to Hanlon for detecting node errors

      def get_boot_script(default_mk, node_smbios_uuid)
        image_svc_uri = "http://#{@config.hanlon_server}:#{@config.api_port}#{@config.websvc_root}/image/mk/#{default_mk.uuid}"
        hnl_mk_boot_debug_level = @config.hnl_mk_boot_debug_level
        hnl_mk_boot_kernel_args = @config.hnl_mk_boot_kernel_args
        mk_password = default_mk.mk_password
        # only allow values of 'quiet' or 'debug' for this parameter; if it's anything else set it
        # to an empty string
        hnl_mk_boot_debug_level = '' unless ['quiet','debug'].include? hnl_mk_boot_debug_level
        boot_script = ""
        boot_script << "#!ipxe\n"
        boot_script << "kernel #{image_svc_uri}#{default_mk.kernel}"
        boot_script << " rancher.password=#{mk_password}" if mk_password
        boot_script << " rancher.cloud_init.datasources=[url:#{image_svc_uri}/cloud-config]"
        boot_script << " smbios_uuid=#{node_smbios_uuid}"
        boot_script << " #{hnl_mk_boot_debug_level}" if hnl_mk_boot_debug_level && !hnl_mk_boot_debug_level.empty?
        boot_script << " #{hnl_mk_boot_kernel_args}" if hnl_mk_boot_kernel_args && !hnl_mk_boot_kernel_args.empty?
        boot_script << " || goto error\n"
        boot_script << "initrd #{image_svc_uri}#{default_mk.initrd} || goto error\n"
        boot_script << "boot || goto error\n"
        boot_script << "\n\n\n"
        boot_script << ":error\necho ERROR, will reboot in #{@config.mk_checkin_interval} seconds\nsleep #{@config.mk_checkin_interval}\nreboot\n"
        boot_script
      end

      def get_error_script(error_message)
        error_script = ""
        error_script << "#!ipxe\n"
        error_script << "echo #{error_message}, will reboot in #{@config.mk_checkin_interval} seconds\nsleep #{@config.mk_checkin_interval}\nreboot\n"
        error_script
      end

    end
  end
end
