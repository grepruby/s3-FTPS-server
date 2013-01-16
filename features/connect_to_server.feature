Feature: connect to FTPS server

  As a client
  Client wants to connect to FTPS server
  So that user can work on server

  Scenario: AUTH TLS, select tls as security mechanism
    Given Server has started
    When Client send cmd 'AUTH TLS'
    Then Server should respond with 234 when server accept the security mechanism

  Scenario: Authenticate, USER test and PASS 1234
    Given Server has started a TLS command connection
    When Client send cmd 'USER test' and 'PASS 1234'
    Then Server should respond with 230 when user is authenticated

  Scenario: PBSZ 0, negotiated a protection buffer size with server
    Given Server has authenticated user
    When Client send cmd 'PBSZ 0'
    Then Server should respond 200 Success when server accept the pbsz size

  Scenario: PROT P, select a protect level
    Given Server has accept PBSZ
    When Client send cmd 'PROT P'
    Then Server should respond with 504 when accept 'P' but decline

  Scenario: FEAT, display suppported features
    Given Server has accept PROT
    When Client send cmd 'FEAT'
    Then Server should respond with 211 when accept FEAT
