require File.dirname(__FILE__) + '/../test_helper'
require 'activemessaging/test_helper'
require File.dirname(__FILE__) + '/../../app/processors/application'

class CloudAddedProcessorTest < Test::Unit::TestCase
  include ActiveMessaging::TestHelper
  
  def setup
    load File.dirname(__FILE__) + "/../../app/processors/cloud_added_processor.rb"
    @processor = CloudAddedProcessor.new
  end
  
  def teardown
    @processor = nil
  end  

  def test_cloud_added_processor
    @processor.on_message('Your test message here!')
  end
end