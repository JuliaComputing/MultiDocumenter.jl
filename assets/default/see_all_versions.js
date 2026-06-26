function multiDocumenterSeeAllVersions() {
  var configEl = document.getElementById("multidoc-see-all-versions-config");
  if (!configEl) return;

  var config;
  try {
    config = JSON.parse(configEl.textContent);
  } catch (_err) {
    return;
  }
  if (!config || !config.target) return;

  var sentinel = config.sentinel || "__MULTIDOC_SEE_ALL_VERSIONS__";
  var label = config.label || "See All Versions";

  function selectors() {
    return document.querySelectorAll(
      ".docs-version-selector select, #documenter-version-selector",
    );
  }

  function rememberAndAppend() {
    var all = selectors();
    for (var i = 0; i < all.length; i++) {
      var sel = all[i];
      if (!sel.options.length) continue;
      if (sel.options[sel.options.length - 1].value === sentinel) continue;
      if (sel.dataset.seeAllPrevIdx === undefined) {
        sel.dataset.seeAllPrevIdx = String(Math.max(0, sel.selectedIndex));
      }
      var opt = document.createElement("option");
      opt.textContent = label;
      opt.value = sentinel;
      sel.appendChild(opt);
    }
  }

  function hasUninitializedSelector() {
    var all = selectors();
    for (var i = 0; i < all.length; i++) {
      if (!all[i].options.length) return true;
    }
    return false;
  }

  function pollForSelector() {
    var tries = 0;
    function step() {
      rememberAndAppend();
      if (!hasUninitializedSelector() || tries >= 120) return;
      tries += 1;
      setTimeout(step, 50);
    }
    setTimeout(step, 0);
  }

  function startup() {
    rememberAndAppend();
    if (hasUninitializedSelector()) {
      pollForSelector();
    }
    var primary = document.getElementById("documenter-version-selector");
    if (primary && window.MutationObserver) {
      new MutationObserver(rememberAndAppend).observe(primary, {
        childList: true,
        subtree: true,
      });
    }
  }

  var resetting = false;
  document.addEventListener(
    "change",
    function (ev) {
      if (resetting) return;
      var sel = ev.target;
      if (sel.tagName !== "SELECT") return;
      if (
        !sel.closest(".docs-version-selector") &&
        sel.id !== "documenter-version-selector"
      ) {
        return;
      }

      if (sel.value !== sentinel) {
        var idx = sel.selectedIndex;
        var all = selectors();
        for (var i = 0; i < all.length; i++) {
          all[i].dataset.seeAllPrevIdx = String(idx);
        }
        return;
      }

      ev.preventDefault();
      ev.stopImmediatePropagation();
      resetting = true;
      window.open(config.target, "_blank", "noopener");

      var prevIdx = parseInt(sel.dataset.seeAllPrevIdx, 10);
      if (isNaN(prevIdx) || prevIdx < 0) prevIdx = 0;
      var maxIdx = sel.options.length - 2;
      if (maxIdx < 0) maxIdx = 0;
      var clampedIdx = Math.min(Math.max(0, prevIdx), maxIdx);

      var all = selectors();
      for (var i = 0; i < all.length; i++) {
        if (!all[i].options.length) continue;
        all[i].selectedIndex = clampedIdx;
        all[i].dataset.seeAllPrevIdx = String(clampedIdx);
      }
      resetting = false;
    },
    true,
  );

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", startup);
  } else {
    startup();
  }
  window.addEventListener("load", rememberAndAppend);
}

if (
  document.readyState === "complete" ||
  document.readyState === "interactive"
) {
  setTimeout(multiDocumenterSeeAllVersions, 1);
} else {
  document.addEventListener("DOMContentLoaded", multiDocumenterSeeAllVersions);
}
