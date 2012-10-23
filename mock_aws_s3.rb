require 'aws/s3'


class MockAwsFile
  def value
    true
  end
end

class MockAwsS3 < AWS::S3::S3Object

  def initialize
    @file_hash = Hash.new
    @file_hash[ ENV['bucket'] ] = Hash.new

  end

  def store(path,data,bucket_name)
    @file_hash[bucket_name][path] = true
  end

  def exists?(path,bucket_name)
    if @file_hash[bucket_name] && @file_hash[bucket_name][path]
      true
    else
      false
    end
  end

  def find(path,bucket_name)
    if @file_hash[bucket_name].nil? == false && @file_hash[bucket_name][path].nil? == false
      return MockAwsFile.new
    else
      return false
    end
  end

  def delete(path,bucket_name)
    @file_hash[bucket_name][path] = nil
  end

  def rename(from_path,to_path,bucket_name)
    @file_hash[bucket_name][from_path] = nil
    @file_hash[bucket_name][to_path]   = true
  end
end