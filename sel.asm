  ORG &1100

;this program will switch the rom bank for the Master SD device
;it expects the cart in the rear slot (you can change the code below
;if you use the front slot.

;you can flash multiple images onto the 128k flashrom in the device and switch between them
;the device cannot take a whole 16k rom though as 2.5k of ram is mapped in from b600-bfff
;which is used as workspace by mmfs

acccon%=&fe34

; OS call to write a character to the screen
OSWRCH = &FFEE

GSREAD=&FFC5

.codestart
; --- 'puts' macro ---
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


.main

  JSR setIFJ

  LDA #0    ;change this to 2 if you put the cartridge in the front slot
	jsr select_rom

  JSR GSREAD_A
  BCS invalid
  CMP #56
  BCS invalid
  CMP #48-1
  BCC invalid

  SBC #48
  STA &fc23

  JSR restoreIFJ

	lda previous_rom
	jsr select_rom

	puts all_done_msg
	RTS
.invalid
  JSR restoreIFJ

	lda previous_rom
	jsr select_rom

	puts invalid_msg
  RTS

.puts_pos EQUB &00 ; string position

.previous_rom EQUB 0
.select_rom
	STA &F4
	STA &FE30
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

.all_done_msg
	EQUS "All done!"
	EQUB &0D
	EQUB &0A
	EQUB &00

.invalid_msg
	EQUS "Invalid bank.. Use *SEL <bank>"
	EQUB &0D
	EQUB &0A
	EQUB &00

.codeend
  SAVE "sel",codestart,codeend
