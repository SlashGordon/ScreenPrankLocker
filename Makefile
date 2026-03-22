APP_NAME := ScreenPrankLocker
VERSION := 1.0.0

.PHONY: all build app pkg dmg install test run clean help

all: pkg

build:
	./build.sh build

app:
	./build.sh app

pkg:
	./build.sh pkg

dmg:
	./build.sh dmg

install:
	./build.sh install

test:
	./build.sh test

run:
	./build.sh run

clean:
	./build.sh clean

help:
	./build.sh help

