#!/usr/bin/perl

# See the readme file.

use strict;
use File::Copy;
use Irssi;

use vars qw($VERSION %IRSSI);

$VERSION = "20110918";
%IRSSI = (
    authors     => "San",
    contact     => "san\@procyon.com",
    name        => "San",
    description => "On proxy connect, create a backlog channel in a hidden window and then send the backlog to it.",
    license     => "GPLv2",
    url         => "",
    changed     => "$VERSION",
    commands    => "backlogwindowsend"
);

my $aldir = "~/.irssi/autolog";

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

# Helper function.
sub pullbacklog {
    # Check if there are unfinished logs.
    foreach my $tag ( <$aldir/*_backlogwindowsend> ) {
        return((":::::::: Backlog proxy thing found " .
                "previous unfinised logs. ::::::::"));
    }
    foreach my $tag ( <$aldir/*> ) {
        move( "$tag", "$tag"."_backlogwindowsend" );
    }
    my @ret = ();
    foreach my $tag ( <$aldir/*_backlogwindowsend/*> ) {
        $tag =~ m/\/([^\/]+)[.]log$/ ;
        my $chan = $1;
        # ignore the chan #backlog, if it was left open.
        if( "#backlog" eq $chan ) {
            unlink( "$tag" );
            next;
        }
        my $n = 0;
        open( F, "<", "$tag" );
        push( @ret, ":::::::: $chan ::::::::" );
        while( <F> ) {
            chomp;
            if( $_ =~ m/^([0-9]{2}[:][0-9]{2} [<][^>]+[>]) (.+)$/ ) {
                my $timenick = $1;
                my $mesg = $2;
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
        $serv->command("msg #backlog $line");
        my @args = ( $serv, @a );
        Irssi::timeout_add_once( 250, \&sendbacklog, \@args );
    }
}

sub cmd_backlogwindowsend {
    my ($client) = @_;
    my $serv = $client->{ server };
    # Start the window stuff.
    if( not defined( $serv->window_item_find( "#backlog" ) ) ) {
        $serv->command("window new hide");
        $serv->command("join #backlog");
        $serv->command("window last");
    }

    # Basically we turn off autolog, move the dir, and restart.
    $serv->command("set autolog off");

    my @args = ( $serv, pullbacklog() );

    $serv->command("set autolog on");

    Irssi::timeout_add_once( 6000, \&sendbacklog, \@args );
}

sub cmd_backlogwindowsend_clear_client {
    my ($client) = @_;
    my $serv = $client->{ server };
    $serv->command("set autolog off");
    my @s = pullbacklog();
    $serv->print(undef, "Threw away ".int(@s)." lines from log.");
    $serv->command("set autolog on");
}

sub cmd_backlogwindowsend_clear {
    my ($args, $serv, $item) = @_;
    $serv->command("set autolog off");
    my @s = pullbacklog();
    $serv->print(undef, "Threw away ".int(@s)." lines from log.");
    $serv->command("set autolog on");
}
