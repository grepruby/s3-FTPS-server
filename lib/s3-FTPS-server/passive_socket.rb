module EM::FTPD

  class PassiveSocket

    def self.start(host, control_server)
      EventMachine.start_server(host, 0, self) do |conn|
        control_server.datasocket = conn
      end
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

