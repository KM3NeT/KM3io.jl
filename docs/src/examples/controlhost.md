# Accessing Live Data

This example shows how to access and process live data (events) from the KM3NeT
DAQ system. We will use two Jpp command line tools
([`JLigier`](https://common.pages.km3net.de/jpp/#JLigier) and
[`JRegurgitate`](https://common.pages.km3net.de/jpp/#JRegurgitate)) to create a
ligier dispatcher and send triggered DAQ events to it.

This example uses Jpp v14.4.3 and real data from a KM3NeT detector (online ROOT
format) with the filename `KM3NeT_00000075_00010275.root` which can be found on
the HPSS storage.

## Launching `JLigier`

We open a terminal and launch the `JLigier` process with a high debug level.
This ligier is the central communication point and it will receive messages
which are tagged with short label of maximum 8 characters.

```shell
$ JLigier -P 5553 -d 3
Port              5553
Memory limit 16760735744
Queue  limit        100
```

The ligier is now running and and listening on port 5553 of all host IP
addresses (including the localhost `127.0.0.1`). Clients can connect to it and
subscribe for a given set of message tags. Leave this terminal open.

## Simulating the DAQ

The first client we start in new terminal session is the
[`JRegurgitate`](https://common.pages.km3net.de/jpp/#JRegurgitate) process which
takes a ROOT file (in online format), a class identifier, a few other parameters
like the frequency and timeout of the messages and also the IP and port of the
ligier to send to. We will use this application to simulate the KM3NeT DAQ -- at
least the output of the
[`JDataFilter`](https://common.pages.km3net.de/jpp/#JDataFilter) which is
responsible for triggering events and sending them downstreams to a `JLigier` so
that they can be picked up by the
[`JDataWriter`](https://common.pages.km3net.de/jpp/#JDataWriter) to store them in 
[ROOT files (online format)](/manual/rootfiles/#Online-Dataformat).

```shell
$ JRegurgitate -f /data/sea/KM3NeT_00000075_00010275.root -C JDAQEvent -R 2 -T 10000000 -H 127.0.0.1:5553
```

This program is fairly quite but if you look at the terminal where the `JLigier`
is running, you'll see a flood of messages, showing that a new client has
connected and data is received (tagged with `IO_EVT`). It also prints the number
of bytes of each message:

```shell
$ JLigier -P 5553 -d 3
Port              30001
Memory limit 16760735744
Queue  limit        100
New client[4]
Client[4].read(0,1,1756)
Client[4].read(1,2,0)
Message[4] IO_EVT 1772
Client[4].read(0,1,1394)
Client[4].read(1,2,0)
Message[4] IO_EVT 1410
Client[4].read(0,1,1716)
...
...
...
```

## Retrieving Events

Now open a thrid terminal and fire up the Julia REPL. With a few lines, we will
able to connect to the ligier and receive DAQ events interactively.

```julia-repl
julia> using KM3io

julia> c = CHClient{KM3io.DAQEvent}(ip"127.0.0.1", 5553)
CHClient{DAQEvent}(ip"127.0.0.1", 0x7531, CHTag[CHTag("IO_EVT")], Sockets.TCPSocket(RawFD(20) open, 0 bytes waiting))

julia> for e in c
         @show e
       end
e = DAQEvent with 126 snapshot and 7 triggered hits
e = DAQEvent with 138 snapshot and 6 triggered hits
e = DAQEvent with 149 snapshot and 6 triggered hits
e = DAQEvent with 149 snapshot and 6 triggered hits
e = DAQEvent with 136 snapshot and 6 triggered hits
...
...
...
```
