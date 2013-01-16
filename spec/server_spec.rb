require 'spec_helper'

describe 's3-FTPS-server' do

  context 'Initialization' do

    before(:each) do
      @c = EM::FTPD::Server.new(nil, FTPSDriver.new(mode=:test))
    end

    it "should default to a root name_prefix" do
      @c.name_prefix.should eql("/")
    end

    it "should respond with 220 when connection is opened" do
      @c.sent_data.should match(/^220/)
    end

  end

  context 'Establish TLS Command Connection' do

    describe 'AUTH' do

      before(:each) do
        @c = EM::FTPD::Server.new(nil, FTPSDriver.new(mode=:test))
      end

      it 'should respond with 234 when server accept the security mechanism' do
        @c.reset_sent!
        @c.receive_line('AUTH tls')
        @c.sent_data.should match(/234.+/)
      end

      it 'should respond with 504 when server donot understand the security mechanism' do
        @c.reset_sent!
        @c.receive_line('AUTH helloworld')
        @c.sent_data.should match(/504.+/)
      end
    end

    describe 'USER' do

      before(:each) do
        @c = EM::FTPD::Server.new(nil, FTPSDriver.new(mode=:test))
      end

      it "should respond with 331 when called by non-logged in user" do
        @c.reset_sent!
        @c.receive_line("USER test")
        @c.sent_data.should match(/331.+/)
      end

      it "should respond with 500 when called by a logged in user" do
        @c.receive_line("USER test")
        @c.receive_line("PASS 1234")
        @c.reset_sent!
        @c.receive_line("USER test")
        @c.sent_data.should match(/500.+/)
      end
    end

    describe 'PASS' do

      before(:each) do
        @c = EM::FTPD::Server.new(nil, FTPSDriver.new(mode=:test))
      end

      it "should respond with 202 when called by logged in user" do
        @c.receive_line("USER test")
        @c.receive_line("PASS 1234")
        @c.reset_sent!
        @c.receive_line("PASS 1234")
        @c.sent_data.should match(/202.+/)
      end

      it "should respond with 553 when called with no param" do
        @c.receive_line("USER test")
        @c.reset_sent!
        @c.receive_line("PASS")
        @c.sent_data.should match(/553.+/)
      end

      it "should respond with 530 when called without first providing a username" do
        @c.reset_sent!
        @c.receive_line("PASS 1234")
        @c.sent_data.should match(/530.+/)
      end

      it "should respond with 230 when user is authenticated" do
        @c.receive_line("USER test")
        @c.reset_sent!
        @c.receive_line("PASS 1234")
        @c.sent_data.should match(/230.+/)
      end

      it "should respond with 530 when password is incorrect" do
        @c.receive_line("USER test")
        @c.reset_sent!
        @c.receive_line("PASS 1235")
        @c.sent_data.should match(/530.+/)
      end
    end

    describe 'PBSZ' do

      before(:each) do
        @c = EM::FTPD::Server.new(nil, FTPSDriver.new(mode=:test))
        @c.receive_line('USER test')
        @c.receive_line('PASS 1234')
        @c.reset_sent!
      end

      it 'should respond with 503 when need AUTH preceded' do
        @c.receive_line('PBSZ 0')
        @c.sent_data.should match(/503.+/)
      end

      it "should respond with '200 Success' when server accept the pbsz size" do
        @c.receive_line('AUTH tls')
        @c.reset_sent!
        @c.receive_line('PBSZ 0')
        @c.sent_data.should match(/200 Success.+/)
      end

      it "should respond with '200 Failed' when server accept non-zero pbsz size" do
        @c.receive_line('AUTH tls')
        @c.reset_sent!
        @c.receive_line("PBSZ #{2**32-1}")
        @c.sent_data.should match(/200 Failed.+/)
      end

      it 'should respond with 501 when server cannot parse the argument' do
        @c.receive_line('AUTH tls')
        @c.reset_sent!
        @c.receive_line('PBSZ #{2**32}')
        @c.sent_data.should match(/501.+/)
      end

      it 'should respond with 501 when server cannot parse the argument' do
        @c.receive_line('AUTH tls')
        @c.reset_sent!
        @c.receive_line('PBSZ hellworld')
        @c.sent_data.should match(/501.+/)
      end
    end

    describe 'PROT' do

      before(:each) do
        @c = EM::FTPD::Server.new(nil, FTPSDriver.new(mode=:test))
        @c.receive_line('AUTH tls')
        @c.receive_line('USER test')
        @c.receive_line('PASS 1234')
        @c.reset_sent!
      end

      it 'should respond with 503 when need PBSZ preceded' do
        @c.receive_line('PROT P')
        @c.sent_data.should match(/503.+/)
      end

      it "should respond with 504 when accept 'P' but decline" do
        @c.receive_line('PBSZ 0')
        @c.reset_sent!
        @c.receive_line('PROT P')
        @c.sent_data.should match(/504.+/)
      end

      it 'should respond with 536 when not support specified proteccted level' do
        @c.receive_line('PBSZ 0')
        @c.reset_sent!
        @c.receive_line('PROT C')
        @c.sent_data.should match(/536.+/)
      end

      it 'should respond with 504 when non understand specified proteccted level' do
        @c.receive_line('PBSZ 0')
        @c.reset_sent!
        @c.receive_line('PROT helloworld')
        @c.sent_data.should match(/504.+/)
      end
    end

    describe 'FEAT' do

      before(:each) do
        @c = EM::FTPD::Server.new(nil, FTPSDriver.new(mode=:test))
        @c.receive_line('AUTH tls')
        @c.receive_line('USER test')
        @c.receive_line('PASS 1234')
        @c.reset_sent!
      end

      it 'should respond with 211 when accept FEAT' do
        @c.receive_line('FEAT')
        @c.sent_data.should match(/211.+/)
      end
    end

  end


  context 'Basic Directory Command' do

    describe 'CWD' do

      before(:each) do
        @c = EM::FTPD::Server.new(nil, FTPSDriver.new(mode=:test))
        @c.receive_line('AUTH tls')
        @c.receive_line("USER test")
        @c.receive_line("PASS 1234")
        @c.receive_line("PBSZ 0")
        @c.receive_line("PROT P")
        @c.reset_sent!
      end

      it "should respond with 250 if called with '/' from users home" do
        @c.receive_line("CWD /")
        @c.sent_data.should match(/250.+/)
        @c.name_prefix.should eql("/")
      end

      it "should respond with 250 if called with 'files' from users home" do
        @c.receive_line("CWD files")
        @c.sent_data.should match(/250.+/)
        @c.name_prefix.should eql("/files")
      end

      it "should respond with 250 if called with 'files/' from users home" do
        @c.receive_line("CWD files/")
        @c.sent_data.should match(/250.+/)
        @c.name_prefix.should eql("/files")
      end

      it "should respond with 250 if called with '/files/' from users home" do
        @c.receive_line("CWD /files/")
        @c.sent_data.should match(/250.+/)
        @c.name_prefix.should eql("/files")
      end
    end

    describe 'PWD' do

      before(:each) do
        @c = EM::FTPD::Server.new(nil, FTPSDriver.new(mode=:test))
        @c.receive_line('AUTH tls')
        @c.receive_line("USER test")
        @c.receive_line("PASS 1234")
        @c.receive_line("PBSZ 0")
        @c.receive_line("PROT P")
        @c.reset_sent!
      end

      it 'should always respond with 257 "/" when called from root dir' do
        @c.receive_line('PWD')
        @c.sent_data.strip.should eql('257 "/" is the current directory')
      end

      it 'should always respond with 257 "/files" when called from files dir' do
        @c.receive_line("CWD files")
        @c.reset_sent!
        @c.receive_line('PWD')
        @c.sent_data.strip.should eql('257 "/files" is the current directory')
      end

    end

    describe 'LIST' do
      before(:each) do
        @c = EM::FTPD::Server.new(nil, FTPSDriver.new(mode=:test))
        @c.receive_line('AUTH tls')
        @c.receive_line("USER test")
        @c.receive_line("PASS 1234")
        @c.receive_line("PBSZ 0")
        @c.receive_line("PROT P")
        @c.reset_sent!
      end

      let!(:root_files) {
        timestr = Time.now.strftime("%b %d %H:%M")
        [
          "-rwxrwxrwx 1 wendi workgroup           40 #{timestr} files",
          "-rwxrwxrwx 1 wendi workgroup           56 #{timestr} one.txt"
        ]
      }
      let!(:dir_files) {
        timestr = Time.now.strftime("%b %d %H:%M")
        [
          "-rwxrwxrwx 1 wendi workgroup           40 #{timestr} two.txt"
        ]
      }

      # it "should respond with 150 ...425  when called with no data socket" do
      #   @c.receive_line("LIST")
      #   @c.sent_data.should match(/150.+425.+/m)
      # end

      it "should respond with 150 when called in the root dir with no param" do
        @c.receive_line("PASV")
        @c.reset_sent!
        @c.receive_line("LIST")
        @c.sent_data.should match(/150.+/m)
        @c.oobdata.split(EM::FTPD::Server::LBRK).should eql(root_files)
      end

      it "should respond with 150 when called in the files dir with no param" do
        @c.receive_line("CWD files")
        @c.receive_line("PASV")
        @c.reset_sent!
        @c.receive_line("LIST")
        @c.sent_data.should match(/150.+/m)
        @c.oobdata.split(EM::FTPD::Server::LBRK).should eql(dir_files)
      end

      it "should respond with 150 when called in the subdir with / param" do
        @c.receive_line("CWD files")
        @c.receive_line("PASV")
        @c.reset_sent!
        @c.receive_line("LIST /")
        @c.sent_data.should match(/150.+/m)
        @c.oobdata.split(EM::FTPD::Server::LBRK).should eql(root_files)
      end

      it "should respond with 150 when called in the root with files param" do
        @c.receive_line("PASV")
        @c.reset_sent!
        @c.receive_line("LIST files")
        @c.sent_data.should match(/150.+/m)
        @c.oobdata.split(EM::FTPD::Server::LBRK).should eql(dir_files)
      end

      it "should respond with 150 when called in the root with files/ param" do
        @c.receive_line("PASV")
        @c.reset_sent!
        @c.receive_line("LIST files/")
        @c.sent_data.should match(/150.+/m)
        @c.oobdata.split(EM::FTPD::Server::LBRK).should eql(dir_files)
      end
    end

    describe 'MKD' do

      before(:each) do
        @c = EM::FTPD::Server.new(nil, FTPSDriver.new(mode=:test))
        @c.receive_line('AUTH tls')
        @c.receive_line("USER test")
        @c.receive_line("PASS 1234")
        @c.receive_line("PBSZ 0")
        @c.receive_line("PROT P")
        @c.reset_sent!
      end

      it "should respond with 553 when the paramater is omitted" do
        @c.receive_line("MKD")
        @c.sent_data.should match(/553.+/)
      end

      it "should respond with 257 when the directory is created" do
        @c.receive_line("DELE four")
        @c.receive_line("MKD four")
        @c.sent_data.should match(/257.+/)
        @c.receive_line("DELE four")
      end

      it "should respond with 550 when the directory is not created" do
        @c.receive_line("MKD five")
        @c.reset_sent!
        @c.receive_line("MKD five")
        @c.sent_data.should match(/550.+/)
        @c.receive_line("DELE five")
      end
    end

  end

  context 'Basic File Operaion' do

    describe 'SIZE' do
      before(:each) do
        @c = EM::FTPD::Server.new(nil, FTPSDriver.new(mode=:test))
        @c.receive_line('AUTH tls')
        @c.receive_line("USER test")
        @c.receive_line("PASS 1234")
        @c.receive_line("PBSZ 0")
        @c.receive_line("PROT P")
        @c.reset_sent!
      end

      it "should always respond with 553 when called with no param" do
        @c.receive_line("SIZE")
        @c.sent_data.should match(/553.+/)
      end

      it "should always respond with 450 when called with a non-file param" do
        @c.receive_line("SIZE blah")
        @c.sent_data.should match(/450.+/)
      end

      it "should always respond with 213 when called with a directory param" do
        @c.receive_line("SIZE files")
        @c.sent_data.should match(/213.+/)
      end

      it "should always respond with 213 when called with a valid file param" do
        @c.receive_line("SIZE one.txt")
        @c.sent_data.should match(/^213(.|\n)+Content-Length: 56/)
      end

      it "should always respond with 213 when called with a valid file param" do
        @c.receive_line("SIZE files/two.txt")
        @c.sent_data.should match(/^213(.|\n)+Content-Length: 40/)
      end
    end

    describe 'RETR' do
      before(:each) do
        @c = EM::FTPD::Server.new(nil, FTPSDriver.new(mode=:test))
        @c.receive_line('AUTH tls')
        @c.receive_line("USER test")
        @c.receive_line("PASS 1234")
        @c.receive_line("PBSZ 0")
        @c.receive_line("PROT P")
        @c.reset_sent!
      end

      it "should respond with 553 when called with no param" do
        @c.receive_line("PASV")
        @c.reset_sent!
        @c.receive_line("RETR")
        @c.sent_data.should match(/553.+/)
      end

      it "should always respond with 551 when called with an invalid file" do
        @c.receive_line("PASV")
        @c.reset_sent!
        @c.receive_line("RETR blah.txt")
        @c.sent_data.should match(/551.+/)
      end

      it "should always respond with 150..226 when called with valid file" do
        @c.receive_line("PASV")
        @c.reset_sent!
        @c.receive_line("RETR one.txt")
        @c.sent_data.should match(/150.+226.+/m)
      end

      it "should always respond with 150..226 when called outside files dir with appropriate param" do
        @c.receive_line("PASV")
        @c.reset_sent!
        @c.receive_line("RETR files/two.txt")
        @c.sent_data.should match(/150.+226.+/m)
      end
    end

    describe 'STOR' do
      before(:each) do
        @c = EM::FTPD::Server.new(nil, FTPSDriver.new(mode=:test))
        @c.receive_line('AUTH tls')
        @c.receive_line("USER test")
        @c.receive_line("PASS 1234")
        @c.receive_line("PBSZ 0")
        @c.receive_line("PROT P")
        @c.reset_sent!
      end

      it "should respond with 553 when called with no param" do
        @c.receive_line("PASV")
        @c.reset_sent!
        @c.receive_line("STOR")
        @c.sent_data.should match(/553.+/)
      end

      it "should always respond with 150 when called with valid file" do
        @c.receive_line("PASV")
        @c.reset_sent!
        @c.receive_line("STOR one.txt")
        @c.sent_data.should match(/150.+/m)
      end

      it "should always respond with 150 when called outside files dir with appropriate param" do
        @c.receive_line("PASV")
        @c.reset_sent!
        @c.receive_line("STOR files/two.txt")
        @c.sent_data.should match(/150.+/m)
      end
    end

    describe 'DELE' do
      before(:each) do
        @c = EM::FTPD::Server.new(nil, FTPSDriver.new(mode=:test))
        @c.receive_line('AUTH tls')
        @c.receive_line("USER test")
        @c.receive_line("PASS 1234")
        @c.receive_line("PBSZ 0")
        @c.receive_line("PROT P")
        @c.reset_sent!
      end

      it "should respond with 553 when called with no param" do
        @c.receive_line("DELE")
        @c.sent_data.should match(/553.+/)
      end

      it "should always respond with 550 when the file is not deleted" do
        @c.receive_line("DELE blah.txt")
        @c.sent_data.should match(/550.+/)
      end

      it "should always respond with 250 when the file is deleted" do
        @c.receive_line("DELE one.txt")
        @c.sent_data.should match(/250.+/m)
      end

      it "should always respond with 250 when the file is deleted" do
        @c.receive_line("DELE files/two.txt")
        @c.sent_data.should match(/250.+/m)
      end
    end

    describe 'RNTO' do
      before(:each) do
        @c = EM::FTPD::Server.new(nil, FTPSDriver.new(mode=:test))
        @c.receive_line('AUTH tls')
        @c.receive_line("USER test")
        @c.receive_line("PASS 1234")
        @c.receive_line("PBSZ 0")
        @c.receive_line("PROT P")
        @c.reset_sent!
      end

      it "should respond with 553 when the paramater is omitted" do
        @c.receive_line("RNFR")
        @c.sent_data.should match(/553.+/)
      end

      it "should always respond with 350 when called" do
        @c.receive_line("RNFR x")
        @c.sent_data.should match(/350.+/)
      end

      it "should respond with 250 when the file is renamed" do
        @c.receive_line("RNFR one.txt")
        @c.receive_line("RNTO two.txt")
        @c.sent_data.should match(/250.+/)
        @c.receive_line("DELE two.txt")
      end

      it "should respond with 550 when the file is not renamed" do
        @c.receive_line("RNFR two.txt")
        @c.receive_line("RNTO one.txt")
        @c.sent_data.should match(/550.+/)
      end
    end

  end

end
