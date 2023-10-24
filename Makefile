.POSIX:

include config.mk

NAME = onclick

SRC = main.ha states/states.ha

all: $(NAME)

$(NAME): $(SRC)
	$(HARE) build $(HAREFLAGS) -o $(NAME)

check:
	$(HARE) test

clean:
	rm -f $(NAME)

install: $(NAME)
	cp $(NAME) $(DESTDIR)$(PREFIX)/bin

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/$(NAME)

.PHONY: all check clean cmd install uninstall
