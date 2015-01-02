//= require jquery
//= require jquery_ujs
//= require jquery-ui/datepicker
//= require jquery-ui/autocomplete
//= require twitter/bootstrap/dropdown
//= require twitter/bootstrap/tab
//= require twitter/bootstrap/alert
//= require twitter/bootstrap/tooltip
//= require twitter/bootstrap/popover
//= require twitter/bootstrap/collapse
//= require twitter/bootstrap/transition
//= require_self
//= require_tree .

// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults

$(document).ready(function(){

  $("#search-toggle").click(function(event){
    $("#search").toggle();
  });

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

