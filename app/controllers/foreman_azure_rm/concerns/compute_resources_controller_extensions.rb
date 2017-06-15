module ForemanAzureRM
  module Concerns
    module ComputeResourcesControllerExtensions
      include Api::Version2
      include Foreman::Controller::Parameters::ComputeResource

      def available_resource_groups
        compute_resource = ComputeResource.find_by_id(params[:id])
        @available_resource_groups = compute_resource.available_resource_groups
        render :available_resource_groups, :layout => 'api/v2/layouts/index_layout'
      end

      def available_sizes
        compute_resource = ComputeResource.find_by_id(params[:id])
        @available_sizes = compute_resource.vm_sizes(params[:region_id])
        render :available_sizes, :layout => 'api/v2/layouts/index_layout'
      end

      def action_permission
        case params[:action]
          when 'available_resource_groups', 'available_sizes'
            :view
          else
            super
        end
      end
    end
  end
end