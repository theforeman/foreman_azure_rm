module ForemanAzureRM
  module Concerns
    module HostsControllerExtensions

      def sizes
        if (azure_rm_resource = Image.unscoped.find_by_uuid(params[:image_id])).present?
          resource = azure_rm_resource.compute_resource
          render :json => resource.vm_sizes(params[:location_string])
        else
          no_sizes = _('The location you selected has no sizes associated with it')
          render :json => "[\"#{no_sizes}\"]"
        end
      end

      def subnets
        azure_rm_resource = Image.unscoped.find_by_uuid(params[:image_id]).compute_resource
        render :json => azure_rm_resource.subnets(params[:location])
      end

      def storage_accts
        if (azure_rm_resource = Image.unscoped.find_by_uuid(params[:image_id])).present?
          resource = azure_rm_resource.compute_resource
          render :json => resource.storage_accts(params[:location])
        else
          no_storage = _('The location you selected has no storage accounts')
          render :json => "[\"#{no_storage}\"]"
        end
      end

      def vnets
        if (azure_rm_resource = Image.unscoped.find_by_uuid(params[:image_id])).present?
          resource = azure_rm_resource.compute_resource
          render :json => resource.virtual_networks(params[:location])
        else
          no_vnets = _('The location you selected has no vNets')
          render :json => "[\"#{no_vnets}\"]"
        end
      end
    end
  end
end