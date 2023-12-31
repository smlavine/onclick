// Copyright (c) 2023 Sebastian LaVine <mail@smlavine.com>
// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

use bufio;
use encoding::utf8;
use errors;
use fmt;
use getopt;
use io;
use os::exec;
use os;
use strings;
use unix::signal;
use unix::tty;

use states;

// Sentinel that signals whether or not the program loop should end.
let loop: bool = true;

// Whether or not to clear the screen before each command invocation.
let clear: bool = false;

// Global tty file value. Set global to make visible to signal handlers.
// The set value is temporary and will be initialized to /dev/tty.
let tty: io::file = -1; // XXX initializer assignment?

// Global termios value. Set global to make visible to signal handlers.
let termios = tty::termios { ... }; // XXX initializer assignment?

fn quit_signals(s: signal::sig, i: *signal::siginfo, u: *opaque) void = {
	loop = false;
};

fn prepare() void = {
	// Enable mouse tracking (ANSI escape sequence).
	fmt::fprint(tty, "\x1B[?1000;1006;1015h")!;
	tty::noecho(&termios)!;
	tty::noncanonical(&termios)!;
	// Cleanup the terminal before suspend (^Z).
	// Located here because this will be called after the TSTP handler
	// is reset.
	signal::handle(signal::sig::TSTP, &_cleanup, signal::flag::RESETHAND);
};

fn _prepare(s: signal::sig, i: *signal::siginfo, u: *opaque) void = {
	prepare();
};

fn cleanup() void = {
	// Restore settings set in prepare().
	tty::termios_restore(&termios);
	// Disable mouse tracking when the program exits.
	fmt::fprint(tty, "\x1B[?1000;1006;1015l")!;
	if (clear) {
		fmt::fprint(tty, "\x1Bc")!;
	};
};

fn _cleanup(s: signal::sig, i: *signal::siginfo, u: *opaque) void = {
	cleanup();
	if (s == signal::sig::TSTP) {
		// This should have been registered as a signal handler with
		// the RESETHAND flag, meaning that raising TSTP on this
		// process within this handler will cause the usual suspend
		// behavior. Note that the signal must be re-registered in
		// _prepare() so that suspends will work properly
		// more than once.
		exec::sig(exec::self(), signal::sig::TSTP)!;
	};
};

// Waits for mouse click input, then runs the provided command.
fn wait_then_run_command(in: io::handle, cmdargs: []str, cmdstr: str) void = {
	for (let sm: *states::state = &states::start; sm != &states::end) {
		// We have to keep an eye on loop because it could be modified
		// by the termination signals. We can't have this check in
		// the `for` condition, because then it would go to the part
		// after the loop where we run the command.
		if (!loop) {
			return;
		};
		match (bufio::read_rune(in)) {
		case let r: rune =>
			sm = sm(r);
		case io::EOF =>
			loop = false;
			return;
		case errors::interrupted =>
			// A constituent type of io::error.
			// The read was probably interrupted by a quit or
			// suspend signal. If that's the case, continue the
			// loop. If it was a quit, then `loop` has been set
			// and we will return on the next `for` iteration.
			continue;
		case let e: io::error =>
			fmt::fprintln(os::stderr, "onclick input error:",
				io::strerror(e))!;
			loop = false;
			return;
		case utf8::invalid =>
			abort("invalid input: expected utf8");
		};
	};

	let cmd = match (exec::cmd(cmdargs[0], cmdargs[1..]...)) {
	case let c: exec::command =>
		yield c;
	case let e: exec::error =>
		fmt::fprintfln(os::stderr, "onclick: {}: {}",
			cmdstr, exec::strerror(e))!;
		loop = false;
		return;
	};

	// Give the command a normal terminal environment.
	cleanup();

	// Prints the command in bold.
	fmt::printfln("{}>> {}{}", "\x1B[1m", cmdstr, "\x1B[0m")!;

	let process = exec::start(&cmd)!;
	exec::wait(&process)!;

	// Aaand we're back. Our terminal now.
	prepare();
};

export fn main() void = {
	const cli = getopt::parse(os::args,
		"Runs a command every time the terminal is clicked",
		('C', "clear the screen before each command"),
		"command [arguments...]",
	);
	defer getopt::finish(&cli);

	for (let i = 0z; i < len(cli.opts); i += 1) {
		switch (cli.opts[i].0) {
		case 'C' =>
			clear = true;
		case =>
			abort("unreachable");
		};
	};

	if (len(cli.args) == 0) {
		getopt::printusage(os::stderr, os::args[0], cli.help)!;
		os::exit(os::status::FAILURE);
	};

	let cmdstr = strings::join(" ", cli.args...);
	defer free(cmdstr);

	tty = match (tty::open()) {
	case let f: io::file =>
		yield f;
	case let e: tty::error =>
		fmt::fatal("Couldn't open tty:", tty::strerror(e));
	};
	defer io::close(tty): void;

	termios = match (tty::termios_query(tty)) {
	case let t: tty::termios =>
		yield t;
	case let e: errors::error =>
		fmt::fatal("Couldn't get termios information:",
			errors::strerror(e));
	};

	// Let the user quit with ^C or ^\.
	signal::handle(signal::sig::INT, &quit_signals);
	signal::handle(signal::sig::QUIT, &quit_signals);

	// Prepare the terminal when returned from suspend (^Z).
	signal::handle(signal::sig::CONT, &_prepare);

	prepare();

	for (loop) {
		wait_then_run_command(tty, cli.args, cmdstr);
	};

	cleanup();
};
