require 'aws/s3'
require 'yaml'
require 'vfs'

class Driver
  def initialize
    settings = YAML.load_file('settings.yml')
    @config = settings['s3']
    @sandbox = $sandbox || './vfs_sandbox'.to_dir.destroy
  end
  
  def authenticate(username, password )
    user_file = nil
    if $mode == 'test'
      user_file = File.new("test_user_details.conf", "r")
	else
	  user_file = File.new("user_details.conf", "r")
	end
    while (line = user_file.gets)
      user_info = line.split(',')
	  if user_info[0] == username && user_info[1] == password
	    @sandbox[username].create
      @username = username
	    yield true
	    return
	  end
    end
    yield false
  end
  
  def put_file(path, tmp_file_path)
    load_configuration 
    AWS::S3::Base.establish_connection!(:access_key_id => ENV['access_key_id'], :secret_access_key => ENV['secret_access_key'])
    AWS::S3::S3Object.store(path, open(tmp_file_path), ENV['bucket'])

    yield File.size(tmp_file_path)
  end
  
  def bytes(path)
    yield nil
  end
  
  def change_dir(path)
    @vfs = @sandbox[path]
    yield true
  end
  
  def dir_contents(path)
    files = Array.new
    if path.split('C:/')[-1].nil? == false && path.split('C:/')[-1] != ''
      path = './vfs_sandbox/' + path.split('C:/')[-1]
      path = path.gsub('/C:','')
    else
      path = './vfs_sandbox'
    end

    @vfs = @sandbox[path]
    puts "#######################{path}##########################"
    #@vfs = @sandbox[@username] if path == '/' || path == 'C:/'
    @vfs.entries.each do |d|
      files << EM::FTPD::DirectoryItem.new(:name => d.name,
                                         :time => Time.now,
                                         :permissions => 777,
                                         :owner => 1,
                                         :group => 1,
                                         :size => 1,
                                         :directory =>  true)
    end
    yield files
  end
  
  def delete_dir(path)
    yield nil
  end
  
  def delete_file(path)
    yield false
  end
  
  def rename(from_path, to_path)
    yield false
  end
  
  def make_dir(path)
    if path.split('C:/')[-1]
      path = './vfs_sandbox/' + path.split('C:/')[-1]
      path = path.gsub('/C:','')
    else
      path = './vfs_sandbox'
    end
    @sandbox[path].create
    yield true
  end
  
  def get_file(path)
    yield nil
  end
end