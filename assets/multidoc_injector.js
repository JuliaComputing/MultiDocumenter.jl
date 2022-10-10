// injected into documenter.js by MultiDocumenter.jl
// require(["jquery", "headroom", "headroom-jquery"], function ($, Headroom) {
//   $(document).ready(function () {
//     $("#multi-page-nav").headroom({
//       tolerance: { up: 10, down: 10 },
//     });
//   });
// });
require(["jquery"], function ($) {
  $(document).ready(function () {
    document
      .getElementById("multidoc-toggler")
      .addEventListener("click", function () {
        document
          .getElementById("nav-items")
          .classList.toggle("hidden-on-mobile");
      });
      Array.prototype.map.call(document.getElementsByClassName("dropdown-label"), function (el) {
      el.addEventListener("click", function () {
        el.parentElement.classList.toggle("nav-expanded")
      })
    })
  });
});
