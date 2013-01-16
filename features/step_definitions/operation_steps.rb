Given /^Client has connected to server$/ do
  steps %Q{
    Given Server has accept PROT
  }
  @c.reset_sent!
end

When /^Client send cmd 'PWD'$/ do
  @c.receive_line('PWD')
end

Then /^Server should respond with (\d+) "(.*?)" when called from root dir$/ do |arg1, arg2|
  @c.sent_data.strip.should eql('257 "/" is the current directory')
end

# - - -

When /^Client send cmd 'CWD files'$/ do
  @c.receive_line('CWD files')
end

Then /^Server should respond with (\d+) if called with files from users home$/ do |arg1|
  @c.sent_data.should match(/250.+/)
  @c.name_prefix.should eql("/files")
end

# - - -

Given /^Client has connected to server and entered Passive Mode$/ do
  steps %Q{
    Given Client has connected to server
  }
  @c.receive_line("PASV")
  @c.reset_sent!
end

When /^Client send cmd 'LIST'$/ do
  @c.receive_line("LIST")
end

Then /^Server should respond with (\d+) when called in the root dir with no param$/ do |arg1|
  timestr = Time.now.strftime("%b %d %H:%M")
  root_files =
    [
      "-rwxrwxrwx 1 wendi workgroup           40 #{timestr} files",
      "-rwxrwxrwx 1 wendi workgroup           56 #{timestr} one.txt"
    ]
  @c.sent_data.should match(/150.+/m)
  @c.oobdata.split(EM::FTPD::Server::LBRK).should eql(root_files)
end

# - - -

When /^Client send cmd 'MKD four'$/ do
  @c.receive_line("MKD")
end

Then /^Server should respond with (\d+) when the directory is created$/ do |arg1|
  @c.sent_data.should match(/553.+/)
end

# - - -

When /^Client send cmd 'SIZE one\.txt'$/ do
  @c.receive_line("SIZE one.txt")
end

Then /^Server should always respond with (\d+) when called with a valid file param$/ do |arg1|
  @c.sent_data.should match(/^213(.|\n)+Content-Length: 56/)
end

# - - -

When /^Client send cmd 'RETR one\.txt'$/ do
  @c.receive_line("RETR one.txt")
end

Then /^Server should always respond with (\d+)\.\.(\d+) when called with valid file$/ do |arg1, arg2|
  @c.sent_data.should match(/150.+226.+/m)
end

# - - -

When /^Client send cmd 'STOR one\.txt'$/ do
  @c.receive_line("STOR one.txt")
end

Then /^Server should always respond with (\d+) when called with valid file$/ do |arg1|
  @c.sent_data.should match(/150.+/m)
end

# - - -

When /^Client send cmd 'DELE one\.txt'$/ do
  @c.receive_line("DELE one.txt")
end

Then /^Server should always respond with (\d+) when the file is deleted$/ do |arg1|
  @c.sent_data.should match(/250.+/m)
end

# - - -

When /^Client send cmd 'RNFR one\.txt' and 'RNTO two\.txt'$/ do
  @c.receive_line("RNFR one.txt")
  @c.receive_line("RNTO two.txt")
  @c.receive_line("DELE two.txt")
end

Then /^Server should always respond with (\d+) when the file is renamed$/ do |arg1|
  @c.sent_data.should match(/250.+/m)
end


