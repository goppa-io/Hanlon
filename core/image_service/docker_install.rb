module ProjectHanlon
  module ImageService
    # Image construct for generic Operating System install ISOs
    class DockerInstall < ProjectHanlon::ImageService::Base

      attr_accessor :os_name
      attr_accessor :os_version
      def initialize(hash)
        super(hash)
        @description = "Docker Install"
        @path_prefix = "docker"
        @hidden = false
        from_hash(hash) unless hash == nil
      end

      def add(src_image_path, lcl_image_path)
        begin
          # for Docker Install TarBall are used, the 'tar' command must be used.
          # supported methods to only support the 'tar' command
          resp = super(src_image_path, lcl_image_path, extra, { :supported_methods => ['tar'] })
          if resp[0]
            @os_name = extra[:os_name]
            @os_version = extra[:os_version]
          end
          resp
        rescue => e
          logger.error e.message
          return [false, e.message]
        end
      end
      
      def verify(lcl_image_path)
        # check to make sure that the hashes match (of the file list
        # extracted and the file list from the tar)
        is_valid, result = super(lcl_image_path)
        unless is_valid
          return [false, result]
        end
        # no specific checks for os images
        [true, '']
      end

      def print_item_header
        super.push "os name", "os version"
      end

      def print_item
        super.push @os_name.to_s, @os_version.to_s
      end

    end
  end
end


      def verify(lcl_image_path)
        # check to make sure that the hashes match (of the file list
        # extracted and the file list from the ISO)
      end

      def print_item_header
        super.push "OS Name", "WIM Index", "Base Image"
      end

      def print_item
        super.push @os_name, @wim_index.to_s, @base_image_uuid
      end

    end
  end
end
