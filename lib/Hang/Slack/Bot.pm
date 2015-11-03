package Hang::Slack::Bot;
use utf8;
use Moose;
use HTTP::Request::Common qw(POST GET);
use Furl;
use IO::Socket;
use Net::Google::DataAPI::Auth::OAuth2;
use Net::OAuth2::Profile::WebServer;
use Net::Google::Calendar;
use Protocol::Websocket::Client;
use JSON qw/encode_json decode_json/;
use Encode qw/encode_utf8/;
use Data::Printer;

sub new {
    my ( $class, $token, $client_id, $client_secret, $scope ) = @_;

    my $res = Furl->new->post( 'https://slack.com/api/rtm.start', [], +{ token => $token } );
    die "response fail" unless decode_json($res->content)->{ok};

    my $url = decode_json($res->content)->{url};
    my $channel_id = decode_json($res->content)->{channels}[0]{id};

    return bless {
        url => $url,
        token => $token,
        channel_id => $channel_id,
        client_id => $client_id,
        client_secret => $client_secret,
        scope => $scope,
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
        read => sub {    
            my ( $client, $buf ) = @_;
            $self->channels_history;
        }
    );
    $client->on(
        write => sub {
            my ( $client, $buf ) = @_;
            syswrite $socket, $buf;
        }
    );
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

sub channels_history {
    my $self = shift;

    my $token = $self->{token};
    my $channel_id = $self->{channel_id};
    my $client_id = $self->{client_id};
    my $client_secret = $self->{client_secret};
    my $scope = $self->{scope};

    my $req = POST 'https://slack.com/api/channels.history',
       'Content' => [
           token => $token,
           channel => $channel_id,
           count => 1,
        ];
    my $res = Furl->new->request($req);
    my $json = decode_json(encode_utf8($res->content));
    my $subtype = $json->{messages}[0]{subtype};
    my $text = $json->{messages}[0]{text};

    if ( !$subtype ) {
        send_msg( $text, $token );

        if ( $text and $text =~ m/calendar/i ) {
            $self->authorized;
        }elsif ( $text and $text =~ m/^!!(.+)$/i ) {
            $self->get_access_token( $1 );
        }
    }elsif ( $subtype and $subtype eq 'bot_message' ) {
        sleep 1;
    }
}
#calendar
#code 복붙
#나머지 처리
#명령어를 입력하면 캘린더에 추가

sub authorized {
    my $self = shift;

    my $token = $self->{token};
    my $client_id = $self->{client_id};
    my $client_secret = $self->{client_secret};
    my $scope = $self->{scope};

    my $oauth2 = Net::Google::DataAPI::Auth::OAuth2->new(
            client_id => $client_id,
            client_secret => $client_secret,
            scope => [ $scope ]
    );
    my $auth_url = $oauth2->authorize_url();
    send_msg( $auth_url, $token );
}

sub get_access_token {
    my ( $self, $code ) = @_;

    my $client_id = $self->{client_id};
    my $client_secret = $self->{client_secret};

    my $redirect_uri = 'urn:ietf:wg:oauth:2.0:oob';
    my $token_uri = 'https://accounts.google.com/o/oauth2/token';

    my $req = POST $token_uri,
       'Content' => [
           client_id => $client_id,
           client_secret => $client_secret,
           redirect_uri => $redirect_uri,
           grant_type => 'authorization_code',
           code => $code,
        ];
    my $res = Furl->new->request($req);
    my $access_token = decode_json($res->content)->{access_token};
    my $refresh_token = decode_json($res->content)->{refresh_token};
    my $token_type = decode_json($res->content)->{token_type};

    my $ua = Furl->new();
    my $api_param = {
        client_id => $client_id,
        client_secret => $client_secret,
        grant_type => 'refresh_token',
        refresh_token => $refresh_token,
    };
    my $response = $ua->post(
            $token_uri,
            [],
            $api_param
    );

    $response->is_success or die $response->code . " " . $response->message . "\n";

    my $body = decode_json($response->body);
    $body->{refresh_token} = $refresh_token;
    $self->save_access_token(encode_json($body));
}

sub save_access_token {
    my ( $self, $body ) = @_;

}

sub send_msg {
    my ( $text, $token ) = @_;

    my $req = POST 'https://slack.com/api/chat.postMessage',
       'Content' => [
           token => $token,
           channel => '#general',
           text => $text,
        ];
    my $res = Furl->new->request($req);
}


#명령어를 입력하면 원하는 파일을 저장소에서 갖고오기

1;
