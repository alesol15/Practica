# Variables
CC := $(CROSS_COMPILE)gcc
CFLAGS := -Wall -Werror -g
TARGET := writer
SRC := writer.c
OBJ := $(SRC:.c=.o)

all: $(TARGET)

# Compile writer
$(TARGET): $(OBJ)
	$(CC) $(CFLAGS) -o $@ $^

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

# Clean files
clean:
	rm -f $(TARGET) *.o

.PHONY: all clean

