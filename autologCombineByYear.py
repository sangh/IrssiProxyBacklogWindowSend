#!/usr/bin/python

from __future__ import (absolute_import, division,
                        print_function, unicode_literals)
import datetime
import os
import sys

help = """The Irssi plug-in `proxy_backlog_window_send.pl` can leave a lot
of directories around in `${HOME}/.irssi/autolog_saved/` after some time.
This could get cumbersome to search and whatnot, so this script will combine
them (in order) into directories (one per year).

It is expected that this is run on a *nix box by hand periodically.
"""

autologdir = os.path.join(os.getenv("HOME"), ".irssi", "autolog_saved")
def toTimeStr(ts):
    return datetime.datetime.fromtimestamp(ts).strftime('%Y-%m-%d %H:%M:%S')

def wrn(s):
    print(s,file=sys.stderr)
def bye(s):
    wrn(s)
    sys.exit(1)
def ConfirmOrExit(s):
    try:
        if "Y" != (raw_input(s + " [no] ")[0]).upper():
            raise Exception
    except:
        bye("OK, exiting.")

# Pull out the timestamps and the years.
nets_years = {}
nets_tsas = {}
for f in os.listdir(autologdir):
    s = f.split("_")
    if len(s) != 2:  # Sometimes random other log files show up.
        continue
    if 4 == len(s[0]):  # This is not a year and not a ts.
        if s[1] in nets_years:
            nets_years[s[1]].append(int(s[0]))
        else:
            nets_years[s[1]] = [int(s[0]), ]
    elif 10 == len(s[0]):
        if s[1] in nets_tsas:
            nets_tsas[s[1]].append(int(s[0]))
        else:
            nets_tsas[s[1]] = [int(s[0]), ]
    else:
        bye("Bad timestamp: " + str(s[0]))
for k in nets_years.keys():
    nets_years[k] = sorted(nets_years[k])
for k in nets_tsas.keys():
    nets_tsas[k] = sorted(nets_tsas[k])

if(1 != len(sys.argv)):
    bye("No arguments taken, this program just combines all the log dirs." +
        "\n" + help)

todo_create_dirs = []
todo_create_file = []
todo_append_file = {}
for net in nets_tsas.keys():
    for ts in nets_tsas[net]:
        ts_str = toTimeStr(ts)
        ts_year = int(ts_str[0:4])
        if 2010 > ts_year or 2070 < ts_year:
            bye("Bad year in " + net + ": " + str(ts) + " " + ts_str)
        year_net_dir = os.path.join(autologdir, str(ts_year) + "_" + net)
        if not year_net_dir in todo_create_dirs:
            if not net in nets_years or not ts_year in nets_years[net]:
                todo_create_dirs.append(year_net_dir)
        dir_to_append_from = os.path.join(autologdir, str(ts) + "_" + net)
        for f in os.listdir(dir_to_append_from):
            file_to_append_to = os.path.join(year_net_dir, f)
            if not os.path.isfile(file_to_append_to):
                if not file_to_append_to in todo_create_file:
                    todo_create_file.append(file_to_append_to)
            if not file_to_append_to in todo_append_file.keys():
                todo_append_file[file_to_append_to] = []
            todo_append_file[file_to_append_to].append(
                os.path.join(dir_to_append_from, f))

for d in todo_create_dirs:
    wrn("Create directory: " + d)
for f in todo_create_file:
    wrn("Create file: " + f)
for f in todo_append_file.keys():
    for ff in todo_append_file[f]:
        wrn("Append to: " + f + ": " + ff)
wrn("Lenght of create dirs: " + str(len(todo_create_dirs)))
wrn("Lenght of create file: " + str(len(todo_create_file)))
wrn("Lenght of append file: " + str(len(todo_append_file)))

if len(todo_create_dirs) > 0:
    ConfirmOrExit("Continue with create dirs?")

    for d in todo_create_dirs:
        os.mkdir(d, 0750)

if len(todo_create_file) > 0:
    ConfirmOrExit("Continue with create files?")

    for f in todo_create_file:
        open(f, 'a').close()
        os.chmod(f, 0640)

if len(todo_append_file.keys()) > 0:
    ConfirmOrExit("Continue with the appending?")

    for f in todo_append_file.keys():
        fa = open(f, 'a')
        for ff in todo_append_file[f]:
            ffa = open(ff, 'r')
            fa.write(ffa.read())
            ffa.close()
        fa.close()
        for ff in todo_append_file[f]:  # Do this after the close.
            os.remove(ff)
    todo_rm_dirs = []
    for f in todo_append_file.keys():
        for ff in todo_append_file[f]:
            d = os.path.dirname(ff)
            if not d in todo_rm_dirs:
                todo_rm_dirs.append(d)
    for d in todo_rm_dirs:
        try:
            os.rmdir(dir_to_append_from)
        except:
            wrn("Could not remove: " + dir_to_append_from)
