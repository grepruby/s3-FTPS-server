module EM::FTPD
  module Files

    def cmd_stor_streamed(target_path)
      tmpfile = Tempfile.new("em-ftp")
      tmpfile.binmode

      wait_for_datasocket do |datasocket|
        datasocket.on_stream { |chunk|
          if !datasocket.data.empty?
            tmpfile.write datasocket.data
            datasocket.data.clear
          end
          tmpfile.write chunk
        }
        send_response "150 Data transfer starting"
        datasocket.callback {
          puts "data transfer finished"
          tmpfile.flush
          @driver.put_file_streamed(target_path, tmpfile.path) do |bytes|
            if bytes
              send_response "226 OK, received #{bytes} bytes"
            else
              send_action_not_taken
            end
          end
          tmp.unlink
        }
        datasocket.errback {
          tmpfile.unlink
        }
      end
    end

  end
end

