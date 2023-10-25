// Copyright (c) 2023 Sebastian LaVine <mail@smlavine.com>
// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

use ascii::{isdigit};

// Given an input rune, transitions to another state (or itself).
export type state = fn(r: rune) *state;

// The initial state of the machine (state 1). Matches '\x1B' (ESC) or Enter.
export fn start(r: rune) *state = {
	switch (r) {
	case '\x1B' =>
		return &bracket;
	case '\n' =>
		return &end;
	case =>
		return &start;
	};
};

// Matches '[' (state 2).
export fn bracket(r: rune) *state = {
	switch (r) {
	case '[' =>
		return &angle_bracket;
	case =>
		return &start;
	};
};

// Matches '<' (state 3).
export fn angle_bracket(r: rune) *state = {
	switch (r) {
	case '<' =>
		return &zero;
	case =>
		return &start;
	};
};

// Matches '0' (state 4).
export fn zero(r: rune) *state = {
	switch (r) {
	case '0' =>
		return &semicolon1;
	case =>
		return &start;
	};
};

// Matches ';' (state 5).
export fn semicolon1(r: rune) *state = {
	switch (r) {
	case ';' =>
		return &numbers1;
	case =>
		return &start;
	};
};

// Matches numbers and the semicolon that follows (state 6).
export fn numbers1(r: rune) *state = {
	if (isdigit(r)) {
		return &numbers1;
	} else if (r == ';') {
		return &numbers2;
	} else {
		return &start;
	};
};

// Matches numbers and the 'M' that follows (state 7).
export fn numbers2(r: rune) *state = {
	if (isdigit(r)) {
		return &numbers2;
	} else if (r == 'M') {
		return &end;
	} else {
		return &start;
	};
};

// The final state (state 8). Always loops back to the starting state.
export fn end(r: rune) *state = return &start;
