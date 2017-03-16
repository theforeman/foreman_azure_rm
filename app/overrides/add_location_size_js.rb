Deface::Override.new(
                    :virtual_path => 'hosts/_form',
                    :name => 'add_location_size_js',
                    :insert_after => 'erb[loud]:contains("javascript")',
                    :text => "<% javascript 'foreman_azure_rm/azure_rm_size_from_location' %>"
)

Deface::Override.new(
                    :virtual_path => 'hosts/_form',
                    :name => 'add_vnet_subnets_js',
                    :insert_after => 'erb[loud]:contains("javascript")',
                    :text => "<% javascript 'foreman_azure_rm/azure_rm_subnet_from_vnet' %>"
)

Deface::Override.new(
                    :virtual_path => 'hosts/_form',
                    :name => 'add_location_callbacks_js',
                    :insert_after => 'erb[loud]:contains("javascript")',
                    :text => "<% javascript 'foreman_azure_rm/azure_rm_location_callbacks' %>"
)