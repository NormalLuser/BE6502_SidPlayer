;
;	NormalLuser edit of the Monty on the Run .SID   
;	For the Ben Eater 6502 Breadboard project with a SID chip
;
;	.SID start:
;
;	.to "Hubbard_Rob_Monty_on_the_Run.sid",plain
;	;* = $0000
; 	.text "PSID"
; 	.byte $00,$02		; version 2
; 	.byte $00,$7c		; data offset
; 	.byte $00,$00		; Load (auto)
; 	.byte >init,<init	; Init
; 	.byte >play,<play	; Play
; 	.byte $00,$01		; num. songs
; 	.byte $00,$01		; first song
; 	.word 0
; 	.word 0
; _t	.text "Monty on the Run"
; 	.fill 32 - (* - _t)
; _a	.text "Rob Hubbard"
; 	.fill 32 - (* - _a)
; _c	.text "1985 Gremlin Graphics"
; 	.fill 32 - (* - _c)
; 	.word $0000			; v2 flags
; 	.word $0000			; Start page, page length (reloc)
; 	.word $0000			; Reserved
	
; 	; auto load address
; 	.word pseudopc ;$8000

;pseudopc: ;$8000 {

;	-------------------------------------------------------
;	Rob Hubbard Music Driver
;	-------------------------------------------------------
;	Original disassembly and commenting by Anthony McSweeney
;	Port to ACME by dmx87
;	-------------------------------------------------------
;	This player was used (with small modifications) for his
;	first approx. 30 tunes
;	-------------------------------------------------------


  
VIA_BASE = $6000    ; Base address of the 6522 VIA
; VIA Register Offsets:
IFR      = VIA_BASE + $D   ; Interrupt Flag Register
IER      = VIA_BASE + $E   ; Interrupt Enable Register
ACR      = VIA_BASE + $B   ; Auxiliary Control Register
T1C_L    = VIA_BASE + $4   ; Timer 1 Counter Low
T1C_H    = VIA_BASE + $5   ; Timer 1 Counter High
T1L_L    = VIA_BASE + $4   ; Timer 1 Latch Low (same as T1C_L)
T1L_H    = VIA_BASE + $5   ; Timer 1 Latch High (same as T1C_H)


 .org $400
; NormalLuser
; Need to setup a 60Hz VIA timer with interrupt 
; We don't care what the IRQ code in the ROM does.
; With the VGA project connected and the Vsync connected to the CPU NMI
; It is not needed and no other code needs to be changed.
; This is because we will use a WDC 65C02 WAI instruction. 
; It allows the CPU to wait for a interrupt from any source and then continue.
; Easy!

; Oh nooo... Needs to be a _50Hz_ Timer, not 60Hz!!!!!
; Whoops!!
;
; Assumes 1Mhz system clock.
; Setup60HzTimer:		    ; 1Mhz system clock needs VIA T1 at ~8331
;     SEI                 ; Disable interrupt
;     LDA #$C0            ; Enable VIA T1 interrupt 
;     STA IER             ; 
;     LDA #$40            ; Set ACR for T1 
;     STA ACR             ; 
;     LDA #$1A            ; Low byte for 8331
;     STA T1L_L           ; 
;     LDA #$41            ; High byte for 8331
;     STA T1L_H           ; Timer start
;     CLI                 ; Turn on interrupt
; Assumes 1Mhz system clock.
Setup50HzTimer:		    ; 1Mhz system clock needs VIA T1 at ~8331
    SEI                 ; Disable interrupt
    LDA #$C0            ; Enable VIA T1 interrupt 
    STA IER             ; 
    LDA #$40            ; Set ACR for T1 
    STA ACR             ; 
    LDA #$7F            ; Low byte 
    STA T1L_L           ; 
    LDA #$4E            ; High byte
    STA T1L_H           ; Timer start
    CLI                 ; Turn on interrupt



init	
	;JMP initmusic
	JSR initmusic
play
	;jmp playmusic
	JSR playmusic
    ; WAI below waits for either the VIA to trigger an IRQ, or for a Vsync NMI from VGA project. 
    ; Kowalski simulator does not allow WAI on 65c02. Comment out to test. 
	WAI ;Is it time for another set of notes?
	JMP play
	
	

;	-------------------------------------------------------
;	Init
;	-------------------------------------------------------

initmusic
	lda #0				; song number (this only got one)
	ldy #0
	asl
	sta tempstore
	asl
	clc
	adc tempstore		; a = song num * 6
	tax

_1	lda songs,x
	sta currtrkhi,y		; set track pointers
	inx
	iny
	cpy #$06
	bne _1

	lda #$00			; SID reset	
	sta $4804
	sta $480b
	sta $4812
	sta $4817

	lda #$0f			; max volume
	sta $4818

	lda #$40			; bit 6 = init music
	sta mstatus

	rts


;====================================
;music off

musicoff
	lda #$c0         	; music off
	sta mstatus
	rts

;	-------------------------------------------------------
;	Play
;	-------------------------------------------------------

playmusic
	inc counter
	
	bit mstatus      	; get status
	bmi _off			; neg? then music is off (bit 7, 8)
	bvc contplay		; bit 6 clear? play

	lda #$00			; init song
	sta counter
	
	ldx #2
SetPatternPointers:
 	sta posoffset,x		; set pattern pointers
	sta patoffset,x
	sta lengthleft,x	; clear length
	sta notenum,x		; clear note
	dex
	bpl SetPatternPointers
	
	sta mstatus			; status = 0 (play)
	jmp contplay


;==========
;music is off (mstatus $80 or $c0)

_off
	bvc BitSixClearExit	; bit 6 clear? exit
	
	lda #$00			; clear control regs
	sta $4804
	sta $480b
	sta $4812
	
	lda #$0f			; max volume
	sta $4818
	
	lda #$80			; next time, go to end
	sta mstatus
BitSixClearExit:	
 	jmp musicend


;==========
;music is playing (mstatus otherwise)

;	-------------------------------------------------------
;	Continue to play music
;	-------------------------------------------------------

contplay
	ldx #2				; voice
	
	dec speed
	bpl mainloop
	
	lda resetspd		; reset speed counter
	sta speed

mainloop
	lda regoffsets,x
	sta tmpregofst
	tay					; y = sid reg offset

; check whether a new note is needed

	lda speed
	cmp resetspd
	beq checknewnote	; speed was reset; get notedata
	jmp vibrato			; keep 

checknewnote

	lda currtrkhi,x
	sta $02
	lda currtrklo,x
	sta $03				; ($02) = current track ptr

	dec lengthleft,x	; previous note done?
	bmi getnewnote		; yes, get new

	jmp soundwork		; keep sounding


;==========
;notework
;a new note is needed. get the pattern number/cc from this position

getnewnote
	ldy posoffset,x		; y = pattern position
	lda ($02),y			; a = note data
	
	cmp #$ff			; a == $ff ? restart
	beq restart
	
	cmp #$fe			; a == $fe ? stop
	bne getnotedata
	
	jmp musicend

;cc of $ff restarts this track from the first position

restart
	lda #0		        ; reset position
	sta lengthleft,x
	sta posoffset,x
	sta patoffset,x
	jmp getnewnote		; and get new note

;	-------------------------------------------------------
;	getnotedata
;	-------------------------------------------------------
;	Get note data from current pattern + pos
;	Byte 1: Length of note (bits 0-4)
;	        No release (bit 5)
;	        Retrig off (bit 6)
;	        New instr/porta coming (bit 7)
;	Byte 2: Instr. number or porta speed
;	        if bit 7 on byte 1 set, else 0
;	Byte 3: Note number
;	-------------------------------------------------------

getnotedata
	tay
	lda patptl,y
	sta $04
	lda patpth,y
	sta $05				; ($04) = pattern ptr
	
	lda #0				; porta disable as default
	sta portaval,x
	
	ldy patoffset,x		; y = pattern position
	
	lda #$ff			; retrig on as default
	sta appendfl

	lda ($04),y			; get note duration
	sta savelnthcc,x
	sta templnthcc
	and #$1f			; keep bits 0-4 (value: 0-31)
	sta lengthleft,x

	bit templnthcc		; test for append (bit 6)
	bvs appendnote

	inc patoffset,x		; next column

	lda templnthcc		; 2nd byte needed?
	bpl getpitch

;2nd byte needed as 1st byte negative
;2nd byte is the instrument number(+ve)
;or portamento speed(-ve)

	iny
	lda ($04),y			; a = get instr/portamento
	bpl IsInstrument ;	; is instrument

	sta portaval,x		; is portamento if negative
	jmp NextColumn

IsInstrument:
	sta instrnr,x

NextColumn:
	inc patoffset,x		; next column

; 3rd byte is the pitch of the note get the 'base frequency' here

getpitch
	iny
	lda ($04),y			; a = note
	sta notenum,x
	asl
	tay					; y = note * 2
	
	lda notefreqsl,y
	sta tempfreq
	lda notefreqsh,y
	
	ldy tmpregofst		; y = sid reg offset
	sta $4801,y			; freq hi
	sta savefreqhi,x
	
	lda tempfreq
	sta $4800,y			; freq lo
	sta savefreqlo,x
	jmp getinstrument

appendnote
	dec appendfl     ;clever eh?

;	-------------------------------------------------------
;	getinstrument
;	-------------------------------------------------------
;	Get instrument data
;	-------------------------------------------------------

getinstrument
	ldy tmpregofst		; y = sid voice offset
	lda instrnr,x		; x = instrument
	stx tempstore		; tempstore = instrument no.
	asl
	asl
	asl
	tax					; x = instrument * 8 (aka offset)

	lda instr+2,x		; (2) a = control value
	sta tempctrl
	
	lda instr+2,x
	and appendfl		; if append, disable gate bit
	sta $4804,y			; control reg

	lda instr+0,x		; (0) pulse width lo
	sta $4802,y

	lda instr+1,x		; (1) pulse width hi
	sta $4803,y

	lda instr+3,x		; (3) attack/decay
	sta $4805,y

	lda instr+4,x		; (4) sustain/release
	sta $4806,y

	ldx tempstore	    ; x = instrument no.
	lda tempctrl		; instrument control value
	sta voicectrl,x

	inc patoffset,x		; point to 4th byte
	
	ldy patoffset,x
	lda ($04),y			; a = value

	cmp #$ff			; end of pattern?
	bne JmpLoopcont

	lda #$00			; reset pattern position
	sta patoffset,x
	inc posoffset,x

JmpLoopcont:
	jmp loopcont


;	-------------------------------------------------------
;	soundwork
;	-------------------------------------------------------
;	Update instrument and effects
;	-------------------------------------------------------

soundwork
	ldy tmpregofst		; y = sid voice offset

	lda savelnthcc,x	
	and #$20			; bit 4 set = sustain
	bne vibrato

	lda lengthleft,x	; note done?
	bne vibrato

	lda voicectrl,x
	and #$fe			; start release by disabling gate bit
	sta $4804,y

	lda #$00
	sta $4805,y			; AD = 0
	sta $4806,y			; SR = 0

;	-------------------------------------------------------
;	Vibrato
;	-------------------------------------------------------
;	A clever little trick to create an oscillating value
;	-------------------------------------------------------

vibrato
	lda instrnr,x		; a = instrument no.
	asl
	asl
	asl
	tay					; y = instrument offset
	sty instnumby8
	
	lda instr+7,y		; (7) instrument fx
	sta instrfx
	
	lda instr+6,y		; (6) pulse speed
	sta pulsevalue
	
	lda instr+5,y		; (5) vibrato depth
	sta vibrdepth
	beq pulsework		; no vibrato here
	
	lda counter			; (this is clever..)
	and #7				; counter 0-7
	cmp #4				; from 4+
	bcc NotReversed 
	eor #7				; is reversed

NotReversed:
	sta oscilatval		; for sequence 01233210

	lda notenum,x		; a = note
	asl					; a *= 2
	tay					; y = a
	sec
	lda notefreqsl+2,y
	sbc notefreqsl,y
	sta tmpvdiflo		; diff = (note + 1) - note
	lda notefreqsh+2,y
	sbc notefreqsh,y
DivideDiff:	
	lsr					; divide diff by 2
	ror tmpvdiflo
	dec vibrdepth		; for each depth
	bpl DivideDiff
	
	sta tmpvdifhi
	
	lda notefreqsl,y	; save note frequency
	sta tmpvfrqlo
	lda notefreqsh,y
	sta tmpvfrqhi
	
	lda savelnthcc,x
	and #$1f			; a = note duration
	cmp #8
	bcc StoreAndLoadSID	; less than 8 ? no need for vibrato
	
	ldy oscilatval		; y = oscillator value
DeyOscillatorValue:	
	dey              	;depending on the osc
	bmi StoreAndLoadSID	;value, add the vibr
	clc              	;freq that many times
	lda tmpvfrqlo    	;to the base freq
	adc tmpvdiflo
	sta tmpvfrqlo
	lda tmpvfrqhi
	adc tmpvdifhi
	sta tmpvfrqhi
	jmp DeyOscillatorValue
StoreAndLoadSID:
	ldy tmpregofst		; store and load SID
	lda tmpvfrqlo
	sta $4800,y
	lda tmpvfrqhi
	sta $4801,y


;	-------------------------------------------------------
;	pulse-width
;	-------------------------------------------------------
;	Delay, speed
;	The pulse-speed value is also used in inc/dec depth
;	-------------------------------------------------------

pulsework
	lda pulsevalue		; a = pulse value
	beq portamento		; 0 = disabled
	
	ldy instnumby8		; y = instr offset
	
	and #$1f
	
	dec pulsedelay,x	; delayed?
	bpl portamento		; yes, skip it
	
	sta pulsedelay,x	; reset delay
	
	lda pulsevalue		; restrict pulse speed
	and #$e0         	; to $00, $20, $40, $60 ...
	sta pulsespeed
	
	lda pulsedir,x		; a = pulse direction
	bne pulsedown		; .0 = down
	
	lda pulsespeed		; 0 = up
	clc
	adc instr+0,y		; add speed
	pha					; <- pw hi
	lda instr+1,y
	adc #$00
	and #$0f
	pha					; <- pw lo
	cmp #$0e			; pulse max ?
	bne dumpulse
	inc pulsedir,x		; yes, flip direction
	jmp dumpulse

pulsedown
	sec
	lda instr+0,y
	sbc pulsespeed		; subtract speed
	pha					; <- pw hi
	lda instr+1,y
	sbc #$00
	and #$0f
	pha					; <- pw lo
	cmp #$08			; pulse min?
	bne dumpulse
	dec pulsedir,x		; yes, flip direction

dumpulse
	stx tempstore
	ldx tmpregofst
	pla					; -> pwlo
	sta instr+1,y
	sta $4803,x			; PWHI
	pla					; -> pwhi
	sta instr+0,y
	sta $4802,x			; PWLO
	ldx tempstore

;	-------------------------------------------------------
;	portamento (2nd byte negative)
;	-------------------------------------------------------

portamento
	ldy tmpregofst
	lda portaval,x		; get porta
	beq drums			; 0 = disabled
	
	and #$7e			; cap
	sta tempstore
	
	lda portaval,x		; bit 0 signals up/down
	and #$01
	beq _up
	
	sec					; down
	lda savefreqlo,x ;sub portaval from
	sbc tempstore    ;current frequency
	sta savefreqlo,x
	sta $4800,y
	lda savefreqhi,x
	sbc #$00         ;(word arithmetic)
	sta savefreqhi,x
	sta $4801,y
	jmp drums

_up clc              ;portamento up
	lda savefreqlo,x ;add portval to
	adc tempstore    ;current frequency
	sta savefreqlo,x
	sta $4800,y
	lda savefreqhi,x
	adc #$00
	sta savefreqhi,x
	sta $4801,y

;	-------------------------------------------------------
;	drums (bit 0 of instrfx)
;	-------------------------------------------------------
;	Drum timbre depends on ctrl register value for instrument
;	If ctrl is 0, it's all noise, otherwise ctrl waveform
;	and noise after 1st vblank. Fast attack/decay and a rapid
;	downwards frequency slide creates this sound
;	-------------------------------------------------------

drums
	lda instrfx
	and #$01			; bit 1 = drums
	beq skydive
	
	lda savefreqhi,x
	beq skydive			; freq is already at lowest
	
	lda lengthleft,x
	beq skydive			; note is done
	
	lda savelnthcc,x	; a = note info
	and #$1f			; a = note length (0-31)
	sec
	sbc #$01
	cmp lengthleft,x	; is it the first vblank ?
	ldy tmpregofst
	bcc _first

	lda savefreqhi,x	; not the first hit
	dec savefreqhi,x	; decrease freqhi
	sta $4801,y
	
	lda voicectrl,x		; if ctrlreg is 0 then it's all noise
	and #$fe			; otherwise, ctrl waveform
	bne _nf

_first
	lda savefreqhi,x ;noise is used for
	sta $4801,y      ;the first vbl also
	lda #$80         ;(set noise)

_nf
	sta $4804,y

;	-------------------------------------------------------
;	skydive (bit 1 of instrfx)
;	-------------------------------------------------------
;	The famous Hubbard signature effect
;	A long slide down from note to zero
;	-------------------------------------------------------

skydive
	lda instrfx      ;check if skydive
	and #$02         ;needed this instr
	beq octarp
	
	lda counter      ;every 2nd vbl
	and #$01
	beq octarp
	
	lda savefreqhi,x ;check if skydive
	beq octarp        ;already complete
	
	dec savefreqhi,x ;decr and save the
	ldy tmpregofst   ;high byte freq
	sta $4801,y

;	-------------------------------------------------------
;	arpeggio (bit 2 of instrfx)
;	-------------------------------------------------------
;	Simple octave arpeggio, also a signature sound
;	-------------------------------------------------------

octarp
	lda instrfx
	and #$04			; bit 2 = octave arpeggio
	beq loopcont
	
	lda counter			; 0 or 1
	and #$01
	beq EvenNote
	
	lda notenum,x		; a = note
	clc
	adc #$0c			; note + 12
	jmp OddNote
EvenNote:
	lda notenum,x    ;even, note
OddNote:
	asl
	tay					; load freq
	lda notefreqsl,y
	sta tempfreq
	lda notefreqsh,y
	ldy tmpregofst
	sta $4801,y
	lda tempfreq
	sta $4800,y


;==========
;end of dbf loop

loopcont
	dex					; next channel
	bmi musicend
	jmp mainloop

musicend
  rts
  ;jmp init	;Loop forever

;====================================
;frequenz data
;====================================

notefreqsl
notefreqsh = * + 1
 .word $0116,$0127,$0138,$014b,$015f,$0173,$018a,$01a1,$01ba,$01d4,$01f0,$020e
 .word $022d,$024e,$0271,$0296,$02bd,$02e7,$0313,$0342,$0374,$03a9,$03e0,$041b
 .word $045a,$049b,$04e2,$052c,$057b,$05ce,$0627,$0685,$06e8,$0751,$07c1,$0837
 .word $08b4,$0937,$09c4,$0a57,$0af5,$0b9c,$0c4e,$0d09,$0dd0,$0ea3,$0f82,$106e
 .word $1168,$126e,$1388,$14af,$15eb,$1739,$189c,$1a13,$1ba1,$1d46,$1f04,$20dc
 .word $22d0,$24dc,$2710,$295e,$2bd6,$2e72,$3138,$3426,$3742,$3a8c,$3e08,$41b8
 .word $45a0,$49b8,$4e20,$52bc,$57ac,$5ce4,$6270,$684c,$6e84,$7518,$7c10,$8370
 .word $8b40,$9370,$9c40,$a578,$af58,$b9c8,$c4e0,$d098,$dd08,$ea30,$f820,$fd2e


regoffsets .byte $00,$07,$0e
tmpregofst .byte $00
posoffset  .byte $00,$00,$00
patoffset  .byte $00,$00,$00
lengthleft .byte $00,$00,$00
savelnthcc .byte $00,$00,$00
voicectrl  .byte $00,$00,$00
notenum    .byte $00,$00,$00
instrnr    .byte $00,$00,$00
appendfl   .byte $00
templnthcc .byte $00
tempfreq   .byte $00
tempstore  .byte $00
tempctrl   .byte $00
vibrdepth  .byte $00
pulsevalue .byte $00
tmpvdiflo  .byte $00
tmpvdifhi  .byte $00
tmpvfrqlo  .byte $00
tmpvfrqhi  .byte $00
oscilatval .byte $00
pulsedelay .byte $00,$00,$00
pulsedir   .byte $00,$00,$00
speed      .byte $00
resetspd   .byte $01
instnumby8 .byte $00
mstatus    .byte $c0
savefreqhi .byte $00,$00,$00
savefreqlo .byte $00,$00,$00
portaval   .byte $00,$00,$00
instrfx    .byte $00
pulsespeed .byte $00
counter    .byte $00
currtrkhi  .byte $00,$00,$00
currtrklo  .byte $00,$00,$00


;====================================
;monty on the run main theme
;====================================

songs =*
 .byte <montymaintr1
 .byte <montymaintr2
 .byte <montymaintr3
 .byte >montymaintr1
 .byte >montymaintr2
 .byte >montymaintr3


;====================================
;pointers to the patterns

;low pointers
patptl =*
 .byte <ptn00
 .byte <ptn01
 .byte <ptn02
 .byte <ptn03
 .byte <ptn04
 .byte <ptn05
 .byte <ptn06
 .byte <ptn07
 .byte <ptn08
 .byte <ptn09
 .byte <ptn0a
 .byte <ptn0b
 .byte <ptn0c
 .byte <ptn0d
 .byte <ptn0e
 .byte <ptn0f
 .byte <ptn10
 .byte <ptn11
 .byte <ptn12
 .byte <ptn13
 .byte <ptn14
 .byte <ptn15
 .byte <ptn16
 .byte <ptn17
 .byte <ptn18
 .byte <ptn19
 .byte <ptn1a
 .byte <ptn1b
 .byte <ptn1c
 .byte <ptn1d
 .byte <ptn1e
 .byte <ptn1f
 .byte <ptn20
 .byte <ptn21
 .byte <ptn22
 .byte <ptn23
 .byte <ptn24
 .byte <ptn25
 .byte <ptn26
 .byte <ptn27
 .byte <ptn28
 .byte <ptn29
 .byte <ptn2a
 .byte <ptn2b
 .byte <ptn2c
 .byte <ptn2d
 .byte 0
 .byte <ptn2f
 .byte <ptn30
 .byte <ptn31
 .byte <ptn32
 .byte <ptn33
 .byte <ptn34
 .byte <ptn35
 .byte <ptn36
 .byte <ptn37
 .byte <ptn38
 .byte <ptn39
 .byte <ptn3a
 .byte <ptn3b

;high pointers
patpth =*
 .byte >ptn00
 .byte >ptn01
 .byte >ptn02
 .byte >ptn03
 .byte >ptn04
 .byte >ptn05
 .byte >ptn06
 .byte >ptn07
 .byte >ptn08
 .byte >ptn09
 .byte >ptn0a
 .byte >ptn0b
 .byte >ptn0c
 .byte >ptn0d
 .byte >ptn0e
 .byte >ptn0f
 .byte >ptn10
 .byte >ptn11
 .byte >ptn12
 .byte >ptn13
 .byte >ptn14
 .byte >ptn15
 .byte >ptn16
 .byte >ptn17
 .byte >ptn18
 .byte >ptn19
 .byte >ptn1a
 .byte >ptn1b
 .byte >ptn1c
 .byte >ptn1d
 .byte >ptn1e
 .byte >ptn1f
 .byte >ptn20
 .byte >ptn21
 .byte >ptn22
 .byte >ptn23
 .byte >ptn24
 .byte >ptn25
 .byte >ptn26
 .byte >ptn27
 .byte >ptn28
 .byte >ptn29
 .byte >ptn2a
 .byte >ptn2b
 .byte >ptn2c
 .byte >ptn2d
 .byte 0
 .byte >ptn2f
 .byte >ptn30
 .byte >ptn31
 .byte >ptn32
 .byte >ptn33
 .byte >ptn34
 .byte >ptn35
 .byte >ptn36
 .byte >ptn37
 .byte >ptn38
 .byte >ptn39
 .byte >ptn3a
 .byte >ptn3b


;====================================
;tracks
;====================================

;track1
montymaintr1 =*
 .byte $11,$14,$17,$1a,$00,$27,$00,$28
 .byte $03,$05,$00,$27,$00,$28,$03,$05
 .byte $07,$3a,$14,$17,$00,$27,$00,$28
 .byte $2f,$30,$31,$31,$32,$33,$33,$34
 .byte $34,$34,$34,$34,$34,$34,$34,$35
 .byte $35,$35,$35,$35,$35,$36,$12,$37
 .byte $38,$09,$2a,$09,$2b,$09,$0a,$09
 .byte $2a,$09,$2b,$09,$0a,$0d,$0d,$0f
 .byte $ff

;track2
montymaintr2 =*
 .byte $12,$15,$18,$1b,$2d,$39,$39
 .byte $39,$39,$39,$39,$2c,$39,$39,$39
 .byte $39,$39,$39,$2c,$39,$39,$39,$01
 .byte $01,$29,$29,$2c,$15,$18,$39,$39
 .byte $39,$39,$39,$39,$39,$39,$39,$39
 .byte $39,$39,$39,$39,$39,$39,$39,$39
 .byte $39,$39,$39,$39,$39,$39,$39,$39
 .byte $39,$39,$39,$39,$39,$01,$01,$01
 .byte $29,$39,$39,$39,$01,$01,$01,$29
 .byte $39,$39,$39,$39,$ff

;track3
montymaintr3 =*
 .byte $13,$16,$19
 .byte $1c,$02,$02,$1d,$1e,$02,$02,$1d
 .byte $1f,$04,$04,$20,$20,$06,$02,$02
 .byte $1d,$1e,$02,$02,$1d,$1f,$04,$04
 .byte $20,$20,$06,$08,$08,$08,$08,$21
 .byte $21,$21,$21,$22,$22,$22,$23,$22
 .byte $24,$25,$3b,$26,$26,$26,$26,$26
 .byte $26,$26,$26,$26,$26,$26,$26,$26
 .byte $26,$26,$26,$02,$02,$1d,$1e,$02
 .byte $02,$1d,$1f,$2f,$2f,$2f,$2f,$2f
 .byte $2f,$2f,$2f,$2f,$2f,$2f,$2f,$2f
 .byte $0b,$0b,$1d,$1d,$0b,$0b,$1d,$0b
 .byte $0b,$0b,$0c,$0c,$1d,$1d,$1d,$10
 .byte $0b,$0b,$1d,$1d,$0b,$0b,$1d,$0b
 .byte $0b,$0b,$0c,$0c,$1d,$1d,$1d,$10
 .byte $0b,$1d,$0b,$1d,$0b,$1d,$0b,$1d
 .byte $0b,$0c,$1d,$0b,$0c,$23,$0b,$0b
 .byte $ff


;====================================
;patterns
;====================================

ptn00 =*
 .byte $83,$00,$37,$01,$3e,$01,$3e,$03
 .byte $3d,$03,$3e,$03,$43,$03,$3e,$03
 .byte $3d,$03,$3e,$03,$37,$01,$3e,$01
 .byte $3e,$03,$3d,$03,$3e,$03,$43,$03
 .byte $42,$03,$43,$03,$45,$03,$46,$01
 .byte $48,$01,$46,$03,$45,$03,$43,$03
 .byte $4b,$01,$4d,$01,$4b,$03,$4a,$03
 .byte $48,$ff

ptn27 =*
 .byte $1f,$4a,$ff

ptn28 =*
 .byte $03,$46,$01,$48,$01,$46,$03,$45
 .byte $03,$4a,$0f,$43,$ff

ptn03 =*
 .byte $bf,$06
 .byte $48,$07,$48,$01,$4b,$01,$4a,$01
 .byte $4b,$01,$4a,$03,$4b,$03,$4d,$03
 .byte $4b,$03,$4a,$3f,$48,$07,$48,$01
 .byte $4b,$01,$4a,$01,$4b,$01,$4a,$03
 .byte $4b,$03,$4d,$03,$4b,$03,$48,$3f
 .byte $4c,$07,$4c,$01,$4f,$01,$4e,$01
 .byte $4f,$01,$4e,$03,$4f,$03,$51,$03
 .byte $4f,$03,$4e,$3f,$4c,$07,$4c,$01
 .byte $4f,$01,$4e,$01,$4f,$01,$4e,$03
 .byte $4f,$03,$51,$03,$4f,$03,$4c,$ff

ptn05 =*
 .byte $83,$04,$26,$03,$29,$03,$28,$03
 .byte $29,$03,$26,$03,$35,$03,$34,$03
 .byte $32,$03,$2d,$03,$30,$03,$2f,$03
 .byte $30,$03,$2d,$03,$3c,$03,$3b,$03
 .byte $39,$03,$30,$03,$33,$03,$32,$03
 .byte $33,$03,$30,$03,$3f,$03,$3e,$03
 .byte $3c,$03,$46,$03,$45,$03,$43,$03
 .byte $3a,$03,$39,$03,$37,$03,$2e,$03
 .byte $2d,$03,$26,$03,$29,$03,$28,$03
 .byte $29,$03,$26,$03,$35,$03,$34,$03
 .byte $32,$03,$2d,$03,$30,$03,$2f,$03
 .byte $30,$03,$2d,$03,$3c,$03,$3b,$03
 .byte $39,$03,$30,$03,$33,$03,$32,$03
 .byte $33,$03,$30,$03,$3f,$03,$3e,$03
 .byte $3c,$03,$34,$03,$37,$03,$36,$03
 .byte $37,$03,$34,$03,$37,$03,$3a,$03
 .byte $3d

ptn3a =*
 .byte $03,$3e,$07,$3e,$07,$3f,$07
 .byte $3e,$03,$3c,$07,$3e,$57,$ff

ptn07 =*
 .byte $8b
 .byte $00,$3a,$01,$3a,$01,$3c,$03,$3d
 .byte $03,$3f,$03,$3d,$03,$3c,$0b,$3a
 .byte $03,$39,$07,$3a,$81,$06,$4b,$01
 .byte $4d,$01,$4e,$01,$4d,$01,$4e,$01
 .byte $4d,$05,$4b,$81,$00,$3a,$01,$3c
 .byte $01,$3d,$03,$3f,$03,$3d,$03,$3c
 .byte $03,$3a,$03,$39,$1b,$3a,$0b,$3b
 .byte $01,$3b,$01,$3d,$03,$3e,$03,$40
 .byte $03,$3e,$03,$3d,$0b,$3b,$03,$3a
 .byte $07,$3b,$81,$06,$4c,$01,$4e,$01
 .byte $4f,$01,$4e,$01,$4f,$01,$4e,$05
 .byte $4c,$81,$00,$3b,$01,$3d,$01,$3e
 .byte $03,$40,$03,$3e,$03,$3d,$03,$3b
 .byte $03,$3a,$1b,$3b,$8b,$05,$35,$03
 .byte $33,$07,$32,$03,$30,$03,$2f,$0b
 .byte $30,$03,$32,$0f,$30,$0b,$35,$03
 .byte $33,$07,$32,$03,$30,$03,$2f,$1f
 .byte $30,$8b,$00,$3c,$01,$3c,$01,$3e
 .byte $03,$3f,$03,$41,$03,$3f,$03,$3e
 .byte $0b,$3d,$01,$3d,$01,$3f,$03,$40
 .byte $03,$42,$03,$40,$03,$3f,$03,$3e
 .byte $01,$3e,$01,$40,$03,$41,$03,$40
 .byte $03,$3e,$03,$3d,$03,$3e,$03,$3c
 .byte $03,$3a,$01,$3a,$01,$3c,$03,$3d
 .byte $03,$3c,$03,$3a,$03,$39,$03,$3a
 .byte $03,$3c,$ff

ptn09 =*
 .byte $83,$00,$32,$01,$35,$01,$34,$03
 .byte $32,$03,$35,$03,$34,$03,$32,$03
 .byte $35,$01,$34,$01,$32,$03,$32,$03
 .byte $3a,$03,$39,$03,$3a,$03,$32,$03
 .byte $3a,$03,$39,$03,$3a,$ff

ptn2a =*
 .byte $03,$34,$01,$37,$01,$35,$03,$34
 .byte $03,$37,$03,$35,$03,$34,$03,$37
 .byte $01,$35,$01,$34,$03,$34,$03,$3a
 .byte $03,$39,$03,$3a,$03,$34,$03,$3a
 .byte $03,$39,$03,$3a,$ff

ptn2b =*
 .byte $03,$39,$03,$38,$03,$39,$03,$3a
 .byte $03,$39,$03,$37,$03,$35,$03,$34
 .byte $03,$35,$03,$34,$03,$35,$03,$37
 .byte $03,$35,$03,$34,$03,$32,$03,$31
 .byte $ff

ptn0a =*
 .byte $03
 .byte $37,$01,$3a,$01,$39,$03,$37,$03
 .byte $3a,$03,$39,$03,$37,$03,$3a,$01
 .byte $39,$01,$37,$03,$37,$03,$3e,$03
 .byte $3d,$03,$3e,$03,$37,$03,$3e,$03
 .byte $3d,$03,$3e,$03,$3d,$01,$40,$01
 .byte $3e,$03,$3d,$03,$40,$01,$3e,$01
 .byte $3d,$03,$40,$03,$3e,$03,$40,$03
 .byte $40,$01,$43,$01,$41,$03,$40,$03
 .byte $43,$01,$41,$01,$40,$03,$43,$03
 .byte $41,$03,$43,$03,$43,$01,$46,$01
 .byte $45,$03,$43,$03,$46,$01,$45,$01
 .byte $43,$03,$46,$03,$45,$03,$43,$01
 .byte $48,$01,$49,$01,$48,$01,$46,$01
 .byte $45,$01,$46,$01,$45,$01,$43,$01
 .byte $41,$01,$43,$01,$41,$01,$40,$01
 .byte $3d,$01,$39,$01,$3b,$01,$3d,$ff

ptn0d =*
 .byte $01,$3e,$01,$39,$01,$35,$01,$39
 .byte $01,$3e,$01,$39,$01,$35,$01,$39
 .byte $03,$3e,$01,$41,$01,$40,$03,$40
 .byte $01,$3d,$01,$3e,$01,$40,$01,$3d
 .byte $01,$39,$01,$3d,$01,$40,$01,$3d
 .byte $01,$39,$01,$3d,$03,$40,$01,$43
 .byte $01,$41,$03,$41,$01,$3e,$01,$40
 .byte $01,$41,$01,$3e,$01,$39,$01,$3e
 .byte $01,$41,$01,$3e,$01,$39,$01,$3e
 .byte $03,$41,$01,$45,$01,$43,$03,$43
 .byte $01,$40,$01,$41,$01,$43,$01,$40
 .byte $01,$3d,$01,$40,$01,$43,$01,$40
 .byte $01,$3d,$01,$40,$01,$46,$01,$43
 .byte $01,$45,$01,$46,$01,$44,$01,$43
 .byte $01,$40,$01,$3d,$ff

ptn0f =*
 .byte $01,$3e,$01
 .byte $39,$01,$35,$01,$39,$01,$3e,$01
 .byte $39,$01,$35,$01,$39,$01,$3e,$01
 .byte $39,$01,$35,$01,$39,$01,$3e,$01
 .byte $39,$01,$35,$01,$39,$01,$3e,$01
 .byte $3a,$01,$37,$01,$3a,$01,$3e,$01
 .byte $3a,$01,$37,$01,$3a,$01,$3e,$01
 .byte $3a,$01,$37,$01,$3a,$01,$3e,$01
 .byte $3a,$01,$37,$01,$3a,$01,$40,$01
 .byte $3d,$01,$39,$01,$3d,$01,$40,$01
 .byte $3d,$01,$39,$01,$3d,$01,$40,$01
 .byte $3d,$01,$39,$01,$3d,$01,$40,$01
 .byte $3d,$01,$39,$01,$3d,$01,$41,$01
 .byte $3e,$01,$39,$01,$3e,$01,$41,$01
 .byte $3e,$01,$39,$01,$3e,$01,$41,$01
 .byte $3e,$01,$39,$01,$3e,$01,$41,$01
 .byte $3e,$01,$39,$01,$3e,$01,$43,$01
 .byte $3e,$01,$3a,$01,$3e,$01,$43,$01
 .byte $3e,$01,$3a,$01,$3e,$01,$43,$01
 .byte $3e,$01,$3a,$01,$3e,$01,$43,$01
 .byte $3e,$01,$3a,$01,$3e,$01,$43,$01
 .byte $3f,$01,$3c,$01,$3f,$01,$43,$01
 .byte $3f,$01,$3c,$01,$3f,$01,$43,$01
 .byte $3f,$01,$3c,$01,$3f,$01,$43,$01
 .byte $3f,$01,$3c,$01,$3f,$01,$45,$01
 .byte $42,$01,$3c,$01,$42,$01,$45,$01
 .byte $42,$01,$3c,$01,$42,$01,$48,$01
 .byte $45,$01,$42,$01,$45,$01,$4b,$01
 .byte $48,$01,$45,$01,$48,$01,$4b,$01
 .byte $4a,$01,$48,$01,$4a,$01,$4b,$01
 .byte $4a,$01,$48,$01,$4a,$01,$4b,$01
 .byte $4a,$01,$48,$01,$4a,$01,$4c,$01
 .byte $4e,$03,$4f,$ff

ptn11 =*
 .byte $bf,$06,$56,$1f,$57,$1f,$56,$1f
 .byte $5b,$1f,$56,$1f,$57,$1f,$56,$1f
 .byte $4f,$ff

ptn12 =*
 .byte $bf,$0c,$56,$7f,$7f,$7f,$7f,$7f
 .byte $7f,$7f,$ff

ptn13 =*
 .byte $bf,$08,$13,$3f,$13,$3f,$13,$3f
 .byte $13,$3f,$13,$3f,$13,$3f,$13,$1f
 .byte $13,$ff

ptn14 =*
 .byte $97,$09,$2e,$03,$2e,$1b,$32,$03
 .byte $32,$1b,$31,$03,$31,$1f,$34,$43
 .byte $17,$32,$03,$32,$1b,$35,$03,$35
 .byte $1b,$34,$03,$34,$0f,$37,$8f,$0a
 .byte $37,$43,$ff

ptn15 =*
 .byte $97,$09,$2b,$03,$2b,$1b,$2e,$03
 .byte $2e,$1b,$2d,$03,$2d,$1f,$30,$43
 .byte $17,$2e,$03,$2e,$1b,$32,$03,$32
 .byte $1b,$31,$03,$31,$0f,$34,$8f,$0a
 .byte $34,$43,$ff

ptn16 =*
 .byte $0f,$1f,$0f,$1f,$0f,$1f,$0f,$1f
 .byte $0f,$1f,$0f,$1f,$0f,$1f,$0f,$1f
 .byte $0f,$1f,$0f,$1f,$0f,$1f,$0f,$1f
 .byte $0f,$1f,$0f,$1f,$0f,$1f,$0f,$1f
 .byte $ff

ptn17 =*
 .byte $97,$09,$33,$03,$33,$1b,$37,$03
 .byte $37,$1b,$36,$03,$36,$1f,$39,$43
 .byte $17,$37,$03,$37,$1b,$3a,$03,$3a
 .byte $1b,$39,$03,$39,$2f,$3c,$21,$3c
 .byte $21,$3d,$21,$3e,$21,$3f,$21,$40
 .byte $21,$41,$21,$42,$21,$43,$21,$44
 .byte $01,$45,$ff

ptn18 =*
 .byte $97,$09,$30,$03,$30,$1b,$33,$03
 .byte $33,$1b,$32,$03,$32,$1f,$36,$43
 .byte $17,$33,$03,$33,$1b,$37,$03,$37
 .byte $1b,$36,$03,$36,$2f,$39,$21,$39
 .byte $21,$3a,$21,$3b,$21,$3c,$21,$3d
 .byte $21,$3e,$21,$3f,$21,$40,$21,$41
 .byte $01,$42,$ff

ptn19 =*
 .byte $0f,$1a,$0f,$1a,$0f,$1a,$0f,$1a
 .byte $0f,$1a,$0f,$1a,$0f,$1a,$0f,$1a
 .byte $0f,$1a,$0f,$1a,$0f,$1a,$0f,$1a
 .byte $0f,$1a,$0f,$1a,$0f,$1a,$0f,$1a
 .byte $ff

ptn1a =*
 .byte $1f,$46,$bf,$0a,$46,$7f,$7f,$ff

ptn1b =*
 .byte $1f,$43,$bf,$0a,$43,$7f,$ff

ptn1c =*
 .byte $83,$02,$13,$03,$13,$03,$1e,$03
 .byte $1f,$03,$13,$03,$13,$03,$1e,$03
 .byte $1f,$03,$13,$03,$13,$03,$1e,$03
 .byte $1f,$03,$13,$03,$13,$03,$1e,$03
 .byte $1f,$03,$13,$03,$13,$03,$1e,$03
 .byte $1f,$03,$13,$03,$13,$03,$1e,$03
 .byte $1f,$03,$13,$03,$13,$03,$1e,$03
 .byte $1f,$03,$13,$03,$13,$03,$1e,$03
 .byte $1f,$ff

ptn29 =*
 .byte $8f,$0b,$38,$4f,$ff

ptn2c =*
 .byte $83,$0e,$32,$07,$32,$07,$2f,$07
 .byte $2f,$03,$2b,$87,$0b,$46,$83,$0e
 .byte $2c,$03,$2c,$8f,$0b,$32,$ff

ptn2d =*
 .byte $43,$83,$0e,$32,$03,$32,$03,$2f
 .byte $03,$2f,$03,$2c,$87,$0b,$38,$ff

ptn39 =*
 .byte $83,$01
 .byte $43,$01,$4f,$01,$5b,$87,$03,$2f
 .byte $83,$01,$43,$01,$4f,$01,$5b,$87
 .byte $03,$2f,$83,$01,$43,$01,$4f,$01
 .byte $5b,$87,$03,$2f,$83,$01,$43,$01
 .byte $4f,$01,$5b,$87,$03,$2f,$83,$01
 .byte $43,$01,$4f,$01,$5b,$87,$03,$2f
 .byte $83,$01,$43,$01,$4f,$01,$5b,$87
 .byte $03,$2f

ptn01 =*
 .byte $83,$01,$43,$01,$4f,$01,$5b,$87
 .byte $03,$2f,$83,$01,$43,$01,$4f,$01
 .byte $5b,$87,$03,$2f,$ff

ptn02 =*
 .byte $83,$02,$13,$03,$13,$03,$1f,$03
 .byte $1f,$03,$13,$03,$13,$03,$1f,$03
 .byte $1f,$ff

ptn1d =*
 .byte $03,$15,$03,$15,$03,$1f,$03,$21
 .byte $03,$15,$03,$15,$03,$1f,$03,$21
 .byte $ff

ptn1e =*
 .byte $03,$1a,$03,$1a,$03,$1c,$03,$1c
 .byte $03,$1d,$03,$1d,$03,$1e,$03,$1e
 .byte $ff

ptn1f =*
 .byte $03,$1a,$03,$1a,$03,$24,$03,$26
 .byte $03,$13,$03,$13,$07,$1f,$ff

ptn04 =*
 .byte $03,$18,$03,$18,$03,$24,$03,$24
 .byte $03,$18,$03,$18,$03,$24,$03,$24
 .byte $03,$20,$03,$20,$03,$2c,$03,$2c
 .byte $03,$20,$03,$20,$03,$2c,$03,$2c
 .byte $ff

ptn20 =*
 .byte $03,$19,$03,$19,$03
 .byte $25,$03,$25,$03,$19,$03,$19,$03
 .byte $25,$03,$25,$03,$21,$03,$21,$03
 .byte $2d,$03,$2d,$03,$21,$03,$21,$03
 .byte $2d,$03,$2d,$ff

ptn06 =*
 .byte $03,$1a,$03,$1a
 .byte $03,$26,$03,$26,$03,$1a,$03,$1a
 .byte $03,$26,$03,$26,$03,$15,$03,$15
 .byte $03,$21,$03,$21,$03,$15,$03,$15
 .byte $03,$21,$03,$21,$03,$18,$03,$18
 .byte $03,$24,$03,$24,$03,$18,$03,$18
 .byte $03,$24,$03,$24,$03,$1f,$03,$1f
 .byte $03,$2b,$03,$2b,$03,$1f,$03,$1f
 .byte $03,$2b,$03,$2b,$03,$1a,$03,$1a
 .byte $03,$26,$03,$26,$03,$1a,$03,$1a
 .byte $03,$26,$03,$26,$03,$15,$03,$15
 .byte $03,$21,$03,$21,$03,$15,$03,$15
 .byte $03,$21,$03,$21,$03,$18,$03,$18
 .byte $03,$24,$03,$24,$03,$18,$03,$18
 .byte $03,$24,$03,$24,$03,$1c,$03,$1c
 .byte $03,$28,$03,$28,$03,$1c,$03,$1c
 .byte $03,$28,$03,$28

ptn3b =*
 .byte $83,$04,$36,$07
 .byte $36,$07,$37,$07,$36,$03,$33,$07
 .byte $32,$57,$ff

ptn08 =*
 .byte $83,$02,$1b,$03,$1b,$03,$27,$03
 .byte $27,$03,$1b,$03,$1b,$03,$27,$03
 .byte $27,$ff

ptn21 =*
 .byte $03,$1c,$03,$1c,$03,$28,$03,$28
 .byte $03,$1c,$03,$1c,$03,$28,$03,$28
 .byte $ff

ptn22 =*
 .byte $03,$1d,$03,$1d,$03,$29,$03,$29
 .byte $03,$1d,$03,$1d,$03,$29,$03,$29
 .byte $ff

ptn23 =*
 .byte $03,$18,$03,$18,$03,$24,$03,$24
 .byte $03,$18,$03,$18,$03,$24,$03,$24
 .byte $ff

ptn24 =*
 .byte $03,$1e,$03,$1e,$03,$2a,$03,$2a
 .byte $03,$1e,$03,$1e,$03,$2a,$03,$2a
 .byte $ff

ptn25 =*
 .byte $83,$05,$26,$01,$4a,$01,$34,$03
 .byte $29,$03,$4c,$03,$4a,$03,$31,$03
 .byte $4a,$03,$24,$03,$22,$01,$46,$01
 .byte $30,$03,$25,$03,$48,$03,$46,$03
 .byte $2d,$03,$46,$03,$24,$ff

ptn0b =*
 .byte $83,$02,$1a,$03,$1a,$03,$26,$03
 .byte $26,$03,$1a,$03,$1a,$03,$26,$03
 .byte $26,$ff

ptn0c =*
 .byte $03,$13,$03,$13,$03,$1d,$03,$1f
 .byte $03,$13,$03,$13,$03,$1d,$03,$1f
 .byte $ff

ptn26 =*
 .byte $87,$02,$1a,$87,$03,$2f,$83,$02
 .byte $26,$03,$26,$87,$03,$2f,$ff

ptn10 =*
 .byte $07,$1a,$4f,$47,$ff

ptn0e =*
 .byte $03,$1f,$03,$1f,$03,$24,$03,$26
 .byte $07,$13,$47,$ff

ptn30 =*
 .byte $bf,$0f,$32,$0f,$32,$8f,$90,$30
 .byte $3f,$32,$13,$32,$03,$32,$03,$35
 .byte $03,$37,$3f,$37,$0f,$37,$8f,$90
 .byte $30,$3f,$32,$13,$32,$03,$2d,$03
 .byte $30,$03,$32,$ff

ptn31 =*
 .byte $0f,$32
 .byte $af,$90,$35,$0f,$37,$a7,$99,$37
 .byte $07,$35,$3f,$32,$13,$32,$03,$32
 .byte $a3,$e8,$35,$03,$37,$0f,$35,$af
 .byte $90,$37,$0f,$37,$a7,$99,$37,$07
 .byte $35,$3f,$32,$13,$32,$03,$2d,$a3
 .byte $e8,$30,$03,$32,$ff

ptn32 =*
 .byte $07,$32,$03
 .byte $39,$13,$3c,$a7,$9a,$37,$a7,$9b
 .byte $38,$07,$37,$03,$35,$03,$32,$03
 .byte $39,$1b,$3c,$a7,$9a,$37,$a7,$9b
 .byte $38,$07,$37,$03,$35,$03,$32,$03
 .byte $39,$03,$3c,$03,$3e,$03,$3c,$07
 .byte $3e,$03,$3c,$03,$39,$a7,$9a,$37
 .byte $a7,$9b,$38,$07,$37,$03,$35,$03
 .byte $32,$af,$90,$3c,$1f,$3e,$43,$03
 .byte $3e,$03,$3c,$03,$3e,$ff

ptn33 =*
 .byte $03,$3e
 .byte $03,$3e,$a3,$e8,$3c,$03,$3e,$03
 .byte $3e,$03,$3e,$a3,$e8,$3c,$03,$3e
 .byte $03,$3e,$03,$3e,$a3,$e8,$3c,$03
 .byte $3e,$03,$3e,$03,$3e,$a3,$e8,$3c
 .byte $03,$3e,$af,$91,$43,$1f,$41,$43
 .byte $03,$3e,$03,$41,$03,$43,$03,$43
 .byte $03,$43,$a3,$e8,$41,$03,$43,$03
 .byte $43,$03,$43,$a3,$e8,$41,$03,$43
 .byte $03,$45,$03,$48,$a3,$fd,$45,$03
 .byte $44,$01,$43,$01,$41,$03,$3e,$03
 .byte $3c,$03,$3e,$2f,$3e,$bf,$98,$3e
 .byte $43,$03,$3e,$03,$3c,$03,$3e,$ff

ptn34 =*
 .byte $03,$4a,$03,$4a,$a3,$f8,$48,$03
 .byte $4a,$03,$4a,$03,$4a,$a3,$f8,$48
 .byte $03,$4a,$ff

ptn35 =*
 .byte $01,$51,$01,$54,$01
 .byte $51,$01,$54,$01,$51,$01,$54,$01
 .byte $51,$01,$54,$01,$51,$01,$54,$01
 .byte $51,$01,$54,$01,$51,$01,$54,$01
 .byte $51,$01,$54,$ff

ptn36 =*
 .byte $01,$50,$01,$4f
 .byte $01,$4d,$01,$4a,$01,$4f,$01,$4d
 .byte $01,$4a,$01,$48,$01,$4a,$01,$48
 .byte $01,$45,$01,$43,$01,$44,$01,$43
 .byte $01,$41,$01,$3e,$01,$43,$01,$41
 .byte $01,$3e,$01,$3c,$01,$3e,$01,$3c
 .byte $01,$39,$01,$37,$01,$38,$01,$37
 .byte $01,$35,$01,$32,$01,$37,$01,$35
 .byte $01,$32,$01,$30,$ff

ptn37 =*
 .byte $5f,$5f,$5f
 .byte $47,$83,$0e,$32,$07,$32,$07,$2f
 .byte $03,$2f,$07,$2f,$97,$0b,$3a,$5f
 .byte $5f,$47,$8b,$0e,$32,$03,$32,$03
 .byte $2f,$03,$2f,$47,$97,$0b,$3a,$5f
 .byte $5f,$47,$83,$0e,$2f,$0b,$2f,$03
 .byte $2f,$03,$2f,$87,$0b,$30,$17,$3a
 .byte $5f,$8b,$0e,$32,$0b,$32,$0b,$2f
 .byte $0b,$2f,$07,$2c,$07,$2c,$ff

ptn38 =*
 .byte $87
 .byte $0b,$34,$17,$3a,$5f,$5f,$84,$0e
 .byte $32,$04,$32,$05,$32,$04,$2f,$04
 .byte $2f,$05,$2f,$47,$97,$0b,$3a,$5f
 .byte $5f,$84,$0e,$32,$04,$32,$05,$32
 .byte $04,$2f,$04,$2f,$05,$2f,$ff

ptn2f =*
 .byte $03,$1a,$03,$1a,$03
 .byte $24,$03,$26,$03,$1a,$03,$1a,$03
 .byte $18,$03,$19,$03,$1a,$03,$1a,$03
 .byte $24,$03,$26,$03,$1a,$03,$1a,$03
 .byte $18,$03,$19,$03,$18,$03,$18,$03
 .byte $22,$03,$24,$03,$18,$03,$18,$03
 .byte $16,$03,$17,$03,$18,$03,$18,$03
 .byte $22,$03,$24,$03,$18,$03,$18,$03
 .byte $16,$03,$17,$03,$13,$03,$13,$03
 .byte $1d,$03,$1f,$03,$13,$03,$13,$03
 .byte $1d,$03,$1e,$03,$13,$03,$13,$03
 .byte $1d,$03,$1f,$03,$13,$03,$13,$03
 .byte $1d,$03,$1e,$03,$1a,$03,$1a,$03
 .byte $24,$03,$26,$03,$1a,$03,$1a,$03
 .byte $18,$03,$19,$03,$1a,$03,$1a,$03
 .byte $24,$03,$26,$03,$1a,$03,$1a,$03
 .byte $18,$03,$19,$ff



;====================================
;instruments
;====================================

; Drum = $01
; Sky = $02
; Arp = $04


	; 0     1     2     3     4    5     6    7
	;  XXX,XXX,CTL,XXX,XXX,VIB,PUL,FX

instr =*
 .byte $80,$09,$41,$48,$60,$03,$81,$00
 .byte $00,$08,$81,$02,$08,$00,$00,$01
 .byte $a0,$02,$41,$09,$80,$00,$00,$00
 .byte $00,$02,$81,$09,$09,$00,$00,$05
 .byte $00,$08,$41,$08,$50,$02,$00,$04
 .byte $00,$01,$41,$3f,$c0,$02,$00,$00
 .byte $00,$08,$41,$04,$40,$02,$00,$00
 .byte $00,$08,$41,$09,$00,$02,$00,$00
 .byte $00,$09,$41,$09,$70,$02,$5f,$04
 .byte $00,$09,$41,$4a,$69,$02,$81,$00
 .byte $00,$09,$41,$40,$6f,$00,$81,$02
 .byte $80,$07,$81,$0a,$0a,$00,$00,$01
 .byte $00,$09,$41,$3f,$ff,$01,$e7,$02		; first skydive
 .byte $00,$08,$41,$90,$f0,$01,$e8,$02
 .byte $00,$08,$41,$06,$0a,$00,$00,$01
 .byte $00,$09,$41,$19,$70,$02,$a8,$00
 .byte $00,$02,$41,$09,$90,$02,$00,$00
 .byte $00,$00,$11,$0a,$fa,$00,$00,$05
 .byte $00,$08,$41,$37,$40,$02,$00,$00
 .byte $00,$08,$11,$07,$70,$02,$00,$00


