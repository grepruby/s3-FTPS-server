Given /^Server has started$/ do
  @c = EM::FTPD::Server.new(nil, FTPSDriver.new(mode=:test))
end

When /^Client send cmd 'AUTH TLS'$/ do
  @c.receive_line('AUTH tls')
end

Then /^Server should respond with 234 when server accept the security mechanism$/ do
  @c.sent_data.should match(/234.+/)
end

# - - -

Given /^Server has started a TLS command connection$/ do
  steps %Q{
    Given Server has started
  }
  @c.receive_line('AUTH tls')
end

When /^Client send cmd 'USER test' and 'PASS 1234'$/ do
  @c.receive_line('USER test')
  @c.receive_line('PASS 1234')
end

Then /^Server should respond with 230 when user is authenticated$/ do
  @c.sent_data.should match(/230.+/)
end

# - - -

Given /^Server has authenticated user$/ do
  steps %Q{
    Given Server has started a TLS command connection
  }
  @c.receive_line('USER test')
  @c.receive_line('PASS 1234')
end

When /^Client send cmd 'PBSZ (\d+)'$/ do |arg1|
  @c.receive_line('PBSZ 0')
end

Then /^Server should respond (\d+) Success when server accept the pbsz size$/ do |arg1|
  @c.sent_data.should match(/200.+/)
end

# - - -

Given /^Server has accept PBSZ$/ do
  steps %Q{
    Given Server has authenticated user
  }
  @c.receive_line('PBSZ 0')
end

When /^Client send cmd 'PROT P'$/ do
  @c.receive_line('PROT P')
end

Then /^Server should respond with (\d+) when accept 'P' but decline$/ do |arg1|
  @c.sent_data.should match(/504.+/)
end

# - - -

Given /^Server has accept PROT$/ do
  steps %Q{
    Given Server has accept PBSZ
  }
  @c.receive_line('PROT P')
end

When /^Client send cmd 'FEAT'$/ do
  @c.receive_line('FEAT')
end

Then /^Server should respond with (\d+) when accept FEAT$/ do |arg1|
  @c.sent_data.should match(/211.+/)
end
