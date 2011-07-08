# Load the rails application
require File.expand_path('../application', __FILE__)

# Initialize the rails application
HouseBills::Application.initialize!

Date::DATE_FORMATS[:default] = "%m-%d-%Y"
Time::DATE_FORMATS[:default] = "%m-%d-%Y %H:%M"

