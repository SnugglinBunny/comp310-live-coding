    .inesprg 1
    .ineschr 1
    .inesmap 0
    .inesmir 1

; ---------------------------------------------------------------------------

PPUCTRL 	= $2000
PPUMASK 	= $2001
PPUSTATUS 	= $2002
OAMADDR 	= $2003
OAMDATA 	= $2004
PPUSCROLL 	= $2005
PPUADDR 	= $2006
PPUDATA 	= $2007
OAMDMA 		= $4014
JOYPAD1     = $4016
JOYPAD2     = $4017

BUTTON_A        = %10000000
BUTTON_B        = %01000000
BUTTON_SELECT   = %00100000
BUTTON_START    = %00010000
BUTTON_UP       = %00001000
BUTTON_DOWN     = %000000100
BUTTON_LEFT     = %000000010
BUTTON_RIGHT    = %000000001

    .rsset $0010
joypad1_state    .rs 1

    .rsset $0200
spirte_player   .rs 4

    .rsset $0000
SPRITE_Y        .rs 1
SPRITE_TILE     .rs 1
SPRITE_ATTRIB   .rs 1
SPRITE_X        .rs 1

    .bank 0
    .org $C000

; Initialisation code based on https://wiki.nesdev.com/w/index.php/Init_code
RESET:
    SEI        ; ignore IRQs
    CLD        ; disable decimal mode
    LDX #$40
    STX $4017  ; disable APU frame IRQ
    LDX #$ff
    TXS        ; Set up stack
    INX        ; now X = 0
    STX PPUCTRL		; disable NMI
    STX PPUMASK		; disable rendering
    STX $4010  ; disable DMC IRQs

    ; Optional (omitted):
    ; Set up mapper and jmp to further init code here.

    ; If the user presses Reset during vblank, the PPU may reset
    ; with the vblank flag still true.  This has about a 1 in 13
    ; chance of happening on NTSC or 2 in 9 on PAL.  Clear the
    ; flag now so the vblankwait1 loop sees an actual vblank.
    BIT PPUSTATUS

    ; First of two waits for vertical blank to make sure that the
    ; PPU has stabilized
vblankwait1:  
    BIT PPUSTATUS
    BPL vblankwait1

    ; We now have about 30,000 cycles to burn before the PPU stabilizes.
    ; One thing we can do with this time is put RAM in a known state.
    ; Here we fill it with $00, which matches what (say) a C compiler
    ; expects for BSS.  Conveniently, X is still 0.
    TXA
clrmem:
    STA $000,x
    STA $100,x
    STA $300,x
    STA $400,x
    STA $500,x
    STA $600,x
    STA $700,x  ; Remove this if you're storing reset-persistent data

    ; We skipped $200,x on purpose.  Usually, RAM page 2 is used for the
    ; display list to be copied to OAM.  OAM needs to be initialized to
    ; $EF-$FF, not 0, or you'll get a bunch of garbage sprites at (0, 0).

    INX
    BNE clrmem

    ; Other things you can do between vblank waits are set up audio
    ; or set up other mapper registers.
   
vblankwait2:
    BIT PPUSTATUS
    BPL vblankwait2

    ; End of initialisation code
	
	; Reset the PPU high/low latch
	LDA PPUSTATUS
	
	; Write address 3F10 (background colour) to the PPU
	LDA #$3F
	STA PPUADDR
	LDA #$10
	STA PPUADDR
	
	; Write the background colour
	LDA #$38
	STA PPUDATA
	
	; Write the pallet colours
	LDA #$17
	STA PPUDATA
    LDA #$36
	STA PPUDATA
    LDA #$0D
	STA PPUDATA
	
	; Write sprite data for sprite 0
	LDA #120	; Y Position
	STA spirte_player + SPRITE_Y
	LDA #0		; Tile number
	STA spirte_player + SPRITE_TILE
	LDA #0		; Attributes
	STA spirte_player + SPRITE_ATTRIB
	LDA #128	; X Position
	STA spirte_player + SPRITE_X
	
	LDA #%10000000	; Enable NMI
	STA PPUCTRL
	
	LDA #%00010000 ; Enable sprites
	STA PPUMASK
	
	; Enter an infinite loop
forever:
    JMP forever

; ---------------------------------------------------------------------------

; NMI is called on every frame
NMI:
    ; Initialise controller 1
    LDA #1
    STA JOYPAD1
    LDA #0
    STA JOYPAD1

    ; Read joypad state
    LDX #0
    STX joypad1_state
ReadController:
    LDA JOYPAD1
    LSR A
    ROL joypad1_state
    INX
    CPX #8
    BNE ReadController

    ; React to RIGHT button
    LDA joypad1_state
    AND #BUTTON_RIGHT
    BEQ ReadRight_Done  ; if ((JOYPAD1 & 1) != 0) {
    LDA spirte_player + SPRITE_X
    CLC
    ADC #1
    STA spirte_player + SPRITE_X

ReadRight_Done: ;}

    ; Read DOWN button
    LDA joypad1_state
    AND #BUTTON_DOWN
    BEQ ReadDown_Done  ; if ((JOYPAD1 & 1) != 0) {
    LDA spirte_player + SPRITE_Y
    CLC
    ADC #1
    STA spirte_player + SPRITE_Y

ReadDown_Done: ;}

    ; Read Left button
    LDA joypad1_state
    AND #BUTTON_LEFT
    BEQ ReadLeft_Done  ; if ((JOYPAD1 & 1) != 0) {
    LDA spirte_player + SPRITE_X
    SEC
    SBC #1
    STA spirte_player + SPRITE_X

ReadLeft_Done: ;}

    ; Read UP button
    LDA joypad1_state
    AND #BUTTON_UP
    BEQ ReadUp_Done  ; if ((JOYPAD1 & 1) != 0) {
    LDA spirte_player + SPRITE_Y
    SEC
    SBC #1
    STA spirte_player + SPRITE_Y

ReadUp_Done: ;}


    ; Copy sprite data to the PPU
	LDA #0
	STA OAMADDR
	LDA #02
	STA OAMDMA
	

    RTI         ; Return from interrupt

; ---------------------------------------------------------------------------

    .bank 1
    .org $FFFA
    .dw NMI
    .dw RESET
    .dw 0

; ---------------------------------------------------------------------------

    .bank 2
    .org $0000
    .incbin "sprites.chr" 