ASSEMBLER  		= nasm
ASM_FLAGS		= -felf64

LINKER 			= ld
LD_FLAGS		= -no-pie

SOURCES_DIR     = src
OBJECTS_DIR     = obj
LISTING_DIR		= lst
BUILD_DIR       = bin

EXECUTABLE 	    = printf
EXECUTABLE_PATH = $(BUILD_DIR)/$(EXECUTABLE)

SOURCE_FILES  = $(wildcard $(SOURCES_DIR)/*.asm)
OBJECT_FILES  = $(subst $(SOURCES_DIR), $(OBJECTS_DIR), $(SOURCE_FILES:.asm=.o))
LISTING_FILES = $(subst $(SOURCES_DIR), $(OBJECTS_DIR), $(SOURCE_FILES:.asm=.lst))

all: $(EXECUTABLE_PATH)

$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

$(OBJECTS_DIR):
	@mkdir -p $(OBJECTS_DIR)

$(LISTING_DIR):
	@mkdir -p $(LISTING_DIR)

$(EXECUTABLE_PATH): $(OBJECT_FILES) $(BUILD_DIR)
	@$(LINKER) $(LD_FLAGS) $(OBJECT_FILES) -o $@

$(OBJECTS_DIR)/%.o $(LISTING_DIR)/%.lst: $(SOURCES_DIR)/%.asm $(OBJECTS_DIR) $(LISTING_DIR)
	@$(ASSEMBLER) $(ASM_FLAGS) -l $(LISTING_DIR)/$*.lst $< -o $(OBJECTS_DIR)/$*.o

clean:
	@rm -rf $(LISTING_DIR) $(OBJECTS_DIR) $(BUILD_DIR)
