// injected into documenter.js by MultiDocumenter.jl
require(['jquery', 'headroom', 'headroom-jquery'], function($, Headroom) {
    $(document).ready(function() {
        $('#multi-page-nav').headroom({
        "tolerance": {"up": 10, "down": 10},
        });
    })
})
