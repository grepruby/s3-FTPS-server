require 'spec_helper'
require 'pry-debugger'

describe 's3-FTPS-server' do

  before(:all) do
    @c = EM::FTPD::Server.new(nil, FTPSDriver.new(mode=:test))
  end

  context 'initialization' do
    it "should default to a root name_prefix" do
      @c.name_prefix.should eql("/")
    end

    it "should respond with 220 when connection is opened" do
      @c.sent_data.should match(/^220/)
    end
  end

  context 'AUTH' do
    it "" do
    end
  end

  context 'USER' do
  end

  context 'PASS' do
  end

  context 'PBSZ' do
  end

  context 'PROT' do
  end

  context 'PWD' do
  end

  context 'TYPE' do
  end

  context 'PASV' do
  end

  context 'LIST' do
  end

  context 'CWD' do
  end

end
