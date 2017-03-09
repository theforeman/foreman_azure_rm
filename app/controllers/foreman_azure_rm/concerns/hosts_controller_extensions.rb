module ForemanAzureRM
  module Concerns
    module HostsControllerExtensions

      def sizes
        if (azure_rm_resource = Image.unscoped.find_by_uuid(params[:image_id])).present?
          resource = azure_rm_resource.compute_resource
          render :json => resource.vm_sizes(params[:location_string])
        else
          no_sizes = ('The location you selected has no sizes associated with it')
          render :json => "[\"#{no_sizes}\"]"
        end
      end
    end
  end
end