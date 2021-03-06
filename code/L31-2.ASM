; Program to demonstrate the two pages available in 320x400
; 256-color modes on a VGA.  Draws diagonal color bars in all
; 256 colors in page 0, then does the same in page 1 (but with
; the bars tilted the other way), and finally draws vertical
; color bars in page 0.
;
VGA_SEGMENT     equ     0a000h
SC_INDEX        equ     3c4h    ;Sequence Controller Index register
GC_INDEX        equ     3ceh    ;Graphics Controller Index register
CRTC_INDEX      equ     3d4h    ;CRT Controller Index register
MAP_MASK        equ     2       ;Map Mask register index in SC
MEMORY_MODE     equ     4       ;Memory Mode register index in SC
MAX_SCAN_LINE   equ     9       ;Maximum Scan Line reg index in CRTC
START_ADDRESS_HIGH equ  0ch     ;Start Address High reg index in CRTC
UNDERLINE       equ     14h     ;Underline Location reg index in CRTC
MODE_CONTROL    equ     17h     ;Mode Control register index in CRTC
GRAPHICS_MODE   equ     5       ;Graphics Mode register index in GC
MISCELLANEOUS   equ     6       ;Miscellaneous register index in GC
SCREEN_WIDTH    equ     320     ;# of pixels across screen
SCREEN_HEIGHT   equ     400     ;# of scan lines on screen
WORD_OUTS_OK    equ     1       ;set to 0 to assemble for
                                ; computers that can't handle
                                ; word outs to indexed VGA registers
;
stack   segment para stack 'STACK'
        db      512 dup (?)
stack   ends
;
; Macro to output a word value to a port.
;
OUT_WORD        macro
if WORD_OUTS_OK
        out     dx,ax
else
        out     dx,al
        inc     dx
        xchg    ah,al
        out     dx,al
        dec     dx
        xchg    ah,al
endif
        endm
;
; Macro to output a constant value to an indexed VGA register.
;
CONSTANT_TO_INDEXED_REGISTER    macro   ADDRESS, INDEX, VALUE
        mov     dx,ADDRESS
        mov     ax,(VALUE shl 8) + INDEX
        OUT_WORD
        endm
;
Code    segment
        assume  cs:Code
Start   proc    near
;
; Set 320x400 256-color mode.
;
        call    Set320By400Mode
;
; We're in 320x400 256-color mode, with page 0 displayed.
; Let's fill page 0 with color bars slanting down and to the right.
;
        sub     di,di           ;page 0 starts at address 0
        mov     bl,1            ;make color bars slant down and
                                ; to the right
        call    ColorBarsUp     ;draw the color bars
;
; Now do the same for page 1, but with the color bars
; tilting the other way.
;
        mov     di,8000h        ;page 1 starts at address 8000h
        mov     bl,-1           ;make color bars slant down and
                                ; to the left
        call    ColorBarsUp     ;draw the color bars
;
; Wait for a key and flip to page 1 when one is pressed.
;
        call    GetNextKey
        CONSTANT_TO_INDEXED_REGISTER CRTC_INDEX,START_ADDRESS_HIGH,80h
                                ;set the Start Address High register
                                ; to 80h, for a start address of 8000h
;
; Draw vertical bars in page 0 while page 1 is displayed.
;
        sub     di,di           ;page 0 starts at address 0
        sub     bl,bl           ;make color bars vertical
        call    ColorBarsUp     ;draw the color bars
;
; Wait for another key and flip back to page 0 when one is pressed.
;
        call    GetNextKey
        CONSTANT_TO_INDEXED_REGISTER CRTC_INDEX,START_ADDRESS_HIGH,00h
                                ;set the Start Address High register
                                ; to 00h, for a start address of 0000h
;
; Wait for yet another key and return to text mode and end when
; one is pressed.
;
        call    GetNextKey
        mov     ax,0003h
        int     10h             ;text mode
        mov     ah,4ch
        int     21h             ;done
;
Start   endp
;
; Sets up 320x400 256-color modes.
;
; Input: none
;
; Output: none
;
Set320By400Mode proc    near
;
; First, go to normal 320x200 256-color mode, which is really a
; 320x400 256-color mode with each line scanned twice.
;
        mov     ax,0013h        ;AH = 0 means mode set, AL = 13h selects
                                ; 256-color graphics mode
        int     10h             ;BIOS video interrupt
;
; Change CPU addressing of video memory to linear (not odd/even,
; chain, or chain 4), to allow us to access all 256K of display
; memory. When this is done, VGA memory will look just like memory
; in modes 10h and 12h, except that each byte of display memory will
; control one 256-color pixel, with 4 adjacent pixels at any given
; address, one pixel per plane.
;
        mov     dx,SC_INDEX
        mov     al,MEMORY_MODE
        out     dx,al
        inc     dx
        in      al,dx
        and     al,not 08h      ;turn off chain 4
        or      al,04h          ;turn off odd/even
        out     dx,al
        mov     dx,GC_INDEX
        mov     al,GRAPHICS_MODE
        out     dx,al
        inc     dx
        in      al,dx
        and     al,not 10h      ;turn off odd/even
        out     dx,al
        dec     dx
        mov     al,MISCELLANEOUS
        out     dx,al
        inc     dx
        in      al,dx
        and     al,not 02h      ;turn off chain
        out     dx,al
;
; Now clear the whole screen, since the mode 13h mode set only
; cleared 64K out of the 256K of display memory. Do this before
; we switch the CRTC out of mode 13h, so we don't see garbage
; on the screen when we make the switch.
;
        CONSTANT_TO_INDEXED_REGISTER SC_INDEX,MAP_MASK,0fh
                                ;enable writes to all planes, so
                                ; we can clear 4 pixels at a time
        mov     ax,VGA_SEGMENT
        mov     es,ax
        sub     di,di
        mov     ax,di
        mov     cx,8000h        ;# of words in 64K
        cld
        rep     stosw           ;clear all of display memory
;
; Tweak the mode to 320x400 256-color mode by not scanning each
; line twice.
;
        mov     dx,CRTC_INDEX
        mov     al,MAX_SCAN_LINE
        out     dx,al
        inc     dx
        in      al,dx
        and     al,not 1fh      ;set maximum scan line = 0
        out     dx,al
        dec     dx
;
; Change CRTC scanning from doubleword mode to byte mode, allowing
; the CRTC to scan more than 64K of video data.
;
        mov     al,UNDERLINE
        out     dx,al
        inc     dx
        in      al,dx
        and     al,not 40h      ;turn off doubleword
        out     dx,al
        dec     dx
        mov     al,MODE_CONTROL
        out     dx,al
        inc     dx
        in      al,dx
        or      al,40h          ;turn on the byte mode bit, so memory is
                                ; scanned for video data in a purely
                                ; linear way, just as in modes 10h and 12h
        out     dx,al
        ret
Set320By400Mode endp
;
; Draws a full screen of slanting color bars in the specified page.
;
; Input:
;       DI = page start address
;       BL = 1 to make the bars slant down and to the right, -1 to
;               make them slant down and to the left, 0 to make
;               them vertical.
;
ColorBarsUp     proc    near
        mov     ax,VGA_SEGMENT
        mov     es,ax           ;point to display memory
        sub     bh,bh           ;start with color 0
        mov     si,SCREEN_HEIGHT;# of rows to do
        mov     dx,SC_INDEX
        mov     al,MAP_MASK
        out     dx,al           ;point the SC Index reg to the Map Mask reg
        inc     dx              ;point DX to the SC Data register
RowLoop:
        mov     cx,SCREEN_WIDTH/4
                                ;there are 4 pixels at each address, so
                                ; each 320-pixel row is 80 bytes wide
                                ; in each plane
        push    bx              ;save the row-start color
ColumnLoop:
MAP_SELECT = 1
        rept    4               ;do all 4 pixels at this address with
                                ; in-line code
        mov     al,MAP_SELECT
        out     dx,al           ;select planes 0, 1, 2, and 3 in turn
        mov     es:[di],bh      ;write this plane's pixel
        inc     bh              ;set the color for the next pixel
MAP_SELECT = MAP_SELECT shl 1
        endm
        inc     di              ;point to the address containing the next
                                ; 4 pixels
        loop    ColumnLoop ;do any remaining pixels on this line
        pop     bx              ;get back the row-start color
        add     bh,bl           ;select next row-start color (controls
                                ; slanting of color bars)
        dec     si              ;count down lines on the screen
        jnz     RowLoop
        ret
ColorBarsUp     endp
;
; Waits for the next key and returns it in AX.
;
GetNextKey      proc    near
WaitKey:
        mov     ah,1
        int     16h
        jz      WaitKey         ;wait for a key to become available
        sub     ah,ah
        int     16h             ;read the key
        ret
GetNextKey      endp
;
Code    ends
;
        end     Start
