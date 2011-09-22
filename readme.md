`Irssi` plugin to replay the backlog when a client connects to `Irssi`'s proxy.
===============================================================================
I wanted to use a native client on my new-ish fancy phone to connect
to `irssi`'s proxy (via SSL) and have it replay the backlog of what
I'd missed on all channels and private messages; all without using yet
another program (like a bouncer (something like `znc`)).  So I wrote this
plugin.

It will start the autologging feature on load (or startup if you have the
script load on `irssi` startup).  When a client connects it will stop the
autolog, move the data (clear the autolog), start it up again,
then playback any lines in the
log that are a message to a newly created
window and channel called `#backlog` (unless a channel called that already
exists, in which case it will use that).
When a disconnect message is received the autolog is not (see bugs below)
cleared.
Now this means that the client will need to close the `#backlog`
channel *and window* or the next time another window will be created.  It also
means that there is a chance that if the client times-out (never sends a
disconnect) then it may get more of a backlog than needed, but this is
better than if it times out and misses everything until a clear or
another (possibly spurious) disconnect.

Bugs
====
*  Doesn't always handle hanging connections properly (not really sure
how I could detect that this is happening, or that a particular message
was actually delivered).  If the proxy client times out it is possible
that the server won't get a disconnect message from a random amount of
time.  Ideally we would stop logging while the client is connected, but
then there is a real (and probable) chance the it will miss messages.
So we keep logging.  This means that the client will receive all the
messages that have already been read not on a phone.  As a work-around
I have an alias that clears the backlog that is often typed at not-a-phone
but this is hackish.  Possible solutions are:
*   *  Create a ping pong mechanism from `irssi` to the proxy client.
*   *  Be much smarter about when the log is cleared, for instance when
the proxy user sends a message, or when manual commands are typed that
could not come from the proxy client.

The Story of why I wrote this.
==============================
I spent the better part of the last couple of days trying to get IRC working
the way I want.  I should stop you right here and say that *I am a crazy
person*; well adjusted people are perfectly fine to use what's available not
worry too much about edge cases.

My normal setup has me using `irssi` in a `tmux` session.  I want to be able to
connect periodically with my phone (using use SSL) and have it replay whatever
messages have been received (both channels and private messages) since I last saw
them in `tmux`.  Doing this proved _much_ harder than I thought it would be.

This article---[IRC, My Way](http://noswap.com/articles/irc/)---sparked my
my interest and got me to think I could get a backlog on a phone.

I thought: "OK, I don't really want to run a whole separate bouncer when `irssi`
has a proxy built-in.  Can't I just use that?"  It turns out that that
proxy doesn't support SSL naively.  I found a nice
[patch](http://bugs.irssi.org/index.php?do=details&task_id=645).
that hasn't made it into the release yet.  I compile my own
copy of `irssi`, which went off without much trouble.

The next thing is to have it detect when a proxy client connects and then
replay the backlog.  *What a nightmare.*  Fist thing I tried is [this
script](http://wouter.coekaerts.be/irssi/proxy_backlog).  It works pretty well
except two things:

1. It depends on the client to send a CTCP message and not many (any?)
smartphone clients support CTCP.
2. It replays whatever is still in memory---nothing more and nothing less.
And I will want more or less depending on how long I've been disconnected.

Well then, I thought, "it shouldn't be too hard to modify this to send
automatically on client connect".  After which I lost several hours in `perl`
chasing `irssi`'s references, functions, and hashes.  I was not successful
in figuring out how to get a reliable `view` from a `window` reference, it
worked sometimes, but I did not want to spend many many days reading `irssi`'s
source to figure out how to call the right function references.

Next was `irssi`'s rawlog.  This (mostly for debugging) bounded log is
everything `irssi` does and is kept in memory.  I tried for many hours to get
the rawlog from `irssi`'s API.  I could not do it, apparently the `get_lines`
function needs an argument (even though there is no mention in the
docs and no examples).  From grepping the source I found that it needed a
`Irssi::Rawlog` passed in.  So I attempted to get that from the main module
and pass it in.  Segfault.  In retrospect it probably wanted a reference
instead of a scalar, but at the time I wasn't thinking that well about it.
One can have `irssi` write
this log to a file (which grows indefinitely).  This would have worked fine
except that the raw log is not timestamped and I thought it may be nice to
know when someone said something when the log is played back to a phone.

Then I noticed that `irssi` has an autolog facility that will write out
everything to a set of files.  This seemed like an OK thing to do, I just
need to turn off logging (because of file locks) on connect, write some
`perl` to move the files (so new writes don't mess it up), walk the structure,
parse them, decide what is new and then send that to the phone (opening up a new
channel and writing there (along with some metadata)).  This is what
I actually did.

I'm a bit disappointed that I had to resort to having `irssi` write stuff out
to files and then parse them rather than being able to store the logs in memory
and play them back using the API.  Overall I'm really happy that this is working
well enough that I can use a phone to check in from time to time.
