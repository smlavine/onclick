.POSIX:

NAME = onclick

SRC = main.ha states/states.ha

all: $(NAME)

$(NAME): $(SRC)
	hare build $(HAREFLAGS) -o $(NAME)

check:
	hare test

clean:
	rm -f $(NAME)

install: $(NAME)
	install -m755 $(NAME) $(DESTDIR)$(PREFIX)/bin

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/$(NAME)

.PHONY: all check clean cmd install uninstall
