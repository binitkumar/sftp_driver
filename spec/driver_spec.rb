load 'driver.rb'

$mode = 'test'
describe Driver do
  before(:each) do
    $virtual_aws = Hash.new
    if Dir['./sandbox/test'].length == 1
      FileUtils.rm_rf('./sandbox/test')
    end
    File.new('test_dir_descriptor.conf','w').puts nil
    @driver = Driver.new

    @sandbox = $sandbox || './sandbox'.to_dir.destroy
    @sandbox.create
  end

  class VirtualSocket
    def data
      return 'abcd'
    end
  end

  def check_existance_in_descriptor(path)
    descriptor = File.new('test_dir_descriptor.conf','r')
    entry_exists = false
    while(line = descriptor.gets)
      entry_exists = true if line.to_s.chomp == path
    end
    entry_exists.should == true
  end
  it "should authorise valid username and password and create directory for that user" do
    response = nil
	  @driver.authenticate('test','test') do |resp|
	    response = resp
    end

    #Varifying user authentication request
	  response.should == true

    #Verifying direcotry with username created or not
    Dir[ './sandbox/test'].length.should == 1

    #vefirying directory descriptor updated or not
    check_existance_in_descriptor './sandbox/test'.to_s.chomp

  end
  
  it "should not authorise invalid username" do
    response = nil
	  @driver.authenticate('test','invalidpassword') do |resp|
	    response = resp
    end

    #verifying invalid user authentication request
	  response.should == false

    #Verifying direcotry with username created or not
    Dir[ './sandbox/test'].length.should == 0

    #vefirying directory descriptor updated or not
    descriptor = File.new('test_dir_descriptor.conf','r')
    entry_exists = false
    while(line = descriptor.gets)
      entry_exists = true if line.to_s.chomp == './sandbox/test'.to_s.chomp
    end
    entry_exists.should == false
  end

  it "should put non-streamed files to the server" do
    response = nil
    @driver.put_file('testdata/dummy_file.txt','testdata/dummy_file.txt') do | resp |
      response = resp
    end
    response.should == File.new('testdata/dummy_file.txt').size
    $virtual_aws['path'].should == './sandbox/testdata/dummy_file.txt'
    $virtual_aws['bucket'].should == ENV['bucket']

    check_existance_in_descriptor 'file_./sandbox/testdata/dummy_file.txt'

  end

  it "should put streamed file on server" do
    file_stream = VirtualSocket.new
    response = nil
    @driver.put_file_streamed('streamed_file.txt',file_stream) do | resp |
      response = resp
    end

    temp_file = File.new('testdata/test_dummy_file','w')
    temp_file.write('abcd')

    response.should == temp_file.size

    $virtual_aws['path'].should == './sandbox/streamed_file.txt'
    $virtual_aws['bucket'].should == ENV['bucket']

    @sandbox['streamed_file.txt'].exist?.should == true
    check_existance_in_descriptor('file_' + './sandbox/streamed_file.txt')

    FileUtils.rm_rf('./sandbox/streamed_file.txt')
  end

  it "shoud provide the file byte size" do
    @driver.bytes('streamed_file.txt') do | resp |
      response = resp
    end
    resp.should == nil
  end


end