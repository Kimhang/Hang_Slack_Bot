#!/usr/bin/env perl

use strict;
use warnings;

require Hang::Slack::Bot;
use Data::Printer;

my $client_id = '694170538220-mmc92qgduv2duk4jpodlju9745pkserj.apps.googleusercontent.com';
my $token = 'xoxb-35491816976-iLjbDXbZrGfQvf8oihXtAQVL';
my $secret_key = '_SjqEp7ga5jgPYcnz0KF4FY2';

my $self = Hang::Slack::Bot->new( $client_id, $secret_key, $token, '#perl_bot_test' );
$self->send_msg('제노스 시작합니다.');
