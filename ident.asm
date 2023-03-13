  ORG &1100
;display manufacturer and device id from the flash chip in MasterSD device
;it expects the cart in the rear slot (you can change the code below
;if you use the front slot.

;should display BFB5 which indicates a SST39SF010A 1mbit (128k*8 flash chip)


acccon%=&fe34

; OS call to write a character to the screen
OSWRCH = &FFEE

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

.all_done_msg
	EQUS "All done!"
	EQUB &0D
	EQUB &0A
	EQUB &00
.crlf
	EQUB &0D
	EQUB &0A
	EQUB &00

; --- main (called from .entry_point) ---
.previous_rom EQUB &00
.rom_to_probe EQUB &ff ;bank 00 or 02 (front or back cart)

.main
	; stash initial ROM ID
	lda &f4
	sta previous_rom
  
  LDA #0        ;change this to 2 if you put the cartridge in the front slot
  STA rom_to_probe
  
  JSR setIFJ

	; probe cartridge 0
	puts probing_cart0_msg

  LDA rom_to_probe
  JSR write_hex_byte
	puts crlf

  LDA rom_to_probe
	JSR identify_flash_chip1

.back_to_basic
  LDA #0
  STA &fc23
  JSR restoreIFJ
	puts all_done_msg
	lda previous_rom
	jsr select_rom
	RTS

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
.identify_flash_chip1

	JSR select_rom

	; * enter flash ID mode

  LDA #&55
  TAX
	LDA #&90
  TAY

  LDA #1
  STA &fc23

	LDA #&AA
	; write AA to 5555
	STA &9555
  NOP

  LDA #0
  STA &fc23

	; write 55 to 2AAA
	STX &AAAA
  NOP

  LDA #1
  STA &fc23

	; write 90 to 5555
	STY &9555
  NOP

  LDA #0
  STA &fc23

	; * read chip identifying info

	; read 0000, should be &BF
	; read 0001, should be &B5 (or B6 for 39SF020A, B7 for 39SF040)

	LDA &8000
	JSR write_hex_byte
	LDA &8001
	JSR write_hex_byte
	puts crlf

	; * exit flash ID mode

  LDA #&55
  TAX
	LDA #&F0
  TAY

  LDA #1
  STA &fc23

	LDA #&AA
	; write AA to 5555
	STA &9555
  NOP

  LDA #0
  STA &fc23

	; write 55 to 2AAA
	STX &AAAA
  NOP

  LDA #1
  STA &fc23

	; write F0 to 5555
	STY &9555
  NOP

  LDA #0
  STA &fc23
	RTS
.codeend
  SAVE "ident",codestart,codeend
