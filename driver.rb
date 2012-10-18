require 'aws/s3'
require 'yaml'

class Driver
  def load_configuration
    settings = YAML.load_file('settings.yml')
    @config = settings['s3']	
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
	    user_dir_struct = File.new(username,'w+')
	    yield true
	    return
	  end
    end
    yield false
  end
  
  def put_file(path, tmp_file_path)
    load_configuration 
    AWS::S3::Base.establish_connection!(:access_key_id => @config['access_key_id'], :secret_access_key => @config['secret_access_key'])
    AWS::S3::S3Object.store(path, open(tmp_file_path), @config['bucket'])

    yield File.size(tmp_file_path)
  end
  
  def bytes(path)
    yield nil
  end
  
  def change_dir(path)
    yield false
  end
  
  def dir_contents(path)
    yield []
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
    yield false
  end
  
  def get_file(path)
    yield nil
  end
end