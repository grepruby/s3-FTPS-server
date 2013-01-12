module EM::FTPD
  module Directories

    # return a detailed list of files and directories
    def cmd_list(param)
      send_unauthorised and return unless logged_in?
      send_response "150 Opening ASCII mode data connection for file list"

      param = '' if param.to_s == '-a'

      @driver.dir_contents(build_path(param)) do |files|
        if !Array === files
          send_response "No such directory or file." and return
        elsif files.count == 0
          return
        end

        now = Time.now
        lines = files.map { |item|
          sizestr = (item.size || 0).to_s.rjust(12)
          "#{item.directory ? 'd' : '-'}#{item.permissions || 'rwxrwxrwx'} 1 #{item.owner || 'owner'}  #{item.group || 'group'} #{sizestr} #{item.time || Time.now.strftime("%b %d %H:%M")} #{item.name}"
        }
        send_outofband_data(lines)

        lines.each { |line| send_response line }
      end
    end

    # change directory
    def cmd_cwd(param)
      send_unauthorised and return unless logged_in?
      path = build_path(param)

      @driver.change_dir(path) do |result|
        if result
          @name_prefix = path
          send_response "250 Directory changed to #{path}"
        else
          send_permission_denied
        end
      end
    end

  end
end

