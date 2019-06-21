CC = gcc -g
CFLAGS = -m32

ASM = nasm -g
AFLAGS = -f elf32

all: main

main.o: main.c
	$(CC) $(CFLAGS) -c main.c

code.o: code.asm
	$(ASM) $(AFLAGS) code.asm

decode.o: decode.asm
	$(ASM) $(AFLAGS) decode.asm

main: main.o code.o decode.o
	$(CC) $(CFLAGS) main.o code.o decode.o -o main

clean:
	rm *.o
	rm main
