module EM::FTPD

  class Server < EM::Connection

    def post_init
      @mode   = :binary
      @name_prefix = "/"

      start_tls(:private_key_file => 'ssl/myssl.key', :cert_chain_file => 'ssl/myssl.crt', :verify_peer => false)

      send_response "220 FTP server (em-ftpd) ready"
    end

    def cmd_auth
    end

    def cmd_feat
    end

    def cmd_pbsz
    end

    def cmd_prot
    end

  end

end

