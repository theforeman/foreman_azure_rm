module ForemanAzureRM
  module Concerns
    module HostsControllerExtensions

      def sizes
        if (azure_rm_resource = Image.unscoped.find_by_uuid(params[:image_id])).present?
          resource = azure_rm_resource.compute_resource
          render :json => resource.vm_sizes(params[:region_string]).map { |size| size.name }
        else
          no_sizes = _('The region you selected has no sizes associated with it')
          render :json => "[\"#{no_sizes}\"]"
        end
      end

      def subnets
        azure_rm_image = Image.unscoped.find_by_uuid(params[:image_id])
        if azure_rm_image.present?
          azure_rm_resource = azure_rm_image.compute_resource
          subnets           = azure_rm_resource.subnets(params[:region])
          if subnets.present?
            render :json => subnets
          else
            no_subnets = _('The selected region has no subnets')
            render :json => "[\"#{no_subnets}\"]"
          end
        else
          no_compute = _('The selected image has no associated compute resource')
          render :json => "[\"#{no_compute}\"]"
        end
      end
    end
  end
end
