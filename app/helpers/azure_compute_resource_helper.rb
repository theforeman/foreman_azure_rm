module AzureComputeResourceHelper
  def regions_list(azurerm_cr, f)
    begin
      regions = azurerm_cr.regions || []
    rescue StandardError
      #do nothing
      regions = []
    rescue Exception => ex
      return information_box("Regions could not be loaded due to exception: #{ex}")
    end
    selectable_f(f, :url, regions, {},
                 {:label => _('Azure Region'),
                  :disabled => regions.empty?,
                  :required => true,
                  :help_inline_permanent => load_button_f(f, regions.present?, _("Load Regions"))
                 })
  end
  def azure_doc_version
    doc_version = Foreman::Plugin.find(:foreman_azure_rm).version.scan(/\d+\.\d+/).first + '.x'
  end
end
