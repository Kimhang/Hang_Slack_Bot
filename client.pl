#!/usr/bin/env perl

use strict;
use warnings;

require Hang::Slack::Bot;
use Data::Printer;

my $client_id = '516481921508-k6kuq5o970cish6daf5b3iutj3htbplh.apps.googleusercontent.com';
my $token = 'xoxb-35491816976-iLjbDXbZrGfQvf8oihXtAQVL';
my $secret_key = 'nX7gYAcPQHvPpjxPLv6B_tzx';
my $refresh_token = '1/-F1jrY0av0WmGI0Qok4IUw5ybZalVtuY7Y4kmkGeNTkMEudVrK5jSpoR30zcRFq6';

my $self = Hang::Slack::Bot->new( $client_id, $secret_key, $token, $refresh_token, '#perl_bot_test' );
$self->send_msg('제노스 시작합니다.');
$self->socket_start;
