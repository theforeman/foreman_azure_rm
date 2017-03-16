//TODO figure out how to refresh modal

/**
 * Created by tgregory on 3/10/17.
 */
function azure_rm_subnet_from_vnet() {
    var vnet = $('#azure_rm_vnet').val();
    var imageId = $('#host_compute_attributes_custom_data').val();
    var subnets = $('#azure_rm_subnet');
    if (typeof tfm == 'undefined') {  // earlier than 1.13
        foreman.tools.showSpinner();
    } else {
        tfm.tools.showSpinner();
    }
    $.ajax({
        data: { "image_id": imageId, "vnet": vnet },
        type: "get",
        url: "/azure_rm/subnets",
        complete: function() {
            reloadOnAjaxComplete('#azure_rm_subnet');
            if (typeof tfm == 'undefined') {  // earlier than 1.13
                foreman.tools.hideSpinner();
            } else {
                tfm.tools.hideSpinner();
            }
        },
        error: function(request, status, error) {
            console.log(status);
            console.log(request);
            console.log(error);
        },
        success: function(request_subnets) {
            subnets.empty();
            $.each(request_subnets, function() {
               subnets.append($("<option />").val(this.id).text(this.name));
            });
        }
    });
}