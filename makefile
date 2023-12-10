DC := ldc2
BIN := main
SRCS := $(wildcard *.d)
DFLAGS += -betterC -O3 -release -mcpu=native
DFLAGS += --linker=lld -flto=full

BUILD := build
OBJS := $(SRCS:%.d=%.o)
BIN_OUT := $(addprefix $(BUILD)/, $(BIN))
OBJS_OUT := $(addprefix $(BUILD)/, $(OBJS))

export CC := /usr/bin/clang

.PHONY: run
run: clean buildir $(BIN_OUT)
	./$(BIN_OUT)

$(BIN_OUT): $(OBJS_OUT)
	$(DC) $^ $(DFLAGS) -of=$@

$(OBJS_OUT): $(BUILD)/%.o: %.d
	$(DC) -c $< $(DFLAGS) -of=$@

.PHONY: clean
clean:
	rm -rf $(BUILD)

.PHONY: buildir
buildir:
	mkdir -p $(BUILD)
