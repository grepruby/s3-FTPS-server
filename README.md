### a FTPS server based on em-ftpd, with AWS S3 backend
- - -

* start with

  ```ruby
  $ em-ftpd config.rb
  ```

* test with

  ```ruby
  $ bundle install --binstubs

  # stub S3 requests with fake-s3
  $ rake test_server

  $ cucumber features
  $ rspec spec
  ```

* objects implemented

  - √ Properly implement put_file_streamed using EventMachine features
  - √ Secure authentication
  - × Secure file transfer using a passive FTP connection
