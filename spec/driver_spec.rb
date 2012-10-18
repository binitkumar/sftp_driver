load 'driver.rb'
$mode = 'test'
describe Driver do
  before(:all) do
    @driver = Driver.new
  end
  it "should authorise valid username and password" do
    response = nil;
	@driver.authenticate('test','test') do |resp| 
	  response = resp; 
	end
	response.should == true
  end
  
  it "should not authorise invalid username" do
    response = nil;
	@driver.authenticate('test','invalidpassword') do |resp| 
	  response = resp; 
	end
	response.should == false
  end
end