# WesternMUD

[![Build](https://github.com/lewis-weinberger/mud/actions/workflows/ci.yml/badge.svg)](https://github.com/lewis-weinberger/mud/actions/workflows/ci.yml)
[![Release](https://github.com/lewis-weinberger/mud/actions/workflows/deploy.yml/badge.svg)](https://github.com/lewis-weinberger/mud/actions/workflows/deploy.yml)

A simple Western-themed Multi User Dungeon (MUD) server, currently *in progress*:

- [x] Telnet protocol interface
- [x] ANSI colour support
- [ ] An array of user commands and interesting game items
- [ ] Prefab and randomly-generated areas and rooms
- [ ] World persistence (with SQLite)

## Installation

### From source

To build the server from source you'll need to install [Crystal](https://crystal-lang.org/)
(including its package manager
[Shards](https://crystal-lang.org/reference/latest/man/shards/index.html)) and
[SQLite](https://sqlite.org/index.html).

```sh
git clone https://github.com/lewis-weinberger/mud.git
cd mud
shards build --production --release --no-debug
```

This should generate `bin` and `lib` directories, with an executable `bin/mud`.

### Download

Alternatively if you're running Linux on x86_64 you can try the latest pre-built binary
in [Releases](https://github.com/lewis-weinberger/mud/releases/latest).

## Usage

### Hosting a server

The server can be started by specifying an address and port to host on:

```sh
mud 127.0.0.1 5000
```

Clients can then connect using their favourite Telnet client (see [below](#telnet-clients)):

```sh
telnet 127.0.0.1 5000
```

Note if you're hosting over the internet you may need to set up port forwarding on your local
network.

The amount of logging can be set via the environment variable `LOG_LEVEL`.

### Telnet clients

Telnet clients come in all shapes and sizes, with varying support for the different protocol
options. As a minimum, **WesternMUD** requires a client to support:

- 8-bit clean data transfer (the Binary Transmission option from RFC 856),
- Terminal emulation capable of interpreting ANSI control codes (confirmed via the
Terminal Type option from RFC 1091).

It is also worth noting that **WesternMUD** assumes UTF-8 encoding of text. If your client
chooses otherwise (or if its font doesn't have enough glyphs) then you may experience
problems.

Clients running on Unix-like operating systems should set the `TERM` environment variable
to either `xterm` or `ansi`.

## License

[ISC](./LICENSE)
