// =============================================================================
// The javascript of the user management panel.
//
// IMPORTANT: the panel works WITHOUT javascript (the table, the toolbar and
// the filters are plain HTML forms), this file only adds the convenience:
//   - the checkboxes in the toolbar are enabled / disabled automatically,
//   - the header checkbox selects / deselects all rows,
//   - the assistant answers questions and controls the table.
// NOTA BENE: no animation, no browser alert() - the messages are rendered
// into the page (Bootstrap alerts).
// =============================================================================
(function () {
  "use strict";

  // Small function: the CSRF token of the page (Rails puts it into the head).
  function csrfToken() {
    var meta = document.querySelector('meta[name="csrf-token"]');
    return meta ? meta.getAttribute("content") : "";
  }

  // Small function: all Bootstrap tooltips of the page.
  // NOTE: the title attributes of the toolbar buttons and of the checkboxes
  // are shown as tooltips.
  function initTooltips() {
    if (typeof bootstrap === "undefined") return;

    document.querySelectorAll('[data-bs-toggle="tooltip"]').forEach(function (element) {
      if (bootstrap.Tooltip.getInstance(element)) return;
      new bootstrap.Tooltip(element, { container: "body", delay: { show: 200, hide: 0 } });
    });
  }

  // ===========================================================================
  // The selection of the table rows.
  // ===========================================================================
  function initSelection() {
    var table = document.getElementById("users-table");
    if (!table) return;

    var selectAll = document.getElementById("select-all");
    var rows = Array.prototype.slice.call(table.querySelectorAll("tbody tr[data-user-id]"));
    var checkboxes = rows.map(function (row) { return row.querySelector(".row-checkbox"); }).filter(Boolean);

    var blockButton = document.getElementById("block-selected");
    var unblockButton = document.getElementById("unblock-selected");
    var deleteButton = document.getElementById("delete-selected");
    var countElement = document.getElementById("selection-count");

    // Small function: recalculates the state of the toolbar.
    // IMPORTANT: the toolbar is ALWAYS visible, only the buttons are enabled
    // or disabled.
    function refreshToolbar() {
      var selected = checkboxes.filter(function (checkbox) { return checkbox.checked; });
      var selectedRows = selected.map(function (checkbox) { return checkbox.closest("tr"); });
      var anyBlocked = selectedRows.some(function (row) { return row.dataset.blocked === "true"; });
      var anyActive = selectedRows.some(function (row) { return row.dataset.blocked !== "true"; });

      if (blockButton) blockButton.disabled = selected.length === 0 || !anyActive;
      if (unblockButton) unblockButton.disabled = selected.length === 0 || !anyBlocked;
      if (deleteButton) deleteButton.disabled = selected.length === 0;
      if (countElement) countElement.textContent = String(selected.length);

      // NOTE: the selected rows are marked, so that the selection is visible
      // in the table itself.
      rows.forEach(function (row) {
        var checkbox = row.querySelector(".row-checkbox");
        row.classList.toggle("is-selected", !!checkbox && checkbox.checked);
      });

      if (selectAll) {
        var total = checkboxes.length;
        selectAll.checked = total > 0 && selected.length === total;
        selectAll.indeterminate = selected.length > 0 && selected.length < total;
      }
    }

    // Small function: the ids of the ticked rows.
    function selectedIds() {
      return checkboxes.filter(function (checkbox) { return checkbox.checked; })
                       .map(function (checkbox) { return parseInt(checkbox.value, 10); });
    }

    // Small function: ticks / unticks every row.
    function setAll(checked) {
      checkboxes.forEach(function (checkbox) { checkbox.checked = checked; });
      refreshToolbar();
    }

    checkboxes.forEach(function (checkbox) {
      checkbox.addEventListener("change", refreshToolbar);
    });

    if (selectAll) {
      selectAll.addEventListener("change", function () { setAll(selectAll.checked); });
    }

    // NOTE: clicking anywhere in the row toggles the checkbox - a small
    // convenience that does not change the markup of the table.
    rows.forEach(function (row) {
      row.addEventListener("click", function (event) {
        if (event.target.classList.contains("row-checkbox")) return;
        var checkbox = row.querySelector(".row-checkbox");
        if (!checkbox) return;
        checkbox.checked = !checkbox.checked;
        refreshToolbar();
      });
    });

    // IMPORTANT: the assistant uses these two functions to control the table.
    window.UserTable = {
      selectedIds: selectedIds,
      refreshToolbar: refreshToolbar,
      selectIds: function (ids) {
        setAll(false);
        (ids || []).forEach(function (id) {
          var checkbox = checkboxes.filter(function (item) { return parseInt(item.value, 10) === id; })[0];
          if (checkbox) checkbox.checked = true;
        });
        refreshToolbar();
      },
      clearSelection: function () { setAll(false); }
    };

    refreshToolbar();
  }

  // ===========================================================================
  // Reloads the table without a full page reload (used by the assistant).
  // ===========================================================================
  function reloadTable(params) {
    var url = new URL(window.location.href);
    url.search = new URLSearchParams(params).toString();

    return fetch(url.toString(), { headers: { "X-Requested-With": "fetch" }, credentials: "same-origin" })
      .then(function (response) { return response.text(); })
      .then(function (html) {
        var parsed = new DOMParser().parseFromString(html, "text/html");

        var oldTable = document.getElementById("users-table");
        var newTable = parsed.getElementById("users-table");
        if (oldTable && newTable) {
          oldTable.replaceWith(newTable);
        }

        var oldSummary = document.getElementById("table-summary");
        var newSummary = parsed.getElementById("table-summary");
        if (oldSummary && newSummary) {
          oldSummary.innerHTML = newSummary.innerHTML;
        }

        // NOTE: the new table has new checkboxes -> the toolbar is refreshed.
        initSelection();
        initTooltips();
      })
      .catch(function () { window.location.reload(); });
  }

  // ===========================================================================
  // The assistant: questions and commands.
  // ===========================================================================
  function initAssistant() {
    var form = document.getElementById("assistant-form");
    if (!form) return;

    // NOTE: the ids of the elements are generated by getUniqIdValue, therefore
    // the javascript uses the data attributes to find them.
    var input = form.querySelector("[data-assistant-input]");
    var output = document.getElementById("assistant-output");
    var answerElement = document.querySelector("#assistant-output .assistant-answer-text");
    var planElement = document.querySelector("#assistant-output .assistant-plan");
    var runButton = document.getElementById("assistant-run");
    var clearButton = document.getElementById("assistant-clear");

    // Small function: applies the actions the assistant asked for.
    function applyActions(actions) {
      (actions || []).forEach(function (action) {
        if (action.type === "select_users" && window.UserTable) {
          window.UserTable.selectIds(action.ids);
        } else if (action.type === "clear_selection" && window.UserTable) {
          window.UserTable.clearSelection();
        } else if (action.type === "set_filter") {
          var filters = action.filters || {};
          var params = new URLSearchParams(window.location.search);
          params.set("status", filters.status || "all");
          if (filters.q) { params.set("q", filters.q); } else { params.delete("q"); }
          reloadTable(params);
        } else if (action.type === "sort_by") {
          var sortParams = new URLSearchParams(window.location.search);
          sortParams.set("sort", action.sort);
          sortParams.set("direction", action.direction || "desc");
          reloadTable(sortParams);
        } else if (action.type === "reload") {
          reloadTable(new URLSearchParams(window.location.search));
        }
      });
    }

    form.addEventListener("submit", function (event) {
      event.preventDefault();
      if (!input) return;

      var command = input.value.trim();
      if (!command) {
        input.focus();
        return;
      }

      var selectedIds = window.UserTable ? window.UserTable.selectedIds() : [];

      if (runButton) {
        runButton.disabled = true;
        runButton.innerHTML = '<span class="spinner-border spinner-border-sm me-1" aria-hidden="true"></span>Working';
      }

      fetch("/api/v1/assistant/command", {
        method: "POST",
        credentials: "same-origin",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": csrfToken()
        },
        body: JSON.stringify({ command: command, selected_ids: selectedIds })
      })
        .then(function (response) { return response.json(); })
        .then(function (data) {
          if (output) output.classList.remove("d-none");
          if (answerElement) answerElement.textContent = data.answer || data.error || "No answer.";
          if (planElement) {
            planElement.textContent = JSON.stringify({
              engine: data.engine,
              plan: data.plan,
              api_calls: data.api_calls,
              ui_actions: data.ui_actions
            }, null, 2);
          }
          applyActions(data.ui_actions);
        })
        .catch(function (error) {
          if (output) output.classList.remove("d-none");
          if (answerElement) answerElement.textContent = "The assistant is not reachable: " + error.message;
        })
        .finally(function () {
          if (runButton) {
            runButton.disabled = false;
            runButton.innerHTML = '<i class="bi bi-send me-1" aria-hidden="true"></i>Run';
          }
        });
    });

    if (clearButton) {
      clearButton.addEventListener("click", function () {
        if (output) output.classList.add("d-none");
        if (input) { input.value = ""; input.focus(); }
      });
    }

    // NOTE: the example buttons put their text into the input field.
    document.querySelectorAll("[data-assistant-example]").forEach(function (button) {
      button.addEventListener("click", function () {
        if (input) {
          input.value = button.getAttribute("data-assistant-example");
          input.focus();
        }
      });
    });  }

  // ===========================================================================
  // The button that shows the password (the sign in and the registration).
  // ===========================================================================
  function initPasswordToggles() {
    document.querySelectorAll("[data-toggle-password]").forEach(function (button) {
      if (button.dataset.togglePasswordBound) return;
      button.dataset.togglePasswordBound = "true";

      button.addEventListener("click", function () {
        var input = document.getElementById(button.getAttribute("data-toggle-password"));
        if (!input) return;

        var hidden = input.type === "password";
        input.type = hidden ? "text" : "password";
        button.setAttribute("aria-label", hidden ? "Hide the password" : "Show the password");

        var icon = button.querySelector("i");
        if (icon) icon.className = hidden ? "bi bi-eye-slash" : "bi bi-eye";

        if (typeof bootstrap !== "undefined" && bootstrap.Tooltip.getInstance(button)) {
          bootstrap.Tooltip.getInstance(button).setContent({ ".tooltip-inner": hidden ? "Hide the password" : "Show the password" });
        }
      });
    });
  }

  document.addEventListener("DOMContentLoaded", function () {
    initTooltips();
    initSelection();
    initAssistant();
    initPasswordToggles();
  });
})();
