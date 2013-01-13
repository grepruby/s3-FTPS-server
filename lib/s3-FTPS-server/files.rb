module EM::FTPD
  module Files

    def cmd_stor_streamed(target_path)
      wait_for_datasocket do |datasocket|
        if datasocket
          send_response "150 Data transfer starting"
          @driver.put_file_streamed(target_path, datasocket) do |bytes|
            @driver.clear_temp_file
            if bytes
              send_response "226 OK, received #{bytes} bytes"
            else
              send_action_not_taken
            end
          end
        else
          send_response "425 Error establishing connection"
        end
      end
    end

    def cmd_stor_tempfile(target_path)
      tmpfile = Tempfile.new("em-ftp")
      tmpfile.binmode

      wait_for_datasocket do |datasocket|
        datasocket.on_stream { |chunk|
          tmpfile.write chunk
        }
        send_response "150 Data transfer starting"
        datasocket.callback {
          puts "data transfer finished"
          tmpfile.flush
          @driver.put_file(target_path, tmpfile.path) do |bytes|
            if bytes
              send_response "226 OK, received #{bytes} bytes"
            else
              send_action_not_taken
            end
          end
          tmpfile.unlink
        }
        datasocket.errback {
          tmpfile.unlink
        }
      end
    end

  end
end

