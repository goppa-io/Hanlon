require "fileutils"
require "digest/sha2"
require "open3"
require 'pry'
require 'pry-byebug'

module ProjectHanlon
  module ImageService
    # Base image abstract
    class Base < ProjectHanlon::Object

      MOUNT_COMMAND = 'mount'
      UMOUNT_COMMAND = 'umount'
      USER_MOUNT_COMMAND = (Process::uid == 0 ? "#{MOUNT_COMMAND}" : "sudo -n #{MOUNT_COMMAND}")
      USER_UMOUNT_COMMAND = (Process::uid == 0 ? "#{UMOUNT_COMMAND}" : "sudo -n #{UMOUNT_COMMAND}")
      ARCHIVE_COMMAND = 'fuseiso'
      ARCHIVE_UMOUNT_COMMAND = 'fusermount'
      UNZIP_COMMAND = '7z'

      attr_accessor :filename
      attr_accessor :description
      attr_accessor :size
      attr_accessor :verification_hash
      attr_accessor :path_prefix
      attr_accessor :hidden
      attr_accessor :image_status
      attr_accessor :image_status_message

      def initialize(hash)
        super()
        @path_prefix = "base"
        @_namespace = :images
        @noun = "image"
        @description = "Image Base"
        @hidden = true
        from_hash(hash) unless hash == nil
      end

      def set_lcl_image_path(lcl_image_path)
        @_lcl_image_path = lcl_image_path + "/" + @path_prefix
      end

      # Used to add an image to the service
      # Within each child class the methods are overridden for that child template
      def add(src_image_path, lcl_image_path, extra = {})
        set_lcl_image_path(lcl_image_path)

        begin
          # set a few default values
          extra[:verify_copy] = true unless extra.has_key?(:verify_copy)
          create_imagepath_success = false
          create_mount_success = false
          # Get full path
          isofullpath = File.expand_path(src_image_path)
          # Get filename
          @filename = File.basename(isofullpath)
          logger.debug "isofullpath: #{isofullpath}"
          logger.debug "filename: #{@filename}"
          logger.debug "mount path: #{mount_path}"

          # Make sure file exists
          return cleanup_on_failure(create_mount_success, create_imagepath_success, "File '#{isofullpath}' does not exist") unless File.exist?(isofullpath)

          # Make sure it has an .iso extension
          return cleanup_on_failure(create_mount_success, create_imagepath_success, "File '#{isofullpath}' is not an ISO") if @filename[-4..-1].downcase != ".iso"

          # Confirm a mount doesn't already exist
          # TODO is_mounted method does not work with fuseiso
          unless is_mounted?(isofullpath)
            supported_methods = extra[:supported_methods]
            supported_methods = [ARCHIVE_COMMAND, MOUNT_COMMAND] unless supported_methods
            unless mount(isofullpath, supported_methods)
              logger.error "Could not mount '#{isofullpath}' on '#{mount_path}'"
              return cleanup_on_failure(create_mount_success, create_imagepath_success, "Could not mount '#{isofullpath}' on '#{mount_path}'")
            end
          end
          create_mount_success = true

          # Determine if there is an existing image path for iso
          if File.directory?(image_path)
            ## Remove if there is
            remove_dir_completely(image_path)
          end

          ## Create image path
          unless FileUtils.mkpath(image_path)
            logger.error "Cannot create image path: '#{image_path}'"
            return cleanup_on_failure(create_mount_success, create_imagepath_success, "Cannot create image path: '#{image_path}'")
          end
          create_imagepath_success = true

          # if we are using the UNZIP_COMMAND to unpack the ISO, then invoke that here;
          # otherwise we'll copy the contents from the 'mount_path' to the 'image_path'
          if @mount_method == :zip
            `#{UNZIP_COMMAND} x -y -o'#{image_path}' #{isofullpath}`
          else
            # Attempt to copy from mount path to image path
            # No way to test if successful. FileUtils.cp_r returns nil.
            FileUtils.cp_r(mount_path + "/.", image_path)
          end

          # if asked for verification and the ISO wasn't unpacked using the UNZIP_COMMAND,
          # then compare the source and copy directory hashes
          if extra[:verify_copy] && @mount_method != :zip
            # Verify diff between mount / image paths
            # For speed/flexibility reasons we just verify all files exists and not their contents
            @verification_hash = get_dir_hash(image_path)
            mount_hash = get_dir_hash(mount_path)
            unless mount_hash == @verification_hash
              logger.error "Image copy failed verification: #{@verification_hash} <> #{mount_hash}"
              return cleanup_on_failure(create_mount_success, create_imagepath_success, "Image copy failed verification: #{@verification_hash} <> #{mount_hash}")
            end
          end

        rescue => e
          logger.error e.message
          return cleanup_on_failure(create_mount_success, create_imagepath_success, e.message)
        end

        umount
        [true, '']
      end

      # Used to remove an image to the service
      # Within each child class the methods are overridden for that child template
      def remove(lcl_image_path)
        set_lcl_image_path(lcl_image_path) unless @_lcl_image_path != nil
        remove_dir_completely(image_path)
        !File.directory?(image_path)
      end

      # Used to verify an image within the filesystem (local/remote/possible Glance)
      # Within each child class the methods are overridden for that child template
      def verify(lcl_image_path)
        set_lcl_image_path(lcl_image_path) unless @_lcl_image_path != nil
        unless get_dir_hash(image_path) == @verification_hash
          binding.pry
          logger.error "ISO file structure is invalid"
          return [false, "ISO file structure is invalid"]
        end
        [true, "Valid"]
      end

      def image_path
        @_lcl_image_path + "/" + @uuid
      end

      def is_mounted?(isoimage)
        mounts.each do
        |mount|
          return true if mount[0] == isoimage && mount[1] == mount_path
        end
        false
      end

      def mount(isoimage, supported_methods)
        # First, create the mount_path directory if it doesn't exist already
        FileUtils.mkpath(mount_path) unless File.directory?(mount_path)
        # Then, depending on the 'supported_methods' declared when this method
        # is called, use the either the fuseiso command, the 7z command, or the
        # mount command to mount the isoimage (the first 'supported_command',
        # in that order, will be used)
        @mount_method = nil
        if supported_methods.include?(ARCHIVE_COMMAND) && exec_in_path(ARCHIVE_COMMAND)
          logger.debug "Mounting #{isoimage} using command '#{ARCHIVE_COMMAND} -n #{isoimage} #{mount_path}'"
          `#{ARCHIVE_COMMAND} -n #{isoimage} #{mount_path}`
          @mount_method = :fuseiso
        elsif supported_methods.include?(UNZIP_COMMAND) && exec_in_path(UNZIP_COMMAND)
          @mount_method = :zip
        elsif supported_methods.include?(MOUNT_COMMAND) && exec_in_path(MOUNT_COMMAND)
          logger.debug "Mounting #{isoimage} using command '#{USER_MOUNT_COMMAND} -o loop #{isoimage} #{mount_path}'"
          stdout, stderr, status = Open3.capture3("#{USER_MOUNT_COMMAND} -o loop #{isoimage} #{mount_path}")
          if status.success?
            @mount_method = :mount
          else
            cleanup_on_failure(false, true, "Command '#{USER_MOUNT_COMMAND}' failed with error '#{stderr.strip}'")
            raise ProjectHanlon::Error::Slice::CommandFailed, "Command '#{USER_MOUNT_COMMAND}' failed with error '#{stderr.strip}'"
          end
        else
          # raise an exception if none of the listed commands could be found
          # (this should not happen, but...)
          raise ProjectHanlon::Error::Slice::CommandFailed, "None of the listed methods #{supported_methods} were available for extracting the ISO.".tr('[]\"','()\'')
        end
        # return true, indicating success
        true
      end

      def umount
        # this block of code should never execute, but if it does make a note of it
        unless @mount_method
          logger.error "Attempting to unmount a volume (#{mount_path}) that was never successfully mounted"
          return
        end
        # use the @mount_method value to determine how to unmount a volume that was
        # mounted using the 'mount' method (above)
        if @mount_method == :fuseiso
          logger.debug "Unmounting via '#{ARCHIVE_UMOUNT_COMMAND} -u #{mount_path}' command"
          `#{ARCHIVE_UMOUNT_COMMAND} -u #{mount_path}`
          remove_dir_completely(mount_path)
        elsif @mount_method == :zip
          logger.debug "ISO was unpacked via the '#{UNZIP_COMMAND}' command; nothing to unmount/remove"
        elsif @mount_method == :mount
          logger.debug "Unmounting via '#{USER_UMOUNT_COMMAND} #{mount_path} 2> /dev/null' command"
          `#{USER_UMOUNT_COMMAND} #{mount_path} 2> /dev/null`
          remove_dir_completely(mount_path)
        else
          logger.error "Unrecognized mount_method (#{@mount_method}) used to mount volume; umount failed"
        end
      end

      def mounts
        `#{USER_MOUNT_COMMAND}`.split("\n").map! { |x| x.split("on") }.map! { |x| [x[0], x[1].split(" ")[0]] }
      end

      ## cleanup_on_failure method, based on arguments will unmount the iso,
      ## delete the mount directory and/or remove the image directory.
      ## If the image directory is removed an error will be logged to inform
      ## the client of the removal.
      def cleanup_on_failure(do_unmount, do_image_delete, errormsg)
        logger.error "Error: #{errormsg}"

        # unmount, if mounted
        if do_unmount
          umount
        end

        # remove directory if created
        if do_image_delete
          remove_dir_completely(image_path)
          logger.error "Deleted Image Directory, Image Path: #{image_path}"
        end

        [false, errormsg]
      end

      def mount_path
        "#{$temp_path}/#{@uuid}"
      end

      def remove_dir_completely(path)
        if File.directory?(path)
          FileUtils.rm_r(path, :force => true)
        else
          true
        end
      end

      def get_dir_hash(dir)
        logger.debug "Generating hash for path: #{dir}"
        files_string = Dir.glob("#{dir}/**/*").map { |x| x.sub("#{dir}/", "") }.sort.join("\n")
        Digest::SHA2.hexdigest(files_string)
      end

      def print_header
        return "UUID", "Type", "Name/Filename", "OS Version", "Status"
      end

      def print_items
        return @uuid, @description, get_name, @os_version, "#{@image_status ? "Valid".green : "Invalid - #{@image_status_message}".red}"
      end

      def print_item_header
        return "UUID", "Type", "Name/Filename", "Status"
      end

      def print_item
        return @uuid, @description, get_name,  "#{@image_status ? "Valid".green : "Invalid - #{@image_status_message}".red}"
      end

      def get_name
        @os_name ? @os_name : @filename
      end

      def line_color
        :white_on_black
      end

      def header_color
        :red_on_black
      end
    end
  end
end
