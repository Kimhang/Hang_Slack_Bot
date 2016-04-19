package Hang::Slack::Bot;
use utf8;
use Moose;
use HTTP::Request::Common qw(POST GET);
use IO::Socket;
#use Net::OAuth2::Profile::WebServer;
use Net::Google::Calendar;
use Protocol::WebSocket::Client;
use JSON qw/encode_json decode_json/;
use Encode qw/encode_utf8/;
use LWP::UserAgent;
use Data::Printer;
use Data::Dumper;

my $ua = LWP::UserAgent->new;

sub new {
    my ( $class, $client_id, $secret_key, $token, $refresh_token, $channel ) = @_;

    my $res = $ua->request(POST 'https://slack.com/api/rtm.start', 'Content' => [ token => $token ] );
    die "response fail" unless decode_json($res->content)->{ok};

    my $content = decode_json($res->content);
    my $url = $content->{url};

    return bless {
        url        => $url,
        token      => $token,
        client_id  => $client_id,
        chennel    => $channel,
        refresh_token => $refresh_token,
        secret_key => $secret_key,
    }, $class;
}

sub socket_start {
    my $self = shift;
    my $url = $self->{url};

    my ($host) = $url =~ m{wss://(.+)/websocket};

    my $socket = IO::Socket::SSL->new( PeerHost => $host, PeerPort => 443 );
    $socket->blocking(0);
    $socket->connect;

    my $client = Protocol::WebSocket::Client->new( url => $self->{url} );
    $client->on(
        connect => sub {
            print "on_connect\n";
        }
    );
    $client->on(
        error => sub {
            my ( $client, $error ) = @_;
            print 'on_error: ', $error, "\n";
        }
    );
    $client->on(
        read => sub {    
            my ( $client, $buf ) = @_;

            $buf =~ /"type":"(.+)","channel".*"text":"(.+)","ts"/;
            my ( $msg, $text ) = ( $1, $2 );

            if( $msg eq 'message' and $text =~ /^(?:\*\*)/ ) {
                $self->check_msg($text);
            }
        }
    );
    $client->on(
        write => sub {
            my ( $client, $buf ) = @_;
            syswrite $socket, $buf;
        }
    );
    
    $client->connect;

    my $i = 0;
    while (1) {
        my $data = '';
        while ( my $line = readline $socket ) {
            $data .= $line;
            last if $line eq "\r\n";
        }

        $client->read($data) if $data;
        if ( $i++ % 30 == 0 ) { 
            $client->write('{"type": "ping"}');
        }

        sleep 1;
    }
}

sub check_msg {
    my ( $self, $text ) = @_;

    my ( $order, $detail ) = split( ' ', $text ) if $text;

    my $token = $self->get_token;

##캘린더에 새 이벤트 등록
    $self->google_calendar($token) if $order =~ /^\*\*calendar$/;

##파일 내려받기
    $self->get_file($detail) if $order =~ /^\*\*file$/;
}

sub get_token {
    my $self = shift;

    my $client_id = $self->{client_id};
    my $client_secret = $self->{secret_key};
    my $refresh_token = $self->{refresh_token};

    $ua->timeout(10);
    $ua->env_proxy;

    my $res = $ua->request(POST 'https://accounts.google.com/o/oauth2/token',
            'Host'          => 'accounts.google.com',
            'Content_Type'  => 'application/x-www-form-urlencoded',
            'Content'       => [
                'client_id'         =>  $client_id,
                'client_secret'     =>  $client_secret,
                'refresh_token'     =>  $refresh_token,
                'grant_type'        =>  'refresh_token',
            ],
        );

    my $access_token = decode_json($res->content)->{access_token};

    return $access_token;
}

sub google_calendar {
    my ( $self, $token ) = @_;

}

sub get_file {
    my ( $self, $detail ) = @_;
}

sub send_msg {
    my ( $self, $text ) = @_;

    $ua->request(POST 'https://slack.com/api/chat.postMessage',
       'Content' => [
            token => $self->{token},
            channel => $self->{chennel},
            text => $text,
            as_user => 'true',
        ],
    );
}

1;
