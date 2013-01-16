# coding: utf-8

# a super simple FTP server with hard coded auth details and only two files
# available for download.
#
# Usage:
#
#   em-ftpd examples/fake.rb

$:.unshift(File.expand_path('../lib/', __FILE__))
require 's3-FTPS-server'

class FTPSDriver
  FILE_ONE = "This is the first file available for download.\n\nBy James"
  FILE_TWO = "This is the file number two.\n\n2009-03-21"

  AWS::S3::DEFAULT_HOST = 's3-ap-northeast-1.amazonaws.com'

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
      AWS::S3::S3Object.store("files", '', @bucket_name, :content_type => 'binary/octet-stream')
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

  # def get_amazon_config
  #   YAML::load File.read( File.expand_path('../security/amazon_keys.yml', __FILE__) )
  # end

  def change_dir(path, &block)
    yield true and return if path == '/'

    path = s3_path_wrapper(path)

    res = true
    begin
      AWS::S3::S3Object.find(path, @bucket_name)
    rescue => e
      # AWS::S3::NoSuckKey exception
      p e
      res = false
    end

    yield res
  end

  def dir_contents(path, &block)
    path = s3_path_wrapper(path)

    objects = AWS::S3::Bucket.objects(@bucket_name, :prefix => path)

    case objects.count
    when 0
      yield false
    when 1
      object = objects.first
      if object.about['content-type'] == 'binary/octet-stream'
        yield []
      else
        name = object.key.split('/').last
        yield [ EM::FTPD::Item.new(:name => name, :directory => false) ]
      end
    else
      res = []
      objects.shift if path != ''
      objects.each do |object|
        key = object.key

        data = key[path.length..-1].split('/')

        data.shift if data.first == ''
        next if data.count > 1

        if key =~ /\/$/
          res << EM::FTPD::Item.new(:name => data.last, :size => s3_object_size(key), :time => s3_object_time(object), :directory => true)
        else
          res << EM::FTPD::Item.new(:name => data.last, :size => s3_object_size(key), :time => s3_object_time(object), :directory => false)
        end
      end
      yield res
    end
  end

  def authenticate(user, pass, &block)
    # yield user == "test" && pass == "1234"
    auth = false
    File.open('security/passwd', 'r').each do |line|
      auth = true if "#{user}:#{pass}" == line.strip
    end
    yield auth
  end

  def bytes(path, &block)
    path = s3_path_wrapper(path)
    begin
      obj = AWS::S3::S3Object.find(path, @bucket_name)
      res = obj.about
      if res['content-type'] == 'binary/octet-stream'
        yield '0'
      else
        yield head_response(res)
      end
    rescue => e
      # NoSuchKey exception
      yield false
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
    path = s3_path_wrapper(path)
    file = open(file_path)

    AWS::S3::S3Object.store(path, file.read, @bucket_name)

    yield File.size(file_path)
  end

  def put_file_streamed(path, file_path, &block)
    path = s3_path_wrapper(path)

    AWS::S3::S3Object.store(path, open(file_path), @bucket_name)

    yield File.size(file_path)
  end

  def delete_file(path, &block)
    path = s3_path_wrapper(path)

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

    begin
      AWS::S3::S3Object.find(path, @bucket_name)
      yield false and return
    rescue => e
    end

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

  def s3_object_size(path)
    objects = AWS::S3::Bucket.objects(@bucket_name, :prefix => path)
    # objects.reduce(0) { |sum, obj| sum += obj.size.to_i }
    objects.reduce(0) { |sum, obj| sum += obj.value.size }
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
      Content-Type: #{about['content-type']} )
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
