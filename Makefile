# ---------------------------------------------------------------------------------------- #

ASSEMBLER         = nasm
ASM_FLAGS         = -f elf64

COMPILER		  = gcc
COMPILER_FLAGS	  = -c

LINKER            = gcc
LD_FLAGS          = -no-pie -z noexecstack

# ---------------------------------------------------------------------------------------- #

SOURCES_DIR       = src
OBJECTS_DIR       = obj
LISTING_DIR       = lst
BUILD_DIR         = bin

EXECUTABLE        = printf
EXECUTABLE_PATH   = $(BUILD_DIR)/$(EXECUTABLE)

# ---------------------------------------------------------------------------------------- #

CPP_SOURCE_FILES  = $(wildcard $(SOURCES_DIR)/*.cpp)
ASM_SOURCE_FILES  = $(wildcard $(SOURCES_DIR)/*.asm)

CPP_OBJECT_FILES  = $(patsubst $(SOURCES_DIR)/%.cpp, $(OBJECTS_DIR)/%.o, $(CPP_SOURCE_FILES))
ASM_OBJECT_FILES  = $(patsubst $(SOURCES_DIR)/%.asm, $(OBJECTS_DIR)/%.o, $(ASM_SOURCE_FILES))

ASM_LISTING_FILES = $(patsubst $(SOURCES_DIR)/%.asm, $(LISTING_DIR)/%.lst, $(ASM_SOURCE_FILES))

OBJECT_FILES      = $(CPP_OBJECT_FILES) $(ASM_OBJECT_FILES)

# ---------------------------------------------------------------------------------------- #

all: $(EXECUTABLE_PATH)

$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

$(OBJECTS_DIR):
	@mkdir -p $(OBJECTS_DIR)

$(LISTING_DIR):
	@mkdir -p $(LISTING_DIR)

$(EXECUTABLE_PATH): $(OBJECT_FILES) | $(BUILD_DIR)
	@$(LINKER) $(LD_FLAGS) $(OBJECT_FILES) -o $@

$(OBJECTS_DIR)/%.o: $(SOURCES_DIR)/%.cpp | $(OBJECTS_DIR)
	@$(COMPILER) $(COMPILER_FLAGS) $< -o $@

$(OBJECTS_DIR)/%.o: $(SOURCES_DIR)/%.asm | $(OBJECTS_DIR) $(LISTING_DIR)
	@$(ASSEMBLER) $(ASM_FLAGS) -l $(LISTING_DIR)/$*.lst $< -o $@

# ---------------------------------------------------------------------------------------- #

clean:
	@rm -rf $(LISTING_DIR) $(OBJECTS_DIR) $(BUILD_DIR)

# ---------------------------------------------------------------------------------------- #
