TARGET_NAME=COCOTERM
TARGET_DISK=cocoterm.dsk
BIN=$(TARGET_NAME).BIN
ASM_FLAGS=--list=$(TARGET_NAME).lst --map=$(TARGET_NAME).map
MESS_DIR=/Applications/mame
MESS=$(MESS_DIR)/mame64

$(TARGET_DISK) : $(TARGET_NAME).asm  $(BIN)
	@echo "Generating disk image..."
	rm -f $@
	decb dskini $@
	decb copy $(BIN) $@,$(BIN)
	decb attr $@,$(BIN) -2 -b

$(BIN): $(TARGET_NAME).asm
	@echo "Building..."
	lwasm $(ASM_FLAGS) -o $@ $^

all: $(BIN) $(TARGET_DISK)

%.bin : %.asm
	lwasm $(FLAGS) $<

clean :
	rm -rf $(TARGET_DISK) $(BIN) *.map *.lst

run : $(TARGET_DISK)
	$(MESS) coco3 -rompath $(MESS_DIR)/roms -window -skip_gameinfo -flop1 $(TARGET_DISK) -cfg_directory ./cfgs/rgb

run_cmp : $(TARGET_DISK)
	$(MESS) coco3 -rompath $(MESS_DIR)/roms -window -skip_gameinfo -flop1 $(TARGET_DISK) -cfg_directory ./cfgs/cmp

debug : $(TARGET_DISK)
	$(MESS) coco3 -rompath $(MESS_DIR)/roms -window -skip_gameinfo -flop1 $(TARGET) -cfg_directory ./cfgs/rgb -debug

debug_cmp : $(TARGET_DISK)
	$(MESS) coco3 -rompath $(MESS_DIR)/roms -window -skip_gameinfo -flop1 $(TARGET_DISK) -cfg_directory ./cfgs/cmp -debug
