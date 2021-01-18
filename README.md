# README

Configurations

    Server: EC2 UBUNTU
    Ruby: 3.0.0
    Rails: 6.1
    Mysql
    Nginx
    Passenger
    Capistrano

How to deploy

    Go to EC2 and create an UBUNTU instance with security settings open to anywhere.

    Follow this guide
    https://gorails.com/deploy/ubuntu/20.04

    Change Root if you haven't made any.

    Watch this video to create and add credentials to both local and remote.
    https://www.youtube.com/watch?v=YJzYmhxB8rE

    Try if the website loads.

    If the website loads, install AWS CLI 2 to the user and set configurations for the user

Code

    Purpose
    Transcribe ringle lesson audio into ZOOM json transcribe with AWS transcribe

    Description
    Upload => Call Transcribe => Check Status => Copy Json and Format to ZOOM on call

Gems
To get the script for polly, we need pry, nokogiri, HTTParty
