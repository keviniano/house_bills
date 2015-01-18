//= require jquery
//= require jquery_ujs
//= require twitter/bootstrap
//= require jquery-ui/datepicker
//= require jquery-ui/autocomplete
//= require_self
//= require_tree .

// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults

$(document).ready(function(){

  $("#search-toggle-bills").click(function(event){
    toggleSearchForm("show_search_bills");
  });

  $("#search-toggle-account-entries").click(function(event){
    toggleSearchForm("show_search_account_entries");
  });

  function toggleSearchForm(cookieName){
    $("#search").slideToggle(600, function(){
      if ($("#search").is(":visible")) {
        $.cookie(cookieName, true);
      } else {
        $.removeCookie(cookieName);
      }
    });
  }

  $(".datepicker").datepicker({
    dateFormat: 'mm-dd-yy',
    showOtherMonths: true,
    selectOtherMonths: true
  });

  $(".view-bill").click(function(event){
    var t = $(event.target);
    var row = t.parents("tr").first().next();
    var cell = row.children().first();
    var successful = false;

    if (cell.children().length == 0) {
      $.ajax({
        url:      t.attr("data-url"),
        async:    false,
        success:  function(data){
          successful = true;
          cell.html(data);
        }
      });
    } else {
      successful = true;
    }

    if (successful == true) {
      event.preventDefault();
      row.toggle();
      if (row.is(":visible")) {
        t.text("Hide Details");
      } else {
        t.text("Show Details");
      }
    }
  });

  // Load Google visualization library if a chart element exists
  if ($('[data-chart]').length > 0) {
    $.getScript('https://www.google.com/jsapi', function (data, textStatus) {
      google.load('visualization', '1.0', { 'packages': ['corechart'], 'callback': function () {
        // Google visualization library loaded
        $('[data-chart]').each(function () {
          var div = $(this)
          // Fetch chart data
          $.getJSON(div.data('chart'), function (data) {
            // Create DataTable from received chart data
            var table = new google.visualization.DataTable();
            $.each(data.cols, function () { table.addColumn.apply(table, this); });
            table.addRows(data.rows);
            // Draw the chart
            var chart = new google.visualization.ChartWrapper();
            chart.setChartType(data.type);
            chart.setDataTable(table);
            chart.setOptions(data.options);
            chart.setOption('width', div.width());
            chart.setOption('height', div.height());
            chart.draw(div.get(0));
          });
        });
      }});
    });
  }

});

