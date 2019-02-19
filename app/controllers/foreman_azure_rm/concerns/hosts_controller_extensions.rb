module ForemanAzureRM
  module Concerns
    module HostsControllerExtensions
      def sizes
        azure_rm_resource = Image.unscoped.find_by(uuid: params[:image_id])
        if azure_rm_resource.present?
          resource = azure_rm_resource.compute_resource
          vm_sizes = resource.vm_sizes(params[:location_string])
          render :json => vm_sizes.map(&:name)
        else
          no_sizes = _('Location you selected has no sizes associated with it')
          render :json => "[\"#{no_sizes}\"]"
        end
      end

      def subnets
        azure_rm_image = Image.unscoped.find_by(uuid: params[:image_id])
        if azure_rm_image.present?
          azure_rm_resource = azure_rm_image.compute_resource
          subnets           = azure_rm_resource.subnets(params[:location])
          if subnets.present?
            render :json => subnets
          else
            render_no_subnets
          end
        else
          render_no_compute
        end
      end

      def render_no_subnets
        no_subnets = _('The selected location has no subnets')
        render :json => "[\"#{no_subnets}\"]"
      end

      def render_no_compute
        no_compute = _('Selected image has no associated compute resource')
        render :json => "[\"#{no_compute}\"]"
      end
    end
  end
end
