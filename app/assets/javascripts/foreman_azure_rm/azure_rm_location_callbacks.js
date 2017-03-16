/**
 * Created by tgregory on 3/13/17.
 */
function azure_rm_storage_accts_from_location() {
    var imageId = $('#host_compute_attributes_custom_data').val();
    var storage_accts = $('#azure_rm_storage_acct');
    var location = $('#azure_rm_location').val();
    if (typeof tfm == 'undefined') {  // earlier than 1.13
        foreman.tools.showSpinner();
    } else {
        tfm.tools.showSpinner();
    }
    $.ajax({
        data: { "image_id": imageId, "location": location },
        type: "get",
        url: "/azure_rm/storage_accts",
        complete: function() {
            reloadOnAjaxComplete('#azure_rm_storage_acct');
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
        success: function(request_accts) {
            storage_accts.empty();
            $.each(request_accts, function() {
                storage_accts.append($("<option />").val(this).text(this));
            });
        }
    });
}

function azure_rm_vnets_from_location() {
    var imageId = $('#host_compute_attributes_custom_data').val();
    var vnets = $('#azure_rm_vnet');
    var location = $('#azure_rm_location').val();
    if (typeof tfm == 'undefined') {  // earlier than 1.13
        foreman.tools.showSpinner();
    } else {
        tfm.tools.showSpinner();
    }
    $.ajax({
        data: { "image_id": imageId, "location": location },
        type: "get",
        url: "/azure_rm/vnets",
        complete: function() {
            reloadOnAjaxComplete('#azure_rm_storage_acct');
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
        success: function(request_vnets) {
            vnets.empty();
            $.each(request_vnets, function() {
                vnets.append($("<option />").val(this.id).text(this.name));
            });
        }
    });
}
