# coding: utf-8

# Usage:
#
#   em-ftpd config.rb

$:.unshift(File.expand_path('../lib/', __FILE__))
require 's3-FTPS-server'

class FTPSDriver
  FILE_ONE = "This is the first file available for download.\n\nBy James"
  FILE_TWO = "This is the file number two.\n\n2009-03-21"

  # AWS::S3::DEFAULT_HOST = 's3-ap-northeast-1.amazonaws.com'

  def initialize(mode=nil)
    if mode == :test
      $mode = :test
      AWS::S3::Base.establish_connection!(:access_key_id => "123",
                                          :secret_access_key => "abc",
                                          :server => "localhost",
                                          :port => "10453" )
      @bucket_name = 'wendi-test'
      AWS::S3::Bucket.create(@bucket_name)
      AWS::S3::S3Object.store('one.txt', FILE_ONE, @bucket_name)
      AWS::S3::S3Object.store('files', '', @bucket_name)
      AWS::S3::S3Object.store('files/two.txt', FILE_TWO, @bucket_name)
    else
      begin
        config = YAML::load File.read( File.expand_path('../security/amazon_keys.yml', __FILE__) )
        access_key_id = config['access_key_id']
        secret_access_key = config['secret_access_key']
        AWS::S3::Base.establish_connection!(
          :access_key_id     => access_key_id,
          :secret_access_key => secret_access_key
        )
        @bucket_name = config['bucket_name']
      rescue => e
        p e
        # puts 'S3 Service Establish Error, retrying..'
        retry
      end
    end
  end

  def change_dir(path, &block)
    yield true and return if path == '/'

    path = s3_path_wrapper(path)

    res = true
    begin
      AWS::S3::Bucket.objects(@bucket_name, :prefix => path)
    rescue => e
      # AWS::S3::NoSuckKey exception
      p e
      res = false
    end

    yield res
  end

  def dir_contents(path, &block)
    path = s3_path_wrapper(path)
    res = []

    objects = AWS::S3::Bucket.objects(@bucket_name, :prefix => path)

    yield false and return if objects.count == 0

    names_set = []
    objects.each do |object|
      key = object.key
      key = key[path.length..-1]

      next if key.empty?
      if pos = (key =~ /\//)
        name = key[0..pos-1]
        if !(names_set.include? name)
          names_set << name
          res << EM::FTPD::Item.new(:name => name, :size => 0, :time => s3_object_time(object), :directory => true)
        end
      else
        # when test, exists this condition: 'files', 'files/one.txt'
        if !(names_set.include? key)
          names_set << key
          res << EM::FTPD::Item.new(:name => key, :size => s3_object_size(object), :time => s3_object_time(object), :directory => false)
        end
      end
    end

    yield res
  end

  def authenticate(user, pass, &block)
    auth = false
    File.open('security/passwd', 'r').each do |line|
      auth = true if "#{user}:#{pass}" == line.strip
    end
    yield auth
  end

  def bytes(path, &block)
    path = s3_path_wrapper(path, dir=false)

    objects = AWS::S3::Bucket.objects(@bucket_name, :prefix => path)
    if objects.count == 0
      yield false
    elsif objects.count == 1 && (objects.map(&:key).include? path)
      yield head_response(objects.first.about)
    else
      yield '0'
    end
  end

  def get_file(path, &block)
    path = s3_path_wrapper(path, dir=false)

    begin
      if !path.empty? && obj=AWS::S3::S3Object.find(path, @bucket_name)
        if obj.about['content-type'] != 'binary/octet-stream'
          yield obj.value and return
        end
      end
    rescue => e
      # NoSuchKey exception
      yield false
    end
  end

  def put_file(path, file_path, &block)
    path = s3_path_wrapper(path, dir=false)
    file = open(file_path)

    AWS::S3::S3Object.store(path, file.read, @bucket_name)

    yield File.size(file_path)
  end

  def put_file_streamed(path, file_path, &block)
    path = s3_path_wrapper(path, dir=false)

    AWS::S3::S3Object.store(path, open(file_path), @bucket_name)

    yield File.size(file_path)
  end

  def delete_file(path, &block)
    path = s3_path_wrapper(path, dir=false)

    begin
      AWS::S3::S3Object.find(path, @bucket_name)
      AWS::S3::S3Object.delete(path, @bucket_name)
      yield true
    rescue => e
      yield false
    end
  end

  def delete_dir(path, &block)
    path = s3_path_wrapper(path)

    objects = AWS::S3::Bucket.objects(@bucket_name, :prefix => path)

    begin
      objects.each { |obj| AWS::S3::S3Object.delete(obj.key, @bucket_name) }
      yield true
    rescue => e
      yield false
    end
  end

  def rename(from, to, &block)
    from = s3_path_wrapper(from)
    to = s3_path_wrapper(to)

    begin
      AWS::S3::S3Object.find(from, @bucket_name)
      AWS::S3::S3Object.rename(from, to, @bucket_name)
      yield true
    rescue => e
      yield false
    end

  end

  def make_dir(path, &block)
    path = s3_path_wrapper(path)

    objects = AWS::S3::Bucket.objects(@bucket_name, :prefix => path)
    yield false and return if objects.count > 0

    begin
      AWS::S3::S3Object.store(
        path,
        '',
        @bucket_name,
        :content_type => 'binary/octet-stream'
      )
      yield true
    rescue => e
      yield false
    end
  end

  private

  def s3_object_size(object)
    object.value.size
  end

  def s3_object_time(object)
    object.about['last-modified']
  end

  def head_response(about)
    str = %Q( HTTP/1.1 OK
      Date: #{Time.now.strftime("%a, %d %b %y %H:%M:%S GMT")}
      Server: #{about['server']}
      Last-Modified: #{about['last-modified']}
      Accept-Ranges: #{about['accept-ranges']}
      Content-Length: #{about['content-length']}
      Content-Type: #{about['content-type']}
      213 END
    )
  end

  #
  # Dir
  # '/' => ''
  # '/empty' => 'empty/'
  #
  # File
  # '/empty/hello.txt' => 'empty/hello.txt'
  #
  def s3_path_wrapper(path, dir=true)
    path = path[1..-1]
    path += '/' if dir && !path.empty? && !( path =~ /\/$/ )
    # different in fake-s3
    if $mode == :test
      while path =~ /\/$/
        path = path[0..-2]
      end
    end
    path.to_s
  end

end
