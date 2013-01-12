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

    res = true
    path = path[1..-1]
    path += '/' if !(path =~ /\/$/)

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
    case path
    when "/"      then
      yield [ dir_item("files"), file_item("one.txt", FILE_ONE.bytesize) ]
    when "/files" then
      yield [ file_item("two.txt", FILE_TWO.bytesize) ]
    else
      yield []
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
    resp =case path
          when "/one.txt"       then FILE_ONE.size
          when "/files/two.txt" then FILE_TWO.size
          else
            false
          end
    head_response(resp)
    yield resp
  end

  def head_response(arg)
    str = %Q(
      HTTP/1.1 200 OK
      Date: #{Time.now.strftime("%a, %d %b %y %H:%M:%S GMT")}
      Server: Unix Type: L8
      Last-Modified: #{}
      Accept-Ranges: bytes
      Content-Length: #{}
      Connection: close
      Content-Type: #{}
    )
  end


  def get_file(path, &block)
    yield case path
          when "/one.txt"       then FILE_ONE
          when "/files/two.txt" then FILE_TWO
          else
            false
          end
  end

  def put_file(path, data, &block)
    yield false
  end

  def put_file_streamed
  end

  def delete_file(path, &block)
    yield false
  end

  def delete_dir(path, &block)
    yield false
  end

  def rename(from, to, &block)
    yield false
  end

  def make_dir(path, &block)
    yield false
  end

  private

  def dir_item(name)
    EM::FTPD::DirectoryItem.new(:name => name, :directory => true, :size => 0)
  end

  def file_item(name, bytes)
    EM::FTPD::DirectoryItem.new(:name => name, :directory => false, :size => bytes)
  end

end

# configure the server
driver     FTPSDriver
port       10001
#driver_args 1, 2, 3
#user      "ftp"
#group     "ftp"
#daemonise false
#name      "fakeftp"
#pid_file  "/var/run/fakeftp.pid"
