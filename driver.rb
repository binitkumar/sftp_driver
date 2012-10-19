require 'aws/s3'
require 'yaml'
require 'vfs'

class Driver
  def initialize
    settings = YAML.load_file('settings.yml')
    @config = settings['s3']
    @sandbox = $sandbox || './vfs_sandbox'.to_dir.destroy

    descriptor = File.new("dir_discripter.conf",'r')
    while(line = descriptor.gets)
      @sandbox[line.strip].create
    end
  end
  
  def authenticate(username, password )
    user_file = File.new("user_details.conf", "r")

	  user_file = File.new("test_user_details.conf", "r") if $mode == 'test'

    while (line = user_file.gets)
      user_info = line.split(',')
	    if user_info[0] == username && user_info[1] == password

        if @sandbox[username].exist? == false
          update_descriptor(username)
	        @sandbox[username].create
        end
        @username = username
	      yield true
	      return
	    end
    end
    yield false
  end
  
  def put_file(path, tmp_file_path)
    puts "##########AWS Path #########################{path}##############################"
    #AWS::S3::Base.establish_connection!(:access_key_id => ENV['access_key_id'], :secret_access_key => ENV['secret_access_key'])
    #AWS::S3::S3Object.store(path, open(tmp_file_path), ENV['bucket'])
    path = parse_path(path)
    @sandbox[path].write 'x'
    yield File.size(tmp_file_path)
  end
  
  def bytes(path)
    yield nil
  end
  
  def change_dir(path)
    permission_pattern = /@username/
    if permission_pattern.match(path).nil? == false
      yield false
    else
      yield true
    end
  end
  
  def dir_contents(path)
    files = Array.new
    path = parse_path(path)
    @vfs = @sandbox[path]
    if @vfs.exist? == false
      yield []
    end
    @vfs.entries.each do |d|
      is_dir = true
      if d.dir?
        is_dir = true
      else
        is_dir = false
      end
      files << EM::FTPD::DirectoryItem.new(:name => d.name,
                                         :time => Time.now,
                                         :permissions => 777,
                                         :owner => 1,
                                         :group => 1,
                                         :size => 1,
                                         :directory =>  is_dir)
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
    path = parse_path(path)
    update_descriptor(path)
    @sandbox[path].create
    yield true
  end
  
  def get_file(path)
    yield nil
  end

  def parse_path(path)
    if path.split('C:/')[-1].nil? == false && path.split('C:/')[-1] != ''
      path = './vfs_sandbox/' + path.split('C:/')[-1]
      path = path.gsub('/C:','')
    else
      path = './vfs_sandbox'
    end
    path
  end

  def update_descriptor(path)
    descriptor = File.new("dir_discripter.conf",'a+')
    descriptor.puts(path)
  end

end