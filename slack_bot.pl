#!/usr/bin/env perl

use strict;
use warnings;
use lib 'lib';
require Hang::Slack::Bot;
use Data::Printer;

my $token = 'xoxp-11052762902-11053225927-11053417861-88a0b1aacc';
my $client_id = '158288324156-co2nmbhb2t62ltstgk55q47e4qd6qou7.apps.googleusercontent.com';
my $client_secret = 'iBhUNt0vULV3QDAO_5wRErk0';
my $scope = 'https://www.googleapis.com/auth/calendar';
my $auth_uri = 'https://accounts.google.com/o/oauth2/auth';

my $self = Hang::Slack::Bot->new($token, $client_id, $client_secret, $scope);
$self->socket_start;
