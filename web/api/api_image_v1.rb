#

require 'json'
require 'uri'
require 'api_utils'

module Hanlon
  module WebService
    module Image

      class APIv1 < Grape::API

        version :v1, :using => :path, :vendor => "hanlon"
        format :json
        default_format :json
        SLICE_REF = ProjectHanlon::Slice::Image.new([])

        rescue_from ProjectHanlon::Error::Slice::InvalidUUID,
                    ProjectHanlon::Error::Slice::InvalidImageType,
                    Grape::Exceptions::Validation do |e|
          Rack::Response.new(
              Hanlon::WebService::Response.new(400, e.class.name, e.message).to_json,
              400,
              { "Content-type" => "application/json" }
          )
        end

        rescue_from ProjectHanlon::Error::Slice::MethodNotAllowed,
                    ProjectHanlon::Error::Slice::MissingArgument,
                    ProjectHanlon::Error::Slice::CouldNotRemove,
                    ProjectHanlon::Error::Slice::CommandFailed do |e|
          Rack::Response.new(
              Hanlon::WebService::Response.new(403, e.class.name, e.message).to_json,
              403,
              { "Content-type" => "application/json" }
          )
        end

        rescue_from ProjectHanlon::Error::Slice::InternalError do |e|
          Rack::Response.new(
              Hanlon::WebService::Response.new(500, e.class.name, e.message).to_json,
              500,
              { "Content-type" => "application/json" }
          )
        end

        rescue_from :all do |e|
          #raise e
          Rack::Response.new(
              Hanlon::WebService::Response.new(500, e.class.name, e.message).to_json,
              500,
              { "Content-type" => "application/json" }
          )
        end

        helpers do

          def content_type_header
            settings[:content_types][env['api.format']]
          end

          def api_format
            env['api.format']
          end

          def is_uuid?(string_)
            string_ =~ /^[A-Za-z0-9]{1,22}$/
          end

          def get_cloud_config_req_uuid(string_)
            match = /^mk\/([A-Za-z0-9]{1,22})\/cloud\-config[\/]?$/.match(string_)
            return match[1] if match
          end

          def get_data_ref
            Hanlon::WebService::Utils::get_data
          end

          def request_is_from_hanlon_server(ip_addr)
            Hanlon::WebService::Utils::request_from_hanlon_server?(ip_addr)
          end

          def request_is_from_hanlon_subnet(ip_addr)
            Hanlon::WebService::Utils::request_from_hanlon_subnet?(ip_addr)
          end

          def slice_success_response(slice, command, response, options = {})
            Hanlon::WebService::Utils::hnl_slice_success_response(slice, command, response, options)
          end

          def slice_success_object(slice, command, response, options = {})
            Hanlon::WebService::Utils::hnl_slice_success_object(slice, command, response, options)
          end

          def filter_hnl_response(response, filter_str)
            Hanlon::WebService::Utils::filter_hnl_response(response, filter_str)
          end

          # get a list of the sub-images in a WIM image
          def get_wim_subimages(image, wim_path)
            # first, define the keys we want to select from the output of the
            # 'wiminfo' command
            selection_keys = ['Display Name', 'Index']

            # then parse the output of that command; first breaking the output down into
            # a nested array of sections, lines, and words; then selecting out the lines
            # we want to keep from each section using the 'selection_keys' (defined above)
            wim_map_array = %x[wiminfo #{wim_path}].split("\n\n").map { |section|
              section.split("\n").map { |line|
                line.split(":").each { |word| word.strip! }
              }
            }.each { |section|
              # only keep lines in each section who's 'key' (the first word) is in the
              # 'selection_keys' array defined above; then remove any sections that are
              # left empty or that don't include both an 'Index' and a 'Description' key
              section.keep_if { |line|
                selection_keys.include?(line[0])
              }
            }.delete_if { |lines| lines.empty? || lines.size != 2 }

            # now, transform the resulting array into a hash map who's keys are the 'Index'
            # values for each element in the array and who's values are the 'Description'
            # for that same array element
            wim_map = {}
            wim_map_array.each { |wim_section|
              # convert the array element (the lines kept from each section) into a hash
              wim_section_hash = Hash[*wim_section.flatten]
              # then use the fields from that hash to fill in the elements in the wim_map
              # hash (which we will use later)
              wim_map[wim_section_hash[selection_keys[1]].to_i] = wim_section_hash[selection_keys[0]]
            }
            # now, based on what we found in the 'wim' file, add new images to an output array
            # (one for each entry in the 'wim' file)
            image_array = []
            classname = SLICE_REF.image_types[:win][:classname]
            image_class = ::Object::full_const_get(classname)
            wim_map.each { |wim_index, os_name|
              # create a new image object
              new_image = image_class.new({})
              # fill in some of the fields with the corresponding values
              # from the underlying (base) image
              new_image.filename = image.filename
              new_image.image_status = image.image_status
              new_image.image_status_message = image.image_status_message
              # and add the OS name and WIM index extracted from the 'wiminfo'
              # command output (above)
              new_image.os_name = os_name
              new_image.wim_index = wim_index
              new_image.base_image_uuid = image.uuid
              # finally, add the resulting object to the array of sub-images
              image_array << new_image
            }
            image_array
          end

          # get a list of all of the images that reference the image with a 'uuid'
          # corresponding to their 'base_image_uuid'
          def get_referencing_images(base_image_uuid)
            images = SLICE_REF.get_object("images", :images)
            images.select! { |image|
              image.respond_to?(:base_image_uuid) && image.base_image_uuid == base_image_uuid && image.uuid != base_image_uuid
            }
          end

        end

        # the following description hides this endpoint from the swagger-ui-based documentation
        # (since the functionality provided by this endpoint is not intended to be used outside
        # of the hanlon subnet, or in the case of a GET on the /image resource, off of the Hanlon
        # server itself)
        desc 'Hide this endpoint', {
            :hidden => true
        }
        resource :image do

          # GET /image
          # Query for images.
          #   parameters:
          #     optional:
          #       :filter_str    | String   | A string to use to filter the results  |
          desc "Retrieve a list of all image instances"
          before do
            # only test if directly accessing the /config resource
            if env["PATH_INFO"].match(/image$/)
              # only allow access to configuration resource from the hanlon server
              unless request_is_from_hanlon_subnet(env['REMOTE_ADDR'])
                raise ProjectHanlon::Error::Slice::MethodNotAllowed, "Remote Access Forbidden; access to /image resource is not allowed from outside of the Hanlon subnet"
              end
            end
          end
          params do
            optional "hidden", type: Boolean, desc: "Return all images (including hidden images)"
            optional :filter_str, type: String, desc: "String used to filter results"
          end
          get do
            filter_str = params[:filter_str]
            images = SLICE_REF.get_object("images", :images)
            # reject all hidden images unless the hidden flag was set to true
            images.reject! { |image| image.hidden } unless params[:hidden]

            # fix 125 - add image local path to image end point
            @_lcl_image_path = ProjectHanlon.config.image_path + "/"
            images.each do |image|
              image.set_lcl_image_path(ProjectHanlon.config.image_path)
              image.image_status, image.image_status_message = image.verify(image.image_path)
            end
            success_object = slice_success_object(SLICE_REF, :get_all_images, images, :success_type => :generic)
            # if a filter_str was provided, apply it here
            success_object['response'] = filter_hnl_response(success_object['response'], filter_str) if filter_str
            # and return the resulting success_object
            success_object
          end     # end GET /image

          # POST /image
          # Create a Hanlon model
          #   parameters:
          #     type         | String | The "type" of image being added ('mk', 'os', etc.)        |    | Default: unavailable
          #     path         | String | The "path" (absolute) to the image ISO                    |    | Default: unavailable
          #     name         | String | The logical name to use for the image (os images only)    |    | Default: unavailable
          #     version      | String | The version to use for the image (os images only)         |    | Default: unavailable
          #     docker_image | String | Path to the Docker image (required; mk images only)       |    | Default: unavailable
          #     ssh_keyfile  | String | The public key file (optional; mk images only)            |    | Default: unavailable
          #     mk_password  | String | The microkernel password (optional; mk images only)       |    | Default: unavailable
          desc "Create a new image instance (from an ISO file)"
          before do
            # ToDo::Sankar::Suppressed - validation suppressed due to security issues

            # only allow access to this resource from the Hanlon subnet
            #puts "env['REMOTE_ADDR'] value is #{env['REMOTE_ADDR']}"
            #unless request_is_from_hanlon_subnet(env['REMOTE_ADDR'])
            #  env['api.format'] = :text
            #  raise ProjectHanlon::Error::Slice::MethodNotAllowed, "Remote Access Forbidden; access to /image resource is not allowed from outside of the Hanlon subnet"
            #end
          end
          params do
            requires "type", type: String, desc: "The image type ('mk', 'os', etc.)"
            requires "path", type: String, desc: "The path (absolute) to the ISO"
            optional "name", type: String, desc: "The image name (required for 'os' images)"
            optional "version", type: String, desc: "The image version (required for 'os' images)"
            optional "docker_image", type: String, desc: "The path to the docker image (required for 'mk' images)"
            optional "ssh_keyfile", type: String, desc: "The public key file (optional for 'mk' images)"
            optional "mk_password", type: String, desc: "The microkernel password (optional for 'mk' images)"
          end
          post do
            image_type = params["type"]
            iso_path = params["path"]
            os_name = params["name"]
            os_version = params["version"]
            docker_image = params["docker_image"]
            ssh_keyfile = params["ssh_keyfile"]
            mk_password = params["mk_password"]

            # check to make sure the image_type is a recognized image_type
            unless ([image_type.to_sym] - SLICE_REF.image_types.keys).size == 0
              raise ProjectHanlon::Error::Slice::InvalidImageType, "Invalid Image Type '#{image_type}', valid types are: " +
                                                                     SLICE_REF.image_types.keys.map { |k| k.to_s }.join(', ')
            end

            # throw an error unless a value was specified for the 'iso_path' parameter
            raise ProjectHanlon::Error::Slice::MissingArgument, '[/path/to/iso]' unless iso_path != nil && iso_path != ""
            os_mk_type_index = ['os','mk'].index(image_type)
            # throw an error unless it is not an OS image or it is an OS image
            # and a value was specified for the 'name' parameter
            raise ProjectHanlon::Error::Slice::InternalError, "Missing parameter 'name'; required for OS images" unless os_mk_type_index != 0 || os_name
            # throw an error unless it is not an OS image or it is an OS image
            # and a value was specified for the 'version' parameter
            raise ProjectHanlon::Error::Slice::InternalError, "Missing parameter 'version'; required for OS images" unless os_mk_type_index != 0 || os_version
            # throw an error unless it is not an MK image or it is an MK image
            # and a value was specified for the 'docker_image' parameter
            raise ProjectHanlon::Error::Slice::InternalError, "Missing parameter 'docker_image'; required for MK images" unless os_mk_type_index != 1 || docker_image

            # if it's a windows ISO, then make sure we can access the 'wiminfo' command
            # (we'll need it to unpack the image)
            if image_type == 'win' && !SLICE_REF.exec_in_path('wiminfo')
              raise ProjectHanlon::Error::Slice::InternalError, "Missing command 'wiminfo'; required to extract Windows images"
            end

            classname = SLICE_REF.image_types[image_type.to_sym][:classname]
            image = ::Object::full_const_get(classname).new({})

            # We send the new image object to the appropriate method
            res = []
            if image_type == 'mk'
              res = SLICE_REF.send SLICE_REF.image_types[image_type.to_sym][:method], image, iso_path,
                                   ProjectHanlon.config.image_path, docker_image, ssh_keyfile, mk_password
            elsif image_type == 'os'
              res = SLICE_REF.send SLICE_REF.image_types[image_type.to_sym][:method], image, iso_path,
                                   ProjectHanlon.config.image_path, os_name, os_version
            else
              res = SLICE_REF.send SLICE_REF.image_types[image_type.to_sym][:method], image, iso_path,
                                   ProjectHanlon.config.image_path
            end
            raise ProjectHanlon::Error::Slice::InternalError, res[1] unless res[0]
            raise ProjectHanlon::Error::Slice::InternalError, "Could not save image." unless SLICE_REF.insert_image(image)

            # fix 125 - add image local path to image end point
            @_lcl_image_path = ProjectHanlon.config.image_path + "/"

            image.set_lcl_image_path(ProjectHanlon.config.image_path)
            image.image_status, image.image_status_message = image.verify(image.image_path)

            # if it's a Windows image, add images for each of the sub-images contained within
            # the top-level (base) Windows image we just added
            if image_type == 'win'
              path_to_wim = Dir["#{image.image_path}/**/install.wim"][0]
              image_array = get_wim_subimages(image, path_to_wim)
              image_array.each { |sub_image|
                raise ProjectHanlon::Error::Slice::InternalError, "Could not save image #{sub_image.wim_index}." unless SLICE_REF.insert_image(sub_image)
              }
              return slice_success_object(SLICE_REF, :create_image, image_array, :success_type => :created)
            end

            slice_success_object(SLICE_REF, :create_image, image, :success_type => :created)
          end     # end POST /image

          resource '/:component', requirements: { component: /.*/ } do

            # GET /image/{component}
            # Handles GET operations for images (by UUID) and files from an image (by path)
            desc "retrieve details for an image (by UUID) or a file from an image (by path)"
            before do
              # only allow access to this resource from the Hanlon subnet
              unless request_is_from_hanlon_subnet(env['REMOTE_ADDR'])
                env['api.format'] = :text
                raise ProjectHanlon::Error::Slice::MethodNotAllowed, "Remote Access Forbidden; access to /image/#{component} resource is not allowed from outside of the Hanlon subnet"
              end
            end
            params do
              requires :component, type: String, desc: "The image UUID or path to the file"
            end
            get do
              component = params[:component]
              # test to see if the component looks more like a UUID, a request for the cloud-config
              # for a Microkernel, or a path to a component of an image that the user is interested in
              if is_uuid?(component)
                # it's a UUID, to retrieve the appropriate image and return it
                image_uuid = component
                image = SLICE_REF.get_object("images", :images, image_uuid)
                raise ProjectHanlon::Error::Slice::InvalidUUID, "Cannot Find Image with UUID: [#{image_uuid}]" unless image

                # fix 125 - add image local path to image end point
                @_lcl_image_path = ProjectHanlon.config.image_path + "/"

                image.set_lcl_image_path(ProjectHanlon.config.image_path)
                image.image_status, image.image_status_message = image.verify(image.image_path)

                raise ProjectHanlon::Error::Slice::InvalidUUID, "Cannot Find Image with UUID: [#{image_uuid}]" unless image && (image.class != Array || image.length > 0)
                slice_success_object(SLICE_REF, :get_image_by_uuid, image, :success_type => :generic)

              elsif image_uuid = get_cloud_config_req_uuid(component)
                # if here then the component represents a request for the cloud-config for a specific
                # instance (in this case the component looked something like 'mk/{UUID}/cloud-config',
                # where the {UUID} part of that string is the UUID of the Microkernel instance in question);
                # in that case, use the request UUID obtained above to retrieve the appropriate Microkernel
                # instance and return the cloud-config that should be used with that instance
                mk_image = SLICE_REF.get_object("images", :images, image_uuid)
                raise ProjectHanlon::Error::Slice::InvalidUUID, "Cannot Find Image with UUID: [#{image_uuid}]" unless mk_image

                # if get this far, then return the cloud_config for the Microkernel instance
                # that we just retrieved
                env['api.format'] = :text
                mk_image.cloud_config

              else
                # if it's not a UUID and it's not a request for a Microkernel cloud-config, then
                # assume it's a component of the image (so return the contents of that component)
                begin

                  path = component
                  # it's not a UUID, so treat it as a path to a file and return the component
                  # of the image that the user is interested in
                  filename = path.split(File::SEPARATOR)[-1]
                  #content_type "application/octet-stream"
                  header['Content-Disposition'] = "attachment; filename=#{filename}"
                  env['api.format'] = :binary

                  filepath = File.join(ProjectHanlon.config.image_path, path)
                  File.read(filepath)

                rescue Exception => e
                  puts "An exception occuring serving image path #{filepath}"
                  raise ProjectHanlon::Error::Slice::InputError, "Cannot find resource /image/#{component}"
                end

              end
            end    # end GET /image/{component}

            # DELETE /image/{component}
            # Handles DELETE operations for images (by UUID)
            desc "Remove an image (by UUID) and it's components"
            before do
              # only allow access to this resource from the Hanlon subnet
              unless request_is_from_hanlon_subnet(env['REMOTE_ADDR'])
                env['api.format'] = :text
                raise ProjectHanlon::Error::Slice::MethodNotAllowed, "Remote Access Forbidden; access to /image/{component} resource is not allowed from outside of the Hanlon subnet"
              end
            end
            params do
              requires :component, type: String, desc: "The image's UUID"
            end
            delete do
              component = params[:component]
              # test to ensure that the component looks like a UUID (and not the path to a component
              # of the image)
              if is_uuid?(component)
                # it's a UUID, to retrieve the appropriate image and return it
                image_uuid = component
                image = SLICE_REF.get_object("image_with_uuid", :images, image_uuid)
                raise ProjectHanlon::Error::Slice::InvalidUUID, "Cannot Find Image with UUID: [#{image_uuid}]" unless image && (image.class != Array || image.length > 0)
                # Use the Engine instance to remove the selected image from the database
                engine = ProjectHanlon::Engine.instance
                begin
                  # if it's a Windows image, then additional actions may be necessary (if it's a base image
                  # then all of the images that reference that base image should be removed; if it's not a
                  # base image but no other images reference the base image that it references, then the base
                  # image should be removed as well since it's no longer necessary)
                  if image.class == ProjectHanlon::ImageService::WindowsInstall
                    if image.uuid == image.base_image_uuid
                      # if here, then we're removing a base image; need to find all of the
                      # images that reference this image, then check each to see if any of them
                      # are used in a model; first get a list of the images that reference this
                      # image as their base image
                      ref_images = get_referencing_images(image.uuid)
                      # then, check each of those to see if there are models that reference them;
                      # along the way construct a map of image UUIDs and the models that reference them
                      referenced_image_list = {}
                      ref_images.each { |ref_image|
                        matching_model_uuids = engine.get_models_using_image(ref_image.uuid)
                        referenced_image_list[ref_image.uuid] = matching_model_uuids unless matching_model_uuids.empty?
                      }
                      # if we found images used in models that reference this base image, then throw an error
                      raise ProjectHanlon::Error::Slice::CouldNotRemove, "Cannot remove Base Image [#{image.uuid}] because it is the base for one or more images that are used in the following models:  #{referenced_image_list}" unless referenced_image_list.empty?
                      # otherwise, remove the base image and the images that reference it
                      raise ProjectHanlon::Error::Slice::CouldNotRemove, "Could not remove Image [#{image.uuid}]" unless engine.remove_image(image)
                      ref_images.each { |ref_image|
                        raise ProjectHanlon::Error::Slice::CouldNotRemove, "Could not remove Referencing Image [#{ref_image.uuid}]" unless engine.remove_image(ref_image)
                      }
                    else
                      # if here, then we're in a non-base Windows image; since we're only removing a
                      # "referencing image" (and not a "base image"), we can simply try to remove the
                      # image we were asked to remove (and throw an error if we cannot remove it)
                      raise ProjectHanlon::Error::Slice::CouldNotRemove, "Could not remove Image [#{image.uuid}]" unless engine.remove_image(image)
                      # next, get the base_image_uuid from the image we just removed determine whether
                      # or not there are other images that reference that same base image
                      base_image_uuid = image.base_image_uuid
                      ref_images = get_referencing_images(base_image_uuid)
                      # if we didn't find any matching images, then we should also remove the
                      # underlying base image object (since it's no longer needed)
                      if ref_images.empty?
                        base_image = SLICE_REF.get_object("image_with_uuid", :images, base_image_uuid)
                        raise ProjectHanlon::Error::Slice::CouldNotRemove, "Could not remove Base Image [#{base_image_uuid}]" unless engine.remove_image(base_image)
                      end
                    end
                  else
                    # since this isn't a Windows image, we can simply attempt to remove the image we were
                    # asked to remove (and throw an error if we cannot remove it)
                    raise ProjectHanlon::Error::Slice::CouldNotRemove, "Could not remove Image [#{image_uuid}]" unless engine.remove_image(image)
                  end
                rescue RuntimeError => e
                  raise ProjectHanlon::Error::Slice::InternalError, e.message
                rescue Exception => e
                  # if got to here, then the Engine raised an exception
                  raise ProjectHanlon::Error::Slice::CouldNotRemove, e.message
                end
                slice_success_response(SLICE_REF, :remove_image_by_uuid, "Image [#{image.uuid}] removed", :success_type => :removed)
              else
                raise ProjectHanlon::Error::Slice::MethodNotAllowed, "Deletion of components of an image via the RESTful API is no allowed"
              end
            end    # end DELETE /image/{component}

          end    # end resource /image/{component}

        end     # end resource /image

      end

    end

  end

end
