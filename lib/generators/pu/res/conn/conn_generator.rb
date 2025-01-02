# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Res
    class ConnGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator
      include PlutoniumGenerators::Concerns::ResourceSelector

      source_root File.expand_path("templates", __dir__)

      desc(
        "Create a connection between a resource and a portal\n\n" \
        "e.g. rails g pu:res:conn todo --dest=dashboard_portal"
      )

      # argument :name

      def start
        selected_resources = resources_selection
        @app_namespace = portal_option(:dest, prompt: "Select destination portal").camelize

        selected_resources.each do |resource|
          @resource_class = resource
          if app_namespace == "MainApp"
            insert_into_file "config/routes.rb",
              indent("register_resource ::#{resource}\n", 2),
              after: /.*Rails\.application\.routes\.draw do.*\n/
          else
            unless expected_parent_policy
              template "app/policies/resource_policy.rb",
                "packages/#{package_namespace}/app/policies/#{package_namespace}/#{resource.underscore}_policy.rb"
            end

            unless expected_parent_definition
              template "app/definitions/resource_definition.rb",
                "packages/#{package_namespace}/app/definitions/#{package_namespace}/#{resource.underscore}_definition.rb"
            end

            template "app/controllers/resource_controller.rb",
              "packages/#{package_namespace}/app/controllers/#{package_namespace}/#{resource.pluralize.underscore}_controller.rb"

            insert_into_file "packages/#{package_namespace}/config/routes.rb",
              indent("register_resource ::#{resource}\n", 2),
              before: /.*# register resources above.*/
          end
        end
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      attr_reader :app_namespace, :resource_class

      def package_namespace
        app_namespace.underscore
      end

      def resource_namespace
        app_namespace.underscore
      end

      def expected_parent_controller
        expected_parent_controller = "::#{resource_class.pluralize}Controller".safe_constantize
        expected_parent_controller if expected_parent_controller.present? && expected_parent_controller < ::ResourceController
      end

      def parent_controller
        expected_parent_controller || "#{app_namespace}::ResourceController"
      end

      def expected_parent_policy
        expected_parent_policy = "::#{resource_class.classify}Policy".safe_constantize
        expected_parent_policy if expected_parent_policy.present? && expected_parent_policy < ::ResourcePolicy
      end

      def parent_policy
        expected_parent_policy || "ResourcePolicy"
      end

      def expected_parent_definition
        expected_parent_definition = "::#{resource_class.classify}Definition".safe_constantize
        expected_parent_definition if expected_parent_definition.present? && expected_parent_definition < ::ResourceDefinition
      end

      def parent_definition
        expected_parent_definition || "ResourceDefinition"
      end

      def attributes
        resource_klass = resource_class.constantize
        resource_klass.content_columns.filter_map { |col|
          PlutoniumGenerators::ModelGeneratorBase::GeneratedAttribute.parse resource_class, "#{col.name}:#{col.type}"
        }
      rescue ActiveRecord::StatementInvalid
        say format_log("An error occurred while building attributes. Ensure any migrations have been run and try again.", :error), :red
        []
      end

      def default_policy_attributes
        attributes.select { |a| !a.rich_text? && !a.password_digest? && !a.token? }.map(&:attribute_name).map(&:to_sym)
      end

      def policy_attributes_for_create
        default_policy_attributes - [:created_at, :updated_at]
      end

      def policy_attributes_for_read
        default_policy_attributes
      end
    end
  end
end
