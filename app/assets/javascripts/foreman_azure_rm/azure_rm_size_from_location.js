/**
 * Created by tgregory on 3/9/17.
 */
function azure_rm_get_size_from_location() {
    var location = $('#azure_rm_location').val();
    var size_spinner = $('#azure_rm_size_spinner');
    var sizes = $('#azure_rm_size');
    var imageId = $('#host_compute_attributes_custom_data').val();
    if (typeof tfm == 'undefined') {  // earlier than 1.13
        foreman.tools.showSpinner();
    } else {
        tfm.tools.showSpinner();
    }
    size_spinner.removeClass('hide');
    $.ajax({
        data: {"location_string": location, "image_id": imageId},
        type: 'get',
        url: '/azure_rm/sizes',
        complete: function() {
            reloadOnAjaxComplete('#azure_rm_size');
            size_spinner.addClass('hide');
            if (typeof tfm == 'undefined') {  // earlier than 1.13
                foreman.tools.hideSpinner();
            } else {
                tfm.tools.hideSpinner();
            }
        },
        error: function(request, status, error) {
            console.log(request);
            console.log(error);
        },
        success: function(request_sizes) {
            sizes.empty();
            $.each(request_sizes, function() {
                sizes.append($("<option />").val(this).text(this));
            });
        }
    });
}