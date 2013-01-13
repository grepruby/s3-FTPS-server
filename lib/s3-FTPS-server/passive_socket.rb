module EM::FTPD

  class PassiveSocket

    class << self
      attr_accessor :temp_file
    end

    def self.start(host, control_server)
      @temp_file = control_server.driver.get_temp_file
      EventMachine.start_server(host, 0, self) do |conn|
        control_server.datasocket = conn
      end
    end

    def receive_data(chunk)
      if @on_stream
        @on_stream.call(chunk)
      else
        self.class.temp_file.write chunk
        # data << chunk
      end
    end

    def on_stream &blk
      @on_stream = blk if block_given?
      unless (file=self.class.temp_file.read).empty?
        @on_stream.call(file) # send all data that was collected before the stream hanlder was set
        @data = ""
      end
      @on_stream
    end

    #
    # cannot start data connection by start_tls
    #
    # def post_init
    #   @mode   = :binary
    #   @name_prefix = "/"

    #   send_response "220 FTP server (em-ftpd) ready"
    #   start_tls(:private_key_file => 'ssl/myssl.key', :cert_chain_file => 'ssl/myssl.crt', :verify_peer => false)
    # end

  end
end

