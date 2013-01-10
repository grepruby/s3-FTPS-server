require 'eventmachine'
require 'em-ftpd'

module EM::FTPD

  class Server

    COMMANDS.push 'auth', 'feat', 'pbsz', 'prot'

    def post_init
      @tls_state = :none
      @mode   = :binary
      @name_prefix = "/"

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
    def cmd_auth(arg)
      if arg =~ /^tls$/i
        @tls_state = :authed
        send_response "234 Accept security mechanism: TLS"
        start_tls(:private_key_file => 'ssl/myssl.key', :cert_chain_file => 'ssl/myssl.crt', :verify_peer => false)
      else
        send_response "504 Do not understand security mechanism: '#{arg}'"
      end
    end

    def cmd_feat(arg)
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
    # * If the server has not completed a security data exchange with the
    #   client, it should respond with a 503 reply code.
    # * If the server cannot parse the argument, or if it will not fit in
    #   32 bits, it should respond with a 501 reply code.
    #
    MAX_PBSZ = 2**32 - 1
    def cmd_pbsz(arg)
      if @tls_state != :authed
        str = '503 Need AUTH preceded'
      else
        if arg == '0'
          @tls_state = :pbszed
          str = '200 Success negotiated, no buffering is taking place'
        else
          pbsz = arg.to_i
          if pbsz > 0 && pbsz <= MAX_PBSZ
            str = "200 Sorry, just support no buffer specified ('0')"
          else
            str = '501 Cannot parse the argument'
          end
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
    # * If the specified protection level is accepted, the server must
    #   reply with a 200 reply code to indicate.
    # * If the server is not willing to accept the specified protection
    #   level, it should respond with reply code 534.
    # * If the server does not understand the specified protection level, it
    #   should respond with reply code 504.
    #
    def cmd_prot(arg)
      if @tls_state != :pbszed
        str = '503 Need PBSZ preceded'
      else
        if arg =~ /^p$/i
          @tls_state = :proted
          # str = '200 Accept protection level: PRIVATE'
          str = '504 Decline to make non-TLS connection'
        elsif arg =~ /^[cse]$/i
          str = '536 Do not support the specified protected level'
        else
          str = '504 Do not understand specified protected level: #{arg}'
        end
      end
      send_response(str)
    end

  end

end

