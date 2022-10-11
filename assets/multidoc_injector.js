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
      document.body.addEventListener("click", function (ev) {
        if (!ev.target.matches(".nav-dropdown-container")) {
          Array.prototype.forEach.call(document.getElementsByClassName("dropdown-label"), function (el) {
            el.parentElement.classList.remove("nav-expanded")
          });
        }
        if (ev.target.matches(".dropdown-label")) {
          ev.target.parentElement.classList.add("nav-expanded")
        }
      })
  });
});
