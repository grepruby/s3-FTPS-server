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

  AWS::S3::DEFAULT_HOST = 's3-ap-northeast-1.amazonaws.com'

  #
  # OPTIMIZE
  #
  def establish_s3_connection
    begin
      config = YAML::load File.read( File.expand_path('../security/amazon_keys.yml', __FILE__) )
      access_key_id = config['access_key_id']
      secret_access_key = config['secret_access_key']
      AWS::S3::Base.establish_connection!(
        :access_key_id     => access_key_id,
        :secret_access_key => secret_access_key
      )
      bucket_name = config['bucket_name']
      @bucket = AWS::S3::Bucket.find(bucket_name)
    rescue => e
      p e
      # puts 'S3 Service Establish Error, retrying..'
      retry
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
      AWS::S3::S3Object.find(path, @bucket.name)
    rescue => e
      # AWS::S3::NoSuckKey exception
      p e
      res = false
    end

    yield res
  end

  def dir_contents(path, &block)
    path = s3_path_wrapper(path)

    objects = AWS::S3::Bucket.objects(@bucket.name, :prefix => path)

    case objects.count
    when 0
      yield false
    when 1
      object = objects.first
      if object.about['content-type'] == 'binary/octet-stream'
        yield []
      else
        name = object.key.split('/').last
        yield [ Item.new(:name => name, :directory => false) ]
      end
    else
      res = []
      objects.shift if path != ''
      objects.each do |object|
        key = object.key

        data = key[path.length..-1].split('/')

        next if data.count > 1

        if key =~ /\/$/
          res << Item.new(:name => data.last, :size => s3_object_size(key), :time => s3_object_time(object), :directory => true)
        else
          res << Item.new(:name => data.last, :size => s3_object_size(key), :time => s3_object_time(object), :directory => false)
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
      obj = AWS::S3::S3Object.find(path, @bucket.name)
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

    if !path.empty? && obj=AWS::S3::S3Object.find(path, @bucket.name)
      if obj.about['content-type'] != 'binary/octet-stream'
        yeild obj.value
      end
    end

    yield false
  end

  def put_file(path, file_path, &block)
    path = s3_path_wrapper(path)
    file = open(file_path)

    AWS::S3::S3Object.store(path, file.read, @bucket.name)

    yield File.size(file_path)
  end

  def puts_file_streamed(path, file_path, &block)
    path = s3_path_wrapper(path)

    AWS::S3::S3Object.store(path, open(file_path), @bucket.name)

    yield File.size(file_path)
  end

  def delete_file(path, &block)
    path = s3_path_wrapper(path)

    begin
      AWS::S3::S3Object.delete(path, @bucket.name)
      yield true
    rescue => e
      yield false
    end
  end

  def delete_dir(path, &block)
    path = s3_path_wrapper(path)

    objects = AWS::S3::Bucket.objects(@bucket.name, :prefix => path)

    begin
      objects.each { |obj| AWS::S3::S3Object.delete(obj.key, @bucket.name) }
      yield true
    rescue => e
      yield false
    end
  end

  def rename(from, to, &block)
  end

  def make_dir(path, &block)
    yield false
  end

  private

  def s3_object_size(path)
    objects = AWS::S3::Bucket.objects(@bucket.name, :prefix => path)
    objects.reduce(0) { |sum, obj| sum += obj.size.to_i }
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
    path.to_s
  end

end

# configure the server
driver     FTPSDriver
# port       10001
#driver_args 1, 2, 3
#user      "ftp"
#group     "ftp"
#daemonise false
#name      "fakeftp"
#pid_file  "/var/run/fakeftp.pid"
