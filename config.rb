require './driver.rb'
require 'yaml'
settings = YAML.load_file('settings.yml')

driver Driver
port settings['s3']['port'] 