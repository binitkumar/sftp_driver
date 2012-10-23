When  /^User attempts to login with invalid username or password$/ do
  require 'net/ftp'
  @ftp = Net::FTP.new
  @ftp.connect('127.0.0.1', 4000)
  begin
    @ftp.login('binit', 'invalidpass')
  rescue Exception => exp

  end

end
Then /^Server should give invalid login message$/ do
  @ftp.welcome.should == nil
end

When /^User attempts to login with valid username and password$/ do
  require 'net/ftp'
  @ftp = Net::FTP.new
  @ftp.connect('127.0.0.1', 4000)
  @ftp.login('binit','binit')
end
Then /^Server should give valid login message$/ do
  @ftp.welcome.chomp.should == '230 OK, password correct'
end

And /^User gets the listing of directory$/ do
 @ftp.list do |file|
   file.split(' ')[2].should == 'binit'
 end
end

Then /^User creates a new directory$/ do
 @ftp.mkdir('new_test_dir')
end
And /^User switches to new directory$/ do
 @ftp.chdir('new_test_dir')
end
Then /^User puts new file in latest directory$/ do
 @ftp.put('testdata/dummy_file.txt')
end
Then /^User finds the new file in the directory$/ do
 @ftp.list('new_test_dir') do |file|
   puts file
 end
end
When /^User downloads the file form the server$/ do

end
Then /^User gets the file as he had uploaded$/ do

end