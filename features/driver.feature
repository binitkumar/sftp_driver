Feature: Driver provides interface to server for ftp processes

  Scenario: User provide invalid username and password
    When  User attempts to login with invalid username or password
    Then Server should give invalid login message

  Scenario: User access ftp server with valid username and password
    When User attempts to login with valid username and password
    Then Server should give valid login message
    And User gets the listing of directory
    Then User creates a new directory
    And User switches to new directory
    Then User puts new file in latest directory
    Then User finds the new file in the directory
    When User downloads the file form the server
    Then User gets the file as he had uploaded


