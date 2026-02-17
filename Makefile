GBFILE := kenken.gb

ASMFILES := $(shell find src/ -type f -name '*.asm')
OBJFILES := $(ASMFILES:%.asm=%.o)

BGS := $(shell find assets/bg -type f -name '*.png')
MAPS := $(BGS:assets/bg/%.png=src/assets/%.bin.map)

SPRITES := $(shell find assets/sprite -type f -name '*.png')
ASSETS := \
	$(SPRITES:assets/sprite/%.png=src/assets/%.bin) \
	$(BGS:assets/bg/%.png=src/assets/%.bin)

.PHONY: clean

$(GBFILE): $(ASSETS) $(OBJFILES)
	rgblink $(OBJFILES) -o $@
	rgbfix -v -p 0xFF -t "KENKEN" $@

src/%.o : src/%.asm $(ASSETS)
	rgbasm -I src $< -o $@

src/assets/%.bin: assets/bg/%.png
	rgbgfx -u -t $@.map -o $@ $<	

src/assets/%.bin: assets/sprite/%.png
	rgbgfx -o $@ $<	

clean:
	rm -f $(ASSETS) $(GBFILE) $(MAPS) $(OBJFILES)
