# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved

require "json"

# Root ProjectRazor namespace
# @author Nicholas Weaver
module ProjectRazor
  module Slice

    # ProjectRazor Slice Policy
    # Used for policy rule management
    # @author Nicholas Weaver
    class Policy < ProjectRazor::Slice::Base
      # Initializes ProjectRazor::Slice::Model including #slice_commands, #slice_commands_help, & #slice_name
      # @param [Array] args
      def initialize(args)
        super(args)
        # Here we create a hash of the command string to the method it corresponds to for routing.
        @slice_commands = {:add => "add_policy",
                           :get => "get_policy",
                           :default => "get_policy",
                           :remove => "remove_policy"}
        @slice_commands_help = {:add => "policy add " + "(type)".blue +
                                        " (name)".blue + " (model config uuid)".blue + " (tag{,tag,tag})".blue,
                                :get => "policy ".red + "{get [rule|type|model [config|type]}".blue,
                                :remove => "policy " + "(policy rule UUID)".yellow,
                                :default => "policy ".red + "{get [rule|type|model [config|type]}".blue,
                                "get model" => "policy get model [config|type] ".white + "(policy type)".red,
                                "get model config" => "policy get model config ".white + "(policy type)".red,
                                "get model type" => "policy get model type ".white + "(policy type)".red}
        @slice_name = "Policy"
      end


      #### Add

      def add_policy
        @command = :add
        policy_rules = ProjectRazor::PolicyRules.instance


        @policy_type_name = @command_array.shift
        unless policy_rules.is_policy_type?(@policy_type_name)
          slice_error("InvalidPolicyTypeProvided")
          return
        end




        @policy_label = @command_array.shift
        unless /^[\w ]+$/ =~ @policy_label
          slice_error("InvalidPolicyLabel")
          return
        end



        @model_config_uuid = @command_array.shift
        unless @model_config_uuid != nil
          slice_error("MustProvideModelConfigUUID")
          return
        end
        setup_data
        @model_config = @data.fetch_object_by_uuid(:model, @model_config_uuid)
        unless @model_config != nil
          slice_error("MustProvideModelConfigUUID")
          return
        end


        @tags = @command_array.shift
        unless @tags != nil
          slice_error("MustProvideAtLeastOneTag")
          return
        end

        @tags_array = @tags.split(",")

        unless @tags_array.count > 0
          slice_error("MustProvideAtLeastOneTag")
          return
        end


        new_policy_rule = policy_rules.new_policy_from_type_name(@policy_type_name)

        new_policy_rule.label = @policy_label
        new_policy_rule.model = @model_config
        new_policy_rule.tags = @tags_array

        new_policy_rule = policy_rules.add(new_policy_rule)
        unless new_policy_rule != nil
          slice_error("ErrorCreatingPolicyRule")
          return
        end

        print_policy_rules [new_policy_rule]
      end



      ####


      #### Remove

      def remove_policy
        @command = :remove
        policy_uuid = @command_array.shift

        unless validate_arg(policy_uuid)
          slice_error("MissingUUID")
          return
        end

        setup_data
        policy_rule= @data.fetch_object_by_uuid(:policy_rule, policy_uuid)

        unless policy_rule
          slice_error("CannotFindPolicyRule")
          get_policy
          return
        end

        if @data.delete_object(policy_rule)
          slice_success("PolicyRuleRemoved")
        else
          slice_error("PolicyRuleNotRemoved")
        end
      end


      ####



      #### Get

      def get_policy
        @command = :get
        @arg01 =  @command_array.shift

        case @arg01
          when "rule"
            get_policy_rules
          when "type"
            get_policy_types
          when "model"
            get_model
          when "help"
            slice_error("Help", false)
          else
            get_policy_rules
        end
      end

      def get_policy_rules
        print_policy_rules get_object("policy_rules", :policy_rule)
      end

      def get_policy_types
        policy_rules = ProjectRazor::PolicyRules.instance

        print_policy_types policy_rules.get_types
      end

      def get_model
        @command = "get model"
        @arg02 =  @command_array.shift

        case @arg02
          when "config"
            get_model_config
          when "type"
            get_model_types
          when "help"
            slice_error("Help")
          else
            slice_error("Help")
        end
      end

      def get_model_config
        @command = "get model config"
        policy_type_name =  @command_array.shift

        if policy_type_name == nil
          slice_error("MissingArgument")
        else
          policy_rules = ProjectRazor::PolicyRules.instance
          policy_type = nil
          policy_rules.get_types.each do
          |type|
            policy_type = type.policy_type if policy_type_name == type.policy_type.to_s
          end

          if policy_type != nil
            print_model_configs policy_rules.get_model_configs(policy_type)
          else
            slice_error("PolicyTypeNotFound")
          end
        end
      end

      def get_model_types
        @command = "get model type"
        policy_type_name =  @command_array.shift

        if policy_type_name == nil
          slice_error("MissingArgument")
        else
          policy_rules = ProjectRazor::PolicyRules.instance

          if policy_rules.is_policy_type?(policy_type_name)
            valid_model_types = []
            policy_rules.get_model_types.each do
            |type|
              valid_model_types << type if policy_type_name == type.model_type.to_s
            end
            print_model_types valid_model_types
          else
            slice_error("PolicyTypeNotFound")
          end
        end
      end

      ####








    end
  end
end
