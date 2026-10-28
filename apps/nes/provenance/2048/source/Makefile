default: 2048.nes 2048.nes.ram.nl

.PHONY: run
run: 2048.nes 2048.nes.ram.nl
	fceux 2048.nes

OBJS := 2048.o \
		blit.o \
		board.o \
		controller.o \
		drawing.o \
		header.o \
		nmi.o \
		startup.o \
		tests.o \
		tile-lookups.o \

2048.nes: $(addprefix obj/,$(OBJS)) nrom.cfg
	ld65 -o $@ $(addprefix obj/,$(OBJS)) -C nrom.cfg --dbgfile 2048.nes.db

obj/%.o: src/%.s
	@mkdir -p obj
	ca65 -o $@ $< --debug-info
obj/2048.o: data/2048.chr data/board-background.nam

.PHONY: clean
clean:
	-rm -rf obj 2048.nes 2048.nes.db test/*.o test/*.prg *.nl

.PHONY: test
test: test/test-board.prg
	@echo
	@sim65 test/test-board.prg

test/test-%.prg: test/test-%.s
	cl65 --target sim6502 -o $@ -D TEST $^

test/test-board.prg: test/board.o test/defs.o

test/%.o: src/%.s test/helpers.s
	ca65 -o $@ $< --target sim6502 -D TEST

2048.nes.ram.nl: 2048.nes fceux_symbols.py
	python3 fceux_symbols.py
