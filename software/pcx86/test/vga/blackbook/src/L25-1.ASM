; Program to illustrate operation of data rotate and bit mask
;  features of Graphics Controller. Draws 8x8 character at
;  specified location, using VGA's 8x8 ROM font. Designed
;  for use with modes 0Dh, 0Eh, 0Fh, 10h, and 12h.
; By Michael Abrash.
;
stack	segment para stack 'STACK'
	db	512 dup(?)
stack	ends
;
VGA_VIDEO_SEGMENT	equ	0a000h	;VGA display memory segment
SCREEN_WIDTH_IN_BYTES	equ	044ah	;offset of BIOS variable
FONT_CHARACTER_SIZE	equ	8	;# bytes in each font char
;
; VGA register equates.
;
GC_INDEX	equ	3ceh	;GC index register
GC_ROTATE	equ	3	;GC data rotate/logical function
				; register index
GC_BIT_MASK	equ	8	;GC bit mask register index
;
dseg	segment para common 'DATA'
TEST_TEXT_ROW	equ	69	;row to display test text at
TEST_TEXT_COL	equ	17	;column to display test text at
TEST_TEXT_WIDTH equ	8	;width of a character in pixels

TestString	label	byte
	db	'Hello, world!',0       ;test string to print.
FontPointer	dd	?		;font offset
dseg	ends
;
; Macro to set indexed register INDEX of GC chip to SETTING.
;
SETGC	macro	INDEX, SETTING
	mov	dx,GC_INDEX
	mov	ax,(SETTING SHL 8) OR INDEX
	out	dx,ax
	endm
;
cseg	segment para public 'CODE'
	assume	cs:cseg, ds:dseg
start	proc	near
	mov	ax,dseg
	mov	ds,ax
;
; Select 640x480 graphics mode.
;
	mov	ax,012h
	int	10h
;
; Set driver to use the 8x8 font.
;
	mov	ah,11h		;VGA BIOS character generator function,
	mov	al,30h		; return info subfunction
	mov	bh,3		;get 8x8 font pointer
	int	10h
	call	SelectFont
;
; Print the test string.
;
	mov	si,offset TestString
	mov	bx,TEST_TEXT_ROW
	mov	cx,TEST_TEXT_COL
StringOutLoop:
	lodsb
	and	al,al
	jz	StringOutDone
	call	DrawChar
	add	cx,TEST_TEXT_WIDTH
	jmp	StringOutLoop
StringOutDone:
;
; Reset the data rotate and bit mask registers.
;
	SETGC	GC_ROTATE, 0
	SETGC	GC_BIT_MASK, 0ffh
;
; Wait for a keystroke.
;
	mov	ah,1
	int	21h
;
; Return to text mode.
;
	mov	ax,03h
	int	10h
;
; Exit to DOS.
;
	mov	ah,4ch
	int	21h
Start	endp
;
; Subroutine to draw a text character in a linear graphics mode
;  (0Dh, 0Eh, 0Fh, 010h, 012h).
; Font used should be pointed to by FontPointer.
;
; Input:
;  AL = character to draw
;  BX = row to draw text character at
;  CX = column to draw text character at
;
;  Forces ALU function to "move".
;
DrawChar	proc	near
	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	push	bp
	push	ds
;
; Set DS:SI to point to font and ES to point to display memory.
;
	lds	si,[FontPointer]	;point to font
	mov	dx,VGA_VIDEO_SEGMENT
	mov	es,dx			;point to display memory
;
; Calculate screen address of byte character starts in.
;
	push	ds	;point to BIOS data segment
	sub	dx,dx
	mov	ds,dx
	xchg	ax,bx
	mov	di,ds:[SCREEN_WIDTH_IN_BYTES]	;retrieve BIOS
						; screen width
	pop	ds
	mul	di	;calculate offset of start of row
	push	di	;set aside screen width
	mov	di,cx	;set aside the column
	and	cl,0111b;keep only the column in-byte address
	shr	di,1
	shr	di,1
	shr	di,1	;divide column by 8 to make a byte address
	add	di,ax	;and point to byte
;
; Calculate font address of character.
;
	sub	bh,bh
	shl	bx,1	;assumes 8 bytes per character; use
	shl	bx,1	; a multiply otherwise
	shl	bx,1	;offset in font of character
	add	si,bx	;offset in font segment of character
;
; Set up the GC rotation.
;
	mov	dx,GC_INDEX
	mov	al,GC_ROTATE
	mov	ah,cl
	out	dx,ax
;
; Set up BH as bit mask for left half,
; BL as rotation for right half.
;
	mov	bx,0ffffh
	shr	bh,cl
	neg	cl
	add	cl,8
	shl	bl,cl
;
; Draw the character, left half first, then right half in the
; succeeding byte, using the data rotation to position the character
; across the byte boundary and then using the bit mask to get the
; proper portion of the character into each byte.
; Does not check for case where character is byte-aligned and
; no rotation and only one write is required.
;
	mov	bp,FONT_CHARACTER_SIZE
	mov	dx,GC_INDEX
	pop	cx	;get back screen width
	dec	cx
	dec	cx	; -2 because do two bytes for each char
CharacterLoop:
;
; Set the bit mask for the left half of the character.
;
	mov	al,GC_BIT_MASK
	mov	ah,bh
	out	dx,ax
;
; Get the next character byte & write it to display memory.
; (Left half of character.)
;
	mov	al,[si]		;get character byte
	mov	ah,es:[di]	;load latches
	stosb			;write character byte
;
; Set the bit mask for the right half of the character.
;
	mov	al,GC_BIT_MASK
	mov	ah,bl
	out	dx,ax
;
; Get the character byte again & write it to display memory.
; (Right half of character.)
;
	lodsb			;get character byte
	mov	ah,es:[di]	;load latches
	stosb			;write character byte
;
; Point to next line of character in display memory.
;
	add	di,cx
;
	dec	bp
	jnz	CharacterLoop
;
	pop	ds
	pop	bp
	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
DrawChar	endp
;
; Set the pointer to the font to draw from to ES:BP.
;
SelectFont	proc	near
	mov	word ptr [FontPointer],bp	;save pointer
	mov	word ptr [FontPointer+2],es
	ret
SelectFont	endp
;
cseg	ends
	end	start
