#!/usr/bin/perl

# See the readme file.

use strict;
use File::Copy;
use File::Path;
use Irssi;

use vars qw($VERSION %IRSSI);

$VERSION = "20111021";
%IRSSI = (
    authors     => "San GH",
    contact     => "http://github.com/sangh",
    name        => "San GH",
    description => "On proxy connect, create a backlog channel in a hidden window and then send the backlog to it.",
    license     => "GPLv2",
    url         => "",
    changed     => "$VERSION",
    commands    => "backlogwindowsend"
);

# Stuff the user may want to change.
# Dir to store the autolog in.
my $aldir = $ENV{"HOME"} . "/.irssi/autolog";
# Channal that is used (created if needed) to write the blog to, nick is added.
my $bchan_prefix = "#backlog";
# Milli pause between lines sent (servers may choke if the is too fast).
my $waitline = 200;
# If n lines is modulus this, pause for $waitclientbufferlines ms.
my $clientbufferlines = 25;
# And pause for this long after $clientbufferlines, in millis.
my $waitclientbufferlines = 30000;
# If you want to keep a permanant history of the logs, then set
# this to a directory, if it's undef then nothing will be stored.
#my $permhistdir = undef;
my $permhistdir = $ENV{"HOME"} . "/.irssi/autolog_saved";

# First make sure the autolog is what we want.
Irssi::Server->command("set autolog_path $aldir/\$tag/\$0.log");
Irssi::Server->command("set autolog_colors off");
Irssi::Server->command("set autolog_level all");
Irssi::Server->command("set autolog on");

#Bind
Irssi::command_bind('backlogwindowsend_clear' => \&cmd_backlogwindowsend_clear);
Irssi::signal_add("proxy client connected" => \&cmd_backlogwindowsend );
# Bad hack, for now.
#Irssi::signal_add("proxy client disconnected" => \&cmd_backlogwindowsend_clear_client );

# One global, start script adds the nick.
my $bchan = $bchan_prefix;

# Helper function.
sub pullbacklog {
    my ($serv) = @_;
    # Check if there are unfinished logs.
    foreach my $tag ( <$aldir/*_backlogwindowsend> ) {
        return((":::::::: Backlog proxy thing found " .
                "previous unfinised logs. ::::::::"));
    }
    # We want the log off for as little time as possible.
    $serv->command("set autolog off");
    foreach my $tag ( <$aldir/*> ) {
        move( "$tag", "$tag"."_backlogwindowsend" );
    }
    $serv->command("set autolog on");
    # If we want a permanant history
    if( defined( $permhistdir ) ) {
        my $epochsec = time();
        foreach my $tag ( <$aldir/*_backlogwindowsend> ) {
            $tag =~ m/\/([^\/]+)_backlogwindowsend$/ ;
            my $dir = $1;
            # Ugly hack in case this gets called more than once a secont.
            my $ndir = $permhistdir . "/" . $epochsec . "_" . $dir;
            while( -e $ndir ) {
                $epochsec = $epochsec + 1;
                $ndir = $permhistdir . "/" . $epochsec . "_" . $dir;
            }
            mkpath( $ndir );
            foreach my $f ( <$tag/*> ) {
                $f =~ m/\/([^\/]+)$/ ;
                my $c = $1;
                copy( $f, $ndir . "/" . $1 );
            }
        }
    }
    my @ret = ();
    foreach my $tag ( <$aldir/*_backlogwindowsend/*> ) {
        $tag =~ m/\/([^\/]+)[.]log$/ ;
        my $chan = $1;
        # ignore the chan $bchan, if it was left open.
        if( "$bchan" eq $chan ) {
            unlink( "$tag" );
            next;
        }
        my $n = 0;
        open( F, "<", "$tag" );
        push( @ret, ":::::::: $chan ::::::::" );
        while( <F> ) {
            chomp;
            if( $_ =~ m/^([0-9]{2}[:][0-9]{2}) ([<][^>]+[>]|\[[^\]]+\]|[{][^}]+[}]) (.+)$/ ) {
                my $timenick = $1 . " " . $2;
                my $mesg = $3;
                push( @ret, "$timenick" );
                push( @ret, "$mesg" );
                $n = 1 + $n ;
            }
        }
        push( @ret, ":::::::: $n lines in $chan ::::::::" );
        close( F );
        unlink( "$tag" );
    }
    foreach my $tag ( <$aldir/*_backlogwindowsend> ) {
        rmdir( "$tag" );
    }
    if( 0 == int( @ret ) ) {
        return((":::::::: No backlog files found. ::::::::"));
    }

    return @ret;
}

sub sendbacklog {
    my( $aref ) = @_;
    my @a = @$aref;
    my $serv = shift( @a );
    my $line = shift( @a );
    if( defined( $line ) ) {
        chomp( $line );
        $serv->command("msg $bchan $line");
        my @args = ( $serv, @a );
        my $wait = $waitline;
        if( 0 == scalar( @a ) % $clientbufferlines ) {
            $wait = $waitclientbufferlines;
        }
        Irssi::timeout_add_once( $wait, \&sendbacklog, \@args );
    }
}

sub cmd_backlogwindowsend {
    my ($client) = @_;
    my $serv = $client->{ server };
    # Set the channel to use (global).
    $bchan = $bchan_prefix . $serv->{ nick };
    # Start the window stuff.
    if( not defined( $serv->window_item_find( "$bchan" ) ) ) {
        $serv->command("window new hide");
        $serv->command("join $bchan");
        $serv->command("window last");
    }

    # Basically we turn off autolog, move the dir, and restart.
    my @args = ( $serv, pullbacklog( $serv ) );

    Irssi::timeout_add_once( 6000, \&sendbacklog, \@args );
}

sub cmd_backlogwindowsend_clear_client {
    my ($client) = @_;
    my $serv = $client->{ server };
    my @s = pullbacklog( $serv );
    $serv->print(undef, "Threw away ".int(@s)." lines from log.");
}

sub cmd_backlogwindowsend_clear {
    my ($args, $serv, $item) = @_;
    my @s = pullbacklog( $serv );
    $serv->print(undef, "Threw away ".int(@s)." lines from log.");
}
