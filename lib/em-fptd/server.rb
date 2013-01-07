module EM::FTPD

  class Server < EM::Connection

    def post_init
      @tls_state = :none
      @pbsz = -1
      @mode   = :binary
      @name_prefix = "/"

      start_tls(:private_key_file => 'ssl/myssl.key', :cert_chain_file => 'ssl/myssl.crt', :verify_peer => false)

      send_response "220 FTP server (em-ftpd) ready"
    end

    # Accept 'TLF' as param.
    #
    # * If the server is willing to accept the named security mechanism,
    #   and does not require any security data, it must respond with reply
    #   code 234.
    # * If the server does not understand the named security mechanism, it
    #   should respond with reply code 504.
    #
    # * If accepted, removes any state associated with prior FTP Security
    #   commands.
    #
    def cmd_auth(arg)
       if arg =~ /^tls$/i
         @tls_state = :authed
         str = "234- Accept security mechanism: TLS"
       else
         str = "504- Do not understand security mechanism: '#{arg}' "
       end
       send_response(str)
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
    #
    # OPTIONAL
    #   If the size provided by the client is too large for the server, it must
    #   use a string of the form "PBSZ=number" in the text part of the
    #   reply to indicate a smaller buffer size.  The client and the
    #   server must use the smaller of the two buffer sizes if both buffer
    #   sizes are specified.
    MAX_PBSZ = 2**32 - 1
    def cmd_pbsz(arg)
      # test if arg is a Fixnum of String
      puts arg

      if @tls_state != :authed
        str = '503- Need AUTH preceded'
      else
        pbsz = arg.to_i
        if pbsz >= 0 && pbsz <= MAX_PBSZ
          @tls_state = :pbszed
          str = '200- Success negotiated a maximun protected buffer size'
          @pbsz = pbsz
        else
          str = '501- Cannot parse the argument (should between 0 and 2^32-1)'
        end
      end
      send_response(str)
    end

    # Accept 'P'
    # The PROT command must be preceded by a successful protection
    # buffer size negotiation.
    #
    # * If no previous PBSZ command was issued,the PROT command will be
    #   rejected and the server should reply 503.
    #
    # * If the server does not understand the specified protection level, it
    #   should respond with reply code 504.
    # * If the specified protection level is accepted, the server must
    #   reply with a 200 reply code to indicate.
    #
    def cmd_prot(arg)
      if @tls_state != :pbszed
        str = '503- Need PBSZ preceded'
      else
        if arg =~ /^p$/i
          @tls_state = :proted
          str = '200- Accept protection level: PRIVATE'
        else
          str = '504- Do not understand specified protected level: #{arg}'
        end
      end
      send_response(str)
    end

  end

end

