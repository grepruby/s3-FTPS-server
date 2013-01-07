module EM::FTPD

  class Server < EM::Connection

    def post_init
      @mode   = :binary
      @name_prefix = "/"

      start_tls(:private_key_file => 'ssl/myssl.key', :cert_chain_file => 'ssl/myssl.crt', :verify_peer => false)

      send_response "220 FTP server (em-ftpd) ready"
    end

    # Accept 'TLF' as param.
    #
    # * If the server does not recognize the AUTH command, it must respond
    #   with reply code 500.
    # * If the server does not understand the named security mechanism, it
    #   should respond with reply code 504.
    #
    # * If accepted, removes any state associated with prior FTP Security
    #   commands.
    #
    def cmd_auth
    end

    def cmd_feat
      str = "211- Supported features:#{LBRK}"
      features = %w{ AUTH PBSZ PROT }
      features.each do |feat|
        str << " #{feat}" << LBRK
      end
      str << "211 END" << LBRK

      send_response(str, true)
    end

    # Accept '0'
    # The PBSZ command must be preceded by a successful security data
    # exchange.
    #
    # * If the server cannot parse the argument, or if it will not fit in
    # 32 bits, it should respond with a 501 reply code.
    #
    # * If the server has not completed a security data exchange with the
    # client, it should respond with a 503 reply code.
    def cmd_pbsz(arg)
    end

    # Accept 'P'
    # The PROT command must be preceded by a successful protection
    # buffer size negotiation.
    #
    # * If no previous PBSZ command was issued,the PROT command will be
    #   rejected and the server should reply 503.
    #
    # * If the server does not understand the named security mechanism, it
    #   should respond with reply code 504.
    # * If the specified protection level is accepted, the server must
    #   reply with a 200 reply code to indicate.
    #
    def cmd_prot
    end

  end

end

