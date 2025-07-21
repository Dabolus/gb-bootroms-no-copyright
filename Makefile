.SECONDEXPANSION:

MODELS := dmg

dmg_asm   := dmg.asm
dmg_size  := 256

BINS := $(patsubst %,bin/%.bin,${MODELS})
SYMS := $(patsubst %,bin/%.sym,${MODELS})
all: ${BINS} ${SYMS}
.PHONY: all

clean:
	rm -rf bin obj
.PHONY: clean

# This pipeline won't fail if `rgblink` errors out but `sed` doesn't.
# But `set -o pipefail` would fail to build on Alpine or w/e, so let's assume linking will go well.
bin/%.sym bin/%.bin: obj/%.o
	@mkdir -p ${@D}
	rgblink -p 0 $^ -o bin/$*.bin -n - | sed 's/^0*:0/BOOT:0/' >bin/$*.sym
	truncate -s ${$*_size} bin/$*.bin

obj/%.o: src/$${$$*_asm}
	@mkdir -p ${@D}
	rgbasm -p 0xFF -D $* -I src/ -o $@ $<
