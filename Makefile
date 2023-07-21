# Frontend to dune.

.PHONY: default build install uninstall test clean fmt
.IGNORE: fmt

default: build

init:
	opam switch list | grep $(PWD) || opam switch create . ocaml-base-compiler.4.14.0 -y -t 
	eval $$(opam env)

build:
	opam exec -- dune build

test:
	opam exec -- dune runtest -f

install:
	opam exec -- dune install

uninstall:
	opam exec -- dune uninstall

clean:
	opam exec -- dune clean
# Optionally, remove all files/folders ignored by git as defined
# in .gitignore (-X).
	git clean -dfXq

fmt:
	opam exec -- dune build @fmt
	opam exec -- dune promote
