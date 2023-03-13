  ORG &1100
  GUARD &2000


;Adapted for flashing the Master SD device by Darren Coles
;any use of this program is strictly at the users own risk.

;this program will flash a specific rom bank for the Master SD device
;it expects the cart in the rear slot (you can change the code below
;if you use the front slot.

;you can flash multiple images onto the 128k flashrom in the device and switch between them
;the device cannot take a whole 16k rom though as 2.5k of ram is mapped in from b600-bfff
;which is used as workspace by mmfs

;the program is built using information that has been reverse engineered
;from the Master SD device and there is no offical flash program for this
;device currently available. You may brick your device if you use this code.

;run this in mode 7 otherwise the screen may corrupt your rom image.

;load your rom image at address 2000 (*L. image 2000) before calling the
;flash program. If you do not do this you will most likely trash your device


;this program is adapted from code for the electron.
;the code is based on these two repositories.

;https://github.com/fordp2002/MaxRAM/blob/master/Driver/program.asm
;https://github.com/google/myelin-acorn-electron-hardware/blob/main/32kb_flash_cartridge/programmer/tester.asm

; some notes below ;are not applicable in this case but are included for completeness.
;
; SST39SF010 flash programmer
; by Phillip Pearson

; Copyright 2017 Google Inc
; Licensed under the GPL; see LICENSE.txt for details.


; You'll need ca65 and ld65 (from cc65) to assemble and link this.

; In MODE 6, the screen starts at &6000.  If we want to stage a
; 16 kB ROM image for programming, we can load it in at &2000.
; If we build this flasher code to run at &1100, we have &F00
; (3840) bytes to play with.  Right now this clocks in at under
; 1k, so there's plenty of room to move!

; On an Electron with a Plus 1 but no other interesting interfaces,
; the easiest way I've found to get data in for flashing is to use
; a 3.5mm to Bang & Olufsen cable to connect a laptop to the
; cassette port, and use UEFtrans.py and uef2wave.py to convert the
; file into a UEF and then a WAV.  First load the file with:

; On the Electron: *LOAD image 2000
; On the laptop: python file_to_wav.py image.rom image 2000

; Then build and run this file.  Edit erase_cart_first and
; rom_to_program (further down) for configuration.

; On the Electron: *RUN
; On the laptop: make

; It should select bank 0 or 1 and flash from &8000-&BFFF.  No
; verification is performed yet.

acccon%=&fe34


; Zero page addresses (stolen from Econet) for indirect accesses
zp_lo = &90
zp_hi = &91

; OS call to write a character to the screen
OSWRCH = &FFEE

GSREAD=&FFC5

.codestart

; --- program entry point ---
.entry_point
	JMP main

; --- 'puts' macro ---
.puts_pos EQUB &00 ; string position
MACRO	puts	addr
	lda #0
	sta puts_pos
.write_byte
	ldx puts_pos
	lda addr, x
	cmp #0
	beq done
	jsr OSWRCH
	inc puts_pos
	jmp write_byte
.done
ENDMACRO

; --- strings ---

.probing_cart0_msg
	EQUS "Probing cart "
	EQUB &00

.programming_bank_msg
	EQUS "Programming bank "
	EQUB &00
.all_done_msg
	EQUS "All done!"
	EQUB &0D
	EQUB &0A
	EQUB &00
.programming_msg
	EQUS "Programming..."
	EQUB &0D
	EQUB &0A
	EQUB &00
.flash_success_msg
	EQUS "Flash was completed!"
	EQUB &0D
	EQUB &0A
	EQUB &00
.flash_fail_msg
	EQUS "Flash failed!"
	EQUB &0D
	EQUB &0A
	EQUB &00
.waiting_msg
	EQUS "Waiting..."
	EQUB &0D
	EQUB &0A
	EQUB &00
.erasing_msg
	EQUS "Erasing..."
	EQUB &0D
	EQUB &0A
	EQUB &00
.erase_complete_msg
	EQUS "Erasing completed.."
	EQUB &0D
	EQUB &0A
	EQUB &00
.done_msg
	EQUS "Done."
	EQUB &0D
	EQUB &0A
	EQUB &00
.invalid_msg
	EQUS "Invalid rom.. Use *FLASH2 <rom>"
	EQUB &0D
	EQUB &0A
	EQUB &00
.crlf
	EQUB &0D
	EQUB &0A
	EQUB &00

; --- main (called from .entry_point) ---
.previous_rom EQUB &00
.rom_to_program EQUB &ff ;bank 00 or 02 (front or back cart)

.invalid
	puts invalid_msg
	lda previous_rom
	jsr select_rom
  RTS

.main
	; stash initial ROM ID
	lda &f4
	sta previous_rom

  JSR GSREAD_A
  BCS invalid
  
  CMP #97
  BCS hexa
  
  CMP #65
  BCS hexa2

  CMP #58
  BCS invalid
  
  CMP #48
  BCC invalid

  SEC
  SBC #48
  JMP go

.hexa
  CMP #103
  BCS invalid

  SEC
  SBC #87
  JMP go

.hexa2
  CMP #71
  BCS invalid

  SEC
  SBC #55

.go
  STA rom_to_program
  JSR setIFJ
  
	; probe cartridge 0
	puts probing_cart0_msg

  LDA rom_to_program
  JSR write_hex_byte
	puts crlf

	JSR identify_flash_chip

  LDY #&80
  LDX #&00
	jsr erase_sector

  LDY #&90
  LDX #&00
	jsr erase_sector

  LDY #&A0
  LDX #&00
	jsr erase_sector

  LDY #&B0
  LDX #&00
	jsr erase_sector
	puts erase_complete_msg
  
	puts programming_bank_msg
	lda rom_to_program
	jsr write_hex_byte
	puts crlf

	jsr program_16k_rom

	lda rom_to_program
	jsr select_rom
	jsr flash_check

.back_to_basic
  JSR restoreIFJ
	puts all_done_msg
	lda previous_rom
	jsr select_rom
	RTS

.GSREAD_A
{
	JSR GSREAD			; GSREAD ctrl chars cause error
	PHP 				; C set if end of string reached
	AND #&7F
	CMP #&0D			; Return?
	BEQ dogsrd_exit
	CMP #&20			; Control character? (I.e. <&20)
	BCC errBadName
	CMP #&7F			; Backspace?
	BEQ errBadName
.dogsrd_exit
	PLP
	RTS
.errBadName
  PLP
  SEC
  RTS
}

.tempIFJ EQUB 0
.setIFJ
    PHA
    LDA        acccon%
    STA        .tempIFJ
    ORA        #&20
    STA        acccon%
    PLA
    RTS

.restoreIFJ
    PHA
    LDA        .tempIFJ
    STA        acccon%
    PLA
    RTS


; A = number to write (0-15)
.write_hex_char
	CMP #10
	BCC less_than_ten
	CLC
	ADC #55 ; add 'A' - 10
	JMP print_it
.less_than_ten
	CLC
	ADC #48 ; add '0'
.print_it
	jsr OSWRCH
	RTS

; A = byte to write
.write_hex_byte
	PHA ; stash a copy of the char
	AND #&F0
	LSR A
	LSR A
	LSR A
	LSR A
	JSR write_hex_char ; write high nybble
	PLA ; get the char back in A
	AND #&0F
	JSR write_hex_char ; write low nybble
	RTS

; X, Y = address to write
; roughly: printf("%02x%02x\r\n", y, x)
.write_hex_address
	; stash x and y for later
	txa
	pha
	tya
	pha
	; and stash x (low byte) again
	txa
	pha
	; now write y (high byte)
	tya
	jsr write_hex_byte
	; and x
	pla
	jsr write_hex_byte
	puts crlf
	; and get x and y back
	pla
	tay
	pla
	tax
	rts

; put the cartridge in the 0/1 slot
; A = rom ID to select (0-3)
.select_rom
	STA &F4
	STA &FE30
	RTS

; we need to be able to write to addresses 2AAA and 5555 (A14-A0; don't care about A15+)
; A16 = ROMQA (bank ID)
; A15 = 0
; A14 = A12
; A13-A0 map into &8000-&BFFF
; so we select the low bank (rom_id), then:
; 2AAA = 010 1010 1010 1010, i.e. A13:0 = 2AAA, + 8000 = AAAA
; 5555 = 101 0101 0101 0101, i.e. A13:0 = 1555, + 8000 = 9555

; flash chip identification
; A = base rom ID to select (0 or 2)
.chip_id EQUB &00
.identify_flash_chip

  LDA rom_to_program
  AND #&FE
	JSR select_rom

	; * enter flash ID mode

  LDA rom_to_program
  ORA #1
	JSR select_rom

	LDA #&AA
	; write AA to 5555
	STA &9555
  NOP

  LDA rom_to_program
  AND #&FE
	JSR select_rom

  LDA #&55
	; write 55 to 2AAA
	STA &AAAA
  NOP

  LDA rom_to_program
  ORA #1
	JSR select_rom

	; write 90 to 5555
	LDA #&90
	STA &9555
  NOP

  LDA rom_to_program
  AND #&FE
	JSR select_rom

	; * read chip identifying info

	; read 0000, should be &BF
	; read 0001, should be &B5 (or B6 for 39SF020A, B7 for 39SF040)

	LDA &8000
	JSR write_hex_byte
	LDA &8001
	JSR write_hex_byte
	puts crlf

	; * exit flash ID mode

  LDA rom_to_program
  ORA #1
	JSR select_rom

	LDA #&AA
	; write AA to 5555
	STA &9555
  NOP

  LDA rom_to_program
  AND #&FE
	JSR select_rom

	; write 55 to 2AAA
  LDA #&55
	STA &AAAA
  NOP

  LDA rom_to_program
  ORA #1
	JSR select_rom

	; write F0 to 5555
	LDA #&F0
	STA &9555
  NOP

	RTS

.flash_check

	; counter
	lda #0
	sta zp_lo
	lda #&80
	sta zp_hi

.flash_check__loop
	ldy #0
	lda (zp_lo), y

  tax
  lda zp_hi
  sec
  sbc #&60
  sta zp_hi
  txa
	eor (zp_lo), y
  tax
  lda zp_hi
  clc
  adc #&60
  sta zp_hi
  txa
  cmp #0
	bne flash_check_error ; not matching

	; increment zp_lo, zp_hi
	clc
	lda zp_lo
	adc #1
	sta zp_lo
	lda zp_hi
	adc #0
	sta zp_hi

	; are we at the end of the rom space?
	cmp #&c0
	bne flash_check__loop

	puts flash_success_msg ; if we get here, all complete

	RTS

.flash_check_error
	ldx #0
	ldy zp_hi
	JSR  dump_page
  puts flash_fail_msg
  RTS

; --- programming ---
; A = byte to write
; X, Y = low/high bytes of address to write to (in 8000-BFFF)
; this assumes the correct bank is already selected and the sector is erased
.program_byte
	STX zp_lo ; write X,Y,A to zp_lo
	STY zp_hi
	STA &03

  LDA rom_to_program
  ORA #1
	JSR select_rom
  
	; * write four command bytes
	; write AA to 5555
	LDA #&AA
	STA &9555

  LDA rom_to_program
  AND #&FE
	JSR select_rom

	; write 55 to 2AAA
	LDA #&55
	STA &AAAA

  LDA rom_to_program
  ORA #1
	JSR select_rom
  
	; write A0 to 5555
	LDA #&A0
	STA &9555

  LDA rom_to_program
	JSR select_rom
  
  NOP
  NOP

	; * write data to address
	LDA &03
	LDX #0
	STA (zp_lo, X)

	; * poll toggle bit until the program operation is complete
	JSR wait_until_operation_done

	RTS

; --- program 16kB rom from &2000 into bank 0 ---
; this assumes the correct bank is already selected
; and the data to program is from &2000-&6000
; (you probably want to be in MODE 6)

; source (&2000)
.src_hi EQUB &00
.src_lo EQUB &00
; dest (&8000)
.dest_hi EQUB &00
.dest_lo EQUB &00
; counter (&0000 - &4000)
.pos_hi EQUB &00
.pos_lo EQUB &00
; dest + counter
.op_hi EQUB &00
.op_lo EQUB &00
.program_16k_rom

	; start by trying to program from 2000-20ff -> 8000-80ff
	puts programming_msg

	; store src and dest addresses
	lda #&20
	sta src_hi
	clc
	adc #&60 ; 0x6000 = 0x8000 - 0x2000
	sta dest_hi

	lda #&00
	sta src_lo
	sta dest_lo

	; reset offset
	lda #&00
	sta pos_hi
	sta pos_lo

	; now loop and program 00 into every byte, to test
.program_16k_rom__loop
	; work out our destination address
	clc
	lda dest_lo
	adc pos_lo
	sta op_lo
	lda dest_hi
	adc pos_hi
	sta op_hi

	; write destination address if op_lo==0
	lda op_lo
	cmp #0
	bne program_16k_rom__done_writing_addr

	ldx op_lo
	ldy op_hi
	jsr write_hex_address

.program_16k_rom__done_writing_addr
	; get byte from memory
	clc
	lda pos_lo
	adc src_lo
	sta zp_lo
	lda pos_hi
	adc src_hi
	sta zp_hi
	; debug
	;ldx zp_lo
	;ldy zp_hi
	;jsr write_hex_address
	; /debug
	ldy #0
	lda (zp_lo), y
	; make byte programming call
	ldx op_lo
	ldy op_hi
	jsr program_byte

	; increment position
	clc
	lda pos_lo
	adc #1
	sta pos_lo
	bcc program_16k_rom__loop ; inside a 256 byte block

	; dump the page we just wrote
	clc
	lda pos_lo ; should be 0
	adc dest_lo ; should be 0
	tax
	lda pos_hi
	adc dest_hi
	tay
	;jsr dump_page

	; see if we're done otherwise go back and program another page
	clc
	lda pos_hi
	adc #1
	sta pos_hi
	cmp #&40 ; are we done programming &4000 bytes?
	bne program_16k_rom__loop

	puts done_msg
	RTS

; --- 4kB sector erase ---
; X, Y = low, high address of a byte in the sector to erase
; this assumes the correct bank is already selected
.erase_sector
	STX zp_lo ; write X,Y to zp_lo
	STY zp_hi

  LDA rom_to_program
  ORA #1
	JSR select_rom

	; * six byte command load sequence
	; write AA to 5555
	LDA #&AA
	STA &9555

  LDA rom_to_program
  AND #&FE
	JSR select_rom

	; write 55 to 2AAA
	LDA #&55
	STA &AAAA

  LDA rom_to_program
  ORA #1
	JSR select_rom


	; write 80 to 5555
	LDA #&80
	STA &9555

	; write AA to 5555
	LDA #&AA
	STA &9555

	; write 55 to 2AAA

  LDA rom_to_program
  AND #&FE
	JSR select_rom

	LDA #&55
	STA &AAAA
	; write 30 to SAx (uses Ams-A12 lines!!)

  LDA rom_to_program
	JSR select_rom
  
	LDA #&30
	LDX #0
	STA (zp_lo, X)

 LDY #100
.delay2
  LDX #0
.delay  
  DEX
  BNE delay
  DEY
  BNE delay2

	; * poll toggle bit until the sector erase is complete
	JSR wait_until_operation_done

	RTS

; --- dump data from a page on the rom ---
; address in X, Y (low in X, high in Y)
.dump_page
	STX zp_lo ; page lo = zp_lo
	STY zp_hi ; page hi = zp_hi

	JSR write_hex_address

	LDA #0 ; loop counter (0-FF)
.dump_page__next
	PHA
	TAY
	LDA (zp_lo), Y
	JSR write_hex_byte
	LDA #32
	JSR OSWRCH
	PLA
	CMP #&FF
	BEQ dump_page__done
	CLC
	ADC #1
	JMP dump_page__next

.dump_page__done
	puts crlf
	RTS

; --- data# / toggle bit detection ---
.wait_until_operation_done
	; keep reading DQ6 until it stops toggling
	LDA &8000
	EOR &8000
	AND #&40
	BNE wait_until_operation_done

	RTS
.codeend
  SAVE "flash2",codestart,codeend
