require 'aws/s3'
require 'yaml'
require 'vfs'

class Driver
  def initialize
    settings = YAML.load_file('settings.yml')
    @config = settings['s3']
    @sandbox = $sandbox || './sandbox'.to_dir.destroy

    descriptor = File.new("dir_discripter.conf",'r')
    while(line = descriptor.gets)
      if line[0..4] == 'file_'
        @sandbox[ line[5..-1] ].write x
      else
        @sandbox[line.strip].create
      end
    end
  end
  
  def authenticate(username, password )
    user_file = File.new("user_details.conf", "r")

	  user_file = File.new("test_user_details.conf", "r") if $mode == 'test'

    while (line = user_file.gets)
      user_info = line.split(',')
	    if user_info[0] == username && user_info[1] == password

        if @sandbox[username].exist? == false
          update_descriptor("./sandbox/#{username}")
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
    path = parse_path(path)
    AWS::S3::Base.establish_connection!(:access_key_id => ENV['access_key_id'], :secret_access_key => ENV['secret_access_key'])
    AWS::S3::S3Object.store(path, open(tmp_file_path), ENV['bucket'])
    @sandbox[path].write 'x'
    update_descriptor('file_'+path)
    yield File.size(tmp_file_path)
  end

  def put_file_streamed(path,file_stream)
    puts "##########AWS Path #########################{path}##############################"
    path = parse_path(path)
    file_stream.cmd_stor_streamed(path)
    AWS::S3::Base.establish_connection!(:access_key_id => ENV['access_key_id'], :secret_access_key => ENV['secret_access_key'])
    AWS::S3::S3Object.store(path, open(path), ENV['bucket'])
    @sandbox[path].write 'x'
    update_descriptor('file_'+path)
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
    else
      @vfs.entries.each do |d|
        files << EM::FTPD::DirectoryItem.new(:name => d.name,
                              :time => Time.now,
                              :permissions => 777,
                              :owner => @username,
                              :group => 1,
                              :size => 1,
                              :directory => d.dir? ? true : false)
        end
        yield files
    end
  end
  
  def delete_dir(path)
    path = parse_path(path)
    update_descriptor(path,'delete')
    @sandbox[path].destroy
    yield true
  end
  
  def delete_file(path)
    path = parse_path(path)
    update_descriptor('file_' + path,'delete')
    @sandbox[path].destroy
    yield true
  end
  
  def rename(from_path, to_path)
    yield false
  end
  
  def make_dir(path)
    puts "###############aaaaaaaaaaaaa#####################{path}###################"
    path = parse_path(path)
    puts "###############bbbbbbbbbbbbb#####################{path}###################"
    update_descriptor(path)
    @sandbox[path].create
    yield true
  end
  
  def get_file(path)
    path = parse_path(path)
    AWS::S3::Base.establish_connection!(:access_key_id => ENV['access_key_id'], :secret_access_key => ENV['secret_access_key'])
    file = AWS::S3::S3Object.find(path, ENV['bucket'])
    yield file.value
  end

  def parse_path(path)
    path_suffix = path.split('C:/')[-1]

    path_suffix = '/' + path_suffix if path_suffix && path_suffix[0] != '/'

    if path_suffix.nil? == false && path_suffix != ''
      path = './sandbox' + path_suffix
      path = path.gsub('/C:','')
    else
      path = './sandbox'
    end
    path
  end

  def update_descriptor(path,method='create',dest_path=nil)
    descriptor = File.new("dir_discripter.conf",'a+')

    if method == 'create'
      descriptor.puts(path)
    elsif method == 'delete'

    elseif method == 'rename'

    end

  end
end