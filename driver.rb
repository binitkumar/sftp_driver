require 'aws/s3'
require 'yaml'
require 'vfs'
require 'pathname'
require "em-ftpd"

class Driver
  def initialize(aws_object = AWS::S3::S3Object, dir_descriptor = 'dir_descriptor.conf' )

    #loading configuration
    settings = YAML.load_file('settings.yml')
    @config = settings['s3']

    @aws_object = aws_object

    #Creating virtual directory sandbox
    @sandbox = $sandbox || './sandbox'.to_dir.destroy
    @sandbox.create

    @descriptor_file = dir_descriptor

    #loading previously created file and directory
    descriptor = File.new(@descriptor_file,'r')
    while(line = descriptor.gets)
      # All the fies has prefix of file_ otherwise it's a directory
      if line[0..4] == 'file_'
        @sandbox[ line[5..-1].strip ].write 'x'
      else
        @sandbox[line.strip].create
      end
    end

    #Establishing AWS connection
    AWS::S3::Base.establish_connection!(:access_key_id => ENV['access_key_id'], :secret_access_key => ENV['secret_access_key'])
  end

  #Mehtod for authentication of user using user name and password
  #If the user is valid user then a directory with name is being created
  def authenticate(username, password )

    #loading user details file
    user_file = File.new("user_details.conf", "r")
	  user_file = File.new("test_user_details.conf", "r") if $mode == 'test'

    while (line = user_file.gets)
      user_info = line.split(',')

      #If user info exists in the user details file then user is authenticated
	    if user_info[0] == username && user_info[1] == password

        #if user already have directory then there is no need to create a new directory
        if @sandbox[username].exist? == false
          update_descriptor("./sandbox/#{username}")
	        @sandbox[username].create
        end

        #Setting username for the future use
        @username = username

	      yield true
        return
	    end
    end
    yield false
  end

  #To place non-streamed file on AWS Server
  def put_file(path, tmp_file_path)
    path = parse_path(path)
    @aws_object.store(path, open(tmp_file_path), ENV['bucket'])   if $mode != 'test'
    #Updating sandbox for file
    @sandbox[path].write 'x'

    #Updating directory descriptor for directory persistence
    update_descriptor('file_'+path)
    yield File.size(tmp_file_path)
  end

  #To place streamed file on aws server
  def put_file_streamed(path,file_stream)
    path = parse_path(path)
    dir_address = Pathname(path).parent.to_s
    @sandbox[dir_address].create

    #Temprory hosting the file on virtual space
    File.open(path, 'ab+') do |f|
      f.write(file_stream.data)
    end


    file_size = File.size(path)

    #Posting the streamed file to aws
    @aws_object.store(path, open(path), ENV['bucket'])  if $mode != "test"

    #overwriting the file with zero byte file
    @sandbox[path].write 'x'
    update_descriptor('file_'+path)
    yield file_size
  end
  
  def bytes(path)
    path = parse_path(path)
    if @aws_object.exists?(path,ENV['bucket'])
      yield @aws_object.find(path,ENV['bucket'])['content-length']
      return
    end
    yield nil
  end
  
  def change_dir(path)
    path = parse_path(path)
    permission_pattern = /#{@username}/
    if path.match(permission_pattern).nil? == false
      yield true
      return
    else
      yield false
      return
    end
  end

  #listing of files and folders of a specific path
  def dir_contents(path)
    files = Array.new
    path = parse_path(path)
    @vfs = @sandbox[path]

    #if the path doesn't exist then it will show blank else the contents
    if @vfs.exist? == false
      yield []
    else
      @vfs.entries.each do |d|
        #converting all files to event machine format to match em-ftpd required format
        files << EM::FTPD::DirectoryItem.new(:name => d.name,
                              :time => d.created_at,
                              :permissions => 777,
                              :owner => @username,
                              :group => 1,
                              :size => ( @aws_object.exists?(d.name,ENV['bucket']) ? @aws_object.find(d.name,ENV['bucket'])['content-length'] : 0 ),
                              :directory => d.dir? ? true : false)
        end
        yield files
    end
  end

  #Deletion of a directory
  def delete_dir(path)
    path = parse_path(path)
    update_descriptor(path,'delete')
    @sandbox[path].entries.each do |file|
      if file.dir? == false
        #Deleting all the files from aws server
        if @aws_object.find(file,ENV['bucket'])
          @aws_object.delete(file, ENV['bucket'])
        end
      end
      update_descriptor(file,'delete')
    end

    @sandbox[path].destroy
    yield true
  end

  #Deletion of a file
  def delete_file(path)
    path = parse_path(path)
    #Deletion of file from aws server
    if @aws_object.find(path,ENV['bucket'])
      @aws_object.delete(path, ENV['bucket'])
    end
    update_descriptor('file_' + path,'delete')

    #Deletion from virtual directory
    @sandbox[path].destroy
    yield true
  end

  #Rename a file
  def rename(from_path, to_path)
    from_path = parse_path(from_path)
    to_path = parse_path(to_path)

    if @aws_object.find(from_path,ENV['bucket'])
      @aws_object.rename(from_path,to_path, ENV['bucket'])
    end
    if @sandbox[from_path].dir?
      @sandbox[from_path].destroy
      @sandbox[to_path].create
    else
      @sandbox[from_path].destroy
      @sandbox[to_path].write 'x'
    end
    from_path = 'file_' + from_path
    to_path = 'file_' + to_path
    update_descriptor(from_path,'rename',to_path)

    yield true
  end

  #Create a new directory
  def make_dir(path)
    path = parse_path(path)
    update_descriptor(path)
    @sandbox[path].create
    yield true
  end

  #Download file from server
  def get_file(path)
    path = parse_path(path)
    aws_file = @aws_object.find(path, ENV['bucket'])
    yield aws_file.value
  end

  #Method to update directory descriptor
  def update_descriptor(path,method='create',dest_path=nil)
    descriptor = File.new(@descriptor_file,'a+')

    if method == 'create'
      descriptor.puts(path)
      descriptor.close
    else
      file_list = Array.new
      if method == 'delete'
        descriptor.each do |line|
          if line.chomp != path.chomp
            file_list.push line
          end
        end
      end
      if method == 'rename'
        descriptor.each do |line|
          if line.chomp == path.chomp
            file_list.push dest_path
          else
            file_list.push line
          end
        end
      end
      descriptor.close
      updated_descriptor = File.new(@descriptor_file,"w")
      file_list.each do |line|
        updated_descriptor.puts line
      end
      updated_descriptor.close
    end
  end


  private
  #internal method to convert windows path to system specific path
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


end