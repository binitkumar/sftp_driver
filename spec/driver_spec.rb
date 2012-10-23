load 'driver.rb'
load 'mock_aws_s3.rb'
$mode = 'test'
describe Driver do
  before(:each) do

    File.new('test_dir_descriptor.conf','w').puts nil
    @aws_obj = MockAwsS3.new
    @driver = Driver.new(@aws_obj,'test_dir_descriptor.conf')

    #Creating virtual directory sandbox
    @sandbox = $sandbox || './sandbox'.to_dir.destroy
    @sandbox.create
  end

  class VirtualSocket
    def data
      return 'abcd'
    end
  end

  def check_existance_in_descriptor(path,option=true)
    descriptor = File.new('test_dir_descriptor.conf','r')
    entry_exists = false
    while(line = descriptor.gets)
      entry_exists = true if line.to_s.chomp == path
    end
    entry_exists.should == option
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
    check_existance_in_descriptor('./sandbox/test',false)

  end

  it "should put non-streamed files to the server" do
    response = nil
    @driver.put_file('testdata/dummy_file.txt','testdata/dummy_file.txt') do | resp |
      response = resp
    end
    response.should == File.new('testdata/dummy_file.txt').size

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

    Dir['./sandbox/streamed_file.txt'].length.should == 1
    check_existance_in_descriptor('file_' + './sandbox/streamed_file.txt')
  end

  it "should provide the file byte size" do
    #todo Implement new version of AWS S3 mock object.
    response = nil
    @driver.bytes('streamed_file.txt') do | resp |
      response = resp
    end
    response.should == nil
  end

  it "should allow change of directory if username is there in the path" do
    response = nil
    @driver.authenticate('test','test') do |resp|
      response = resp
    end

    #Varifying user authentication request
    response.should == true

    @driver.change_dir('test/folder1') do | resp |
      response = resp
    end
    response.should == true
  end

  it "should not allow change of directory if username is not there in the path" do
    response = nil
    @driver.authenticate('test','test') do |resp|
      response = resp
    end

    #Varifying user authentication request
    response.should == true

    @driver.change_dir('invalidpath/folder1') do | resp |
      response = resp
    end
    response.should == false
  end

  it "should list files and folders of the directory" do
    @sandbox['test/folder1/file1.txt'].write 'This is dummy data'
    @sandbox['test/folder2/file2.txt'].write 'This is dummy data'

    response = nil
    @driver.dir_contents('test') do |resp|
      response = resp
    end
    response.length.should == 2
    expected_string = 'folder1,,1,0,' + @sandbox['test/folder1'].created_at.to_s + ',777,true'
    response[0].to_s.should == expected_string

    expected_string = 'folder2,,1,0,' + @sandbox['test/folder2'].created_at.to_s + ',777,true'
    response[1].to_s.should == expected_string

    @driver.dir_contents('test/folder1') do |resp|
      response = resp
    end

    response.length.should == 1
    expected_string = 'file1.txt,,1,0,' + @sandbox['test/folder1/file1.txt'].created_at.to_s + ',777,false'
    response[0].to_s.should == expected_string

    @driver.dir_contents('test/folder2') do |resp|
      response = resp
    end

    response.length.should == 1
    expected_string = 'file2.txt,,1,0,' + @sandbox['test/folder2/file2.txt'].created_at.to_s + ',777,false'
    response[0].to_s.should == expected_string
  end

  it "should not list any file or folder if the path is invalid" do
    response = nil
    @driver.dir_contents('invalidpath') do |resp|
      response = resp
    end
    response.length.should == 0
  end



  it "should delete a directory " do
    @sandbox['test/folder1/file1.txt'].write 'Dummy file'

    response = nil
    @driver.delete_dir('test/folder1') do | resp |
      response = resp
    end
    response.should == true
    @sandbox["test/folder1/file1.txt"].exist?.should == false
    check_existance_in_descriptor('file_./sandbox/test/folder1/file1.txt',false)
    @sandbox["test/folder1"].exist?.should == false
    check_existance_in_descriptor('file_./sandbox/test/folder1',false)
  end

  it "should delete a file" do
    @sandbox['test/folder1/file1.txt'].write 'Dummy file'
    @driver.update_descriptor('file_./sandbox/test/folder1/file1.txt')

    response = nil
    @driver.delete_file('test/folder1/file1.txt') do | resp |
      response = resp
    end
    response.should == true
    @sandbox["test/folder1/file1.txt"].exist?.should == false
    check_existance_in_descriptor('file_./sandbox/test/folder1/file1.txt',false)
  end

  it "should rename a existing file or directory" do
    @sandbox['test/folder1/file1.txt'].write 'Dummy file'
    @driver.update_descriptor('file_./sandbox/test/folder1/file1.txt')

    response = nil
    @driver.rename('test/folder1/file1.txt','test/folder1/file2.txt') do | resp |
      response = resp
    end
    response.should == true
    @sandbox["test/folder1/file1.txt"].exist?.should == false
    check_existance_in_descriptor('file_./sandbox/test/folder1/file1.txt',false)
    @sandbox["test/folder1/file2.txt"].exist?.should == true
    check_existance_in_descriptor('file_./sandbox/test/folder1/file2.txt',true)

  end

  it "should make a directory" do
    response = nil
    @driver.make_dir('test/folder1') do | resp |
      response = resp
    end
    response.should == true
    @sandbox['test/folder1'].exist?.should == true
    check_existance_in_descriptor('./sandbox/test/folder1')
  end


  it "should give the file on request" do | resp |
    response = nil
    @aws_obj.store('./sandbox/file1.txt','abcd',ENV['bucket'])
    @driver.get_file('file1.txt') do |resp|
      response = resp
    end
  end
end