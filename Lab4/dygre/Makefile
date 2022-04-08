# Toolchain settings
TARGET  := 
CC      := $(TARGET)gcc
CXX     := $(TARGET)g++
AS      := $(TARGET)as
LD      := $(TARGET)gcc
GDB     := $(TARGET)gdb

BUILD   ?= debug

# User Settings
BINNAME     = dygre
AINCDIR     =
INCDIR      = 
LIBS        =
FLAGS       =
CFLAGS      = -std=c11 -Wall $(shell pkg-config --cflags libnl-route-3.0) $(shell pkg-config --cflags libpcap)
CXXFLAGS    = -std=c++17 -Wall
LDFLAGS     = $(shell pkg-config --libs libnl-route-3.0) $(shell pkg-config --libs libpcap)
DEFFLAGS    =
DBGFLAGS    = -g -DDEBUG
LDSCRIPT    =

# Compile Flags
ZFLAGS      = 
ZASFLAGS    = $(foreach d, $(AINCDIR), -I$d)
ZCFLAGS     = $(OPTIFLAGS) $(DEFFLAGS) $(foreach d, $(INCDIR), -I$d) $(CFLAGS)
ZCXXFLAGS   = $(OPTIFLAGS) $(DEFFLAGS) $(foreach d, $(INCDIR), -I$d) $(CXXFLAGS)
ZLDFLAGS    = $(LDFLAGS)

OPTIFLAGS   = 
ifeq ($(BUILD),debug)
	OBJDIR = obj/Debug
	DEPDIR = dep/Debug
	ZFLAGS += $(DBGFLAGS)
	OPTIFLAGS = -O0
else ifeq ($(BUILD),release)
	OBJDIR = obj/Release
	DEPDIR = dep/Release
	OPTIFLAGS = -O2
	ZFLAGS += -DNDEBUG
else
	OBJDIR = $(error "Unknown build type")
endif

ifneq ($(LDSCRIPT),)
	ZLDFLAGS += -T $(LDSCRIPT)
endif

SRCS.s      = $(wildcard *.s)
SRCS.c      = $(wildcard *.c)
SRCS.cpp    = $(wildcard *.cpp)
OBJFILES    = $(SRCS.c:.c=.o) $(SRCS.cpp:.cpp=.o) $(SRCS.s:.s=.o)
OBJS        = $(addprefix $(OBJDIR)/,$(OBJFILES))
DEPFILES    = $(SRCS.c:.c=.d) $(SRCS.cpp:.cpp=.d)
DEPS        = $(addprefix $(DEPDIR)/,$(DEPFILES))

.PHONY: clean distclean gdb

all: $(BINNAME)

$(OBJDIR):
	mkdir -p $(OBJDIR)

$(DEPDIR):
	mkdir -p $(DEPDIR)

$(OBJDIR)/%.o: %.s | $(OBJDIR)
	$(AS) $(FLAGS) $(ZASFLAGS) -o $@ $<

$(OBJDIR)/%.o: %.c | $(OBJDIR)
	$(CC) $(FLAGS) $(ZFLAGS) $(ZCFLAGS) -c -o $@ $<

$(OBJDIR)/%.o: %.cpp | $(OBJDIR)
	$(CXX) $(FLAGS) $(ZFLAGS) $(ZCXXFLAGS) -c -o $@ $<

$(DEPDIR)/%.d: %.c | $(DEPDIR)
	@echo -n "$(OBJDIR)/" > $@
	@$(CC) -MM -MP $(FLAGS) $(ZCFLAGS) $< >> $@

$(DEPDIR)/%.d: %.cpp | $(DEPDIR)
	@echo -n "$(OBJDIR)/" > $@
	@$(CXX) -MM -MP $(FLAGS) $(ZCXXFLAGS) $< >> $@

$(BINNAME): $(OBJS)
	$(LD) $(FLAGS) -o $@ $(OBJS) $(ZLDFLAGS) $(foreach l, $(LIBS), -l$l)

ifneq ($(DEPS),)
  sinclude $(DEPS)
endif

gdb: $(BINNAME)
	$(GDB) -se $(BINNAME)

clean:
	rm -rf obj
	rm -f *.o $(BINNAME)

distclean: clean
	rm -rf dep
	rm -f *.d

