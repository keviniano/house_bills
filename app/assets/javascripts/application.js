//= require jquery
//= require jquery_ujs
//= require twitter/bootstrap
//= require_self
//= require_tree .

// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults

$(document).ready(function(){

  $(".datepicker").datepicker({ dateFormat: 'yy-mm-dd' });

  $("#accordion").accordion({ collapsible: true, active: false });

});

