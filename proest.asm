;NOTE
; pointer to start of input (located in SRAM):	r25:r24
; pointer to start of SRAM:						r23:r22

; global
.def round		= r0
.def tmp		= r21

; subRows
.def byte		= r16
.def row		= r17
.def p			= r18
.def q			= r19
.def a			= r26
.def b			= r27
.def c			= r28
.def d			= r29

; mixSlices
.def byte		= r16
.def res		= r17

; shiftPlanes
.def counter	= r16
.def reg1		= r17
.def reg2		= r18
.def reg3		= r19
.def reg4		= r20

; addConstants
.def counter	= r16
.def con1		= r17
.def con2		= r18
.def con3		= r19
.def con4		= r20


;################################################### SIMULATION ###################################################

; address where input data will be stored
.equ datastore = 0x0060

; define 64 byte input data
input:
	.db 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07
	.db 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F
	.db 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17
	.db 0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F
	.db 0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27
	.db 0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x2D, 0x2E, 0x2F
	.db 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37
	.db 0x38, 0x39, 0x3A, 0x3B, 0x3C, 0x3D, 0x3E, 0x3F

; stack initialization
ldi		r16, high( ramend )
out		sph, r16

ldi		r16, low( ramend )
out		spl, r16

; load address of input data in program memory into z-pointer
ldi		zl, low( input << 1 )
ldi		zh, high( input << 1 )

; load address of SRAM where input data will be placed into r25:r24
ldi		r24, low( datastore )
ldi		r25, high( datastore )

; load input data from program memory into SRAM
mov		yl, r24
mov		yh, r25

ldi		r17, 64

init_loop:
	lpm		r16, z+
	st		y+, r16
	dec		r17
	brne	init_loop

; set pointer to free SRAM
mov		r22, yl
mov		r23, yh

;################################################### flow control ###################################################

Project_permute:

	clr		round

	perform_permutation:
		call	subRows
		call	mixSlices
		call	shiftPlanes
		call	addConstants

		inc		round

		ldi		tmp, 18
		eor		tmp, round
		brne	perform_permutation

done:
	jmp		done


; ################################################################## subRows ##################################################################

subRows:
	; clear row and byte counter
	ldi		row, 4
	ldi		byte, 4

	; let z-pointer point to the start of the input data
	mov		zl, r24
	mov		zh, r25

	subRows_processing:
		ld		a, z				; load a (p), b (q), c and d
		ldd		b, z+4
		ldd		c, z+8
		ldd		d, z+12
		mov		p, a
		mov		q, b
		;--------------------------------------------------

		and		a, q				; a = p and q
		eor		a, c				; a = c xor (p and q)
		st		z, a
		;--------------------------------------------------

		and		b, c				; b = q and c
		eor		b, d				; b = d xor (q and c)
		std		z+4, b
		;--------------------------------------------------

		mov		c, a				; c = a and b
		and		c, b
		eor		c, p				; c = p xor (a and b)
		std		z+8, c
		;--------------------------------------------------

		mov		d, b				; d = b and c
		and		d, c
		eor		d, q				; d = q xor (b and c)
		std		z+12, d
		;--------------------------------------------------

		adiw	z, 1				; increment z-pointer

		dec		byte				; decrement byte counter

		brne	subRows_processing	; process next byte in current row
		;--------------------------------------------------

		ldi		byte, 4				; reset byte counter
		adiw	z, 0x0C				; set z-pointer to next row

		dec		row					; increment row counter

		brne	subRows_processing	; process next row

	ret


; ################################################################# mixSlices #################################################################

mixSlices:
	; initialize byte counter
	ldi		byte, 4

	; let z-pointer point to the start of the input data
	mov		zl, r24
	mov		zh, r25	

	; let y-pointer point to start of free SRAM
	mov		yl, r22
	mov		yh, r23

	call	mixSlices_processing		; first byte of lane
	call	mixSlices_processing		; second byte of lane
	call	mixSlices_processing		; third byte of lane
										; fourth byte of lane [no call needed]

	mixSlices_processing:
		;
		; multiplication of state with MDS matrix
		;

		; 1000100100101011
		ld		res, z
		ldd		tmp, z+16
		eor		res, tmp
		ldd		tmp, z+28
		eor		res, tmp
		ldd		tmp, z+40
		eor		res, tmp
		ldd		tmp, z+48
		eor		res, tmp
		ldd		tmp, z+56
		eor		res, tmp
		ldd		tmp, z+60
		eor		res, tmp

		st		y, res					; store in S_0,0
		;--------------------------------------------------

		; 0100100000011001
		ldd		res, z+4
		ldd		tmp, z+16
		eor		res, tmp
		ldd		tmp, z+44
		eor		res, tmp
		ldd		tmp, z+48
		eor		res, tmp
		ldd		tmp, z+60
		eor		res, tmp

		std		y+4, res				; store in S_0,1
		;--------------------------------------------------

		; 0010010011001000
		ldd		res, z+8
		ldd		tmp, z+20
		eor		res, tmp
		ldd		tmp, z+32
		eor		res, tmp
		ldd		tmp, z+36
		eor		res, tmp
		ldd		tmp, z+48
		eor		res, tmp

		std		y+8, res				; store in S_0,2
		;--------------------------------------------------

		; 0001001001100100
		ldd		res, z+12
		ldd		tmp, z+24
		eor		res, tmp
		ldd		tmp, z+36
		eor		res, tmp
		ldd		tmp, z+40
		eor		res, tmp
		ldd		tmp, z+52
		eor		res, tmp

		std		y+12, res				; store in S_0,3
		;--------------------------------------------------

		; 1001100010110010
		ld		res, z
		ldd		tmp, z+12
		eor		res, tmp
		ldd		tmp, z+16
		eor		res, tmp
		ldd		tmp, z+32
		eor		res, tmp
		ldd		tmp, z+40
		eor		res, tmp
		ldd		tmp, z+44
		eor		res, tmp
		ldd		tmp, z+56
		eor		res, tmp

		std		y+16, res				; store in S_1,0
		;--------------------------------------------------

		; 1000010010010001
		ld		res, z
		ldd		tmp, z+20
		eor		res, tmp
		ldd		tmp, z+32
		eor		res, tmp
		ldd		tmp, z+44
		eor		res, tmp
		ldd		tmp, z+60
		eor		res, tmp

		std		y+20, res				; store in S_1,1
		;--------------------------------------------------
	
		; 0100001010001100
		ldd		res, z+4
		ldd		tmp, z+24
		eor		res, tmp
		ldd		tmp, z+32
		eor		res, tmp
		ldd		tmp, z+48
		eor		res, tmp
		ldd		tmp, z+52
		eor		res, tmp

		std		y+24, res				; store in S_1,2
		;--------------------------------------------------

		; 0010000101000110
		ldd		res, z+8
		ldd		tmp, z+28
		eor		res, tmp
		ldd		tmp, z+36
		eor		res, tmp
		ldd		tmp, z+52
		eor		res, tmp
		ldd		tmp, z+56
		eor		res, tmp

		std		y+28, res				; store in S_1,3
		;--------------------------------------------------

		; 0010101110001001
		ldd		res, z+8
		ldd		tmp, z+16
		eor		res, tmp
		ldd		tmp, z+24
		eor		res, tmp
		ldd		tmp, z+28
		eor		res, tmp
		ldd		tmp, z+32
		eor		res, tmp
		ldd		tmp, z+48
		eor		res, tmp
		ldd		tmp, z+60
		eor		res, tmp

		std		y+32, res				; store in S_2,0
		;--------------------------------------------------

		; 0001100101001000
		ldd		res, z+12
		ldd		tmp, z+16
		eor		res, tmp
		ldd		tmp, z+28
		eor		res, tmp
		ldd		tmp, z+36
		eor		res, tmp
		ldd		tmp, z+48
		eor		res, tmp

		std		y+36, res				; store in S_2,1
		;--------------------------------------------------

		; 1100100000100100
		ld		res, z
		ldd		tmp, z+4
		eor		res, tmp
		ldd		tmp, z+16
		eor		res, tmp
		ldd		tmp, z+40
		eor		res, tmp
		ldd		tmp, z+52
		eor		res, tmp

		std		y+40, res				; store in S_2,2
		;--------------------------------------------------

		; 0110010000010010
		ldd		res, z+4
		ldd		tmp, z+8
		eor		res, tmp
		ldd		tmp, z+20
		eor		res, tmp
		ldd		tmp, z+44
		eor		res, tmp
		ldd		tmp, z+56
		eor		res, tmp

		std		y+44, res				; store in S_2,3
		;--------------------------------------------------

		; 1011001010011000
		ld		res, z
		ldd		tmp, z+8
		eor		res, tmp
		ldd		tmp, z+12
		eor		res, tmp
		ldd		tmp, z+24
		eor		res, tmp
		ldd		tmp, z+32
		eor		res, tmp
		ldd		tmp, z+44
		eor		res, tmp
		ldd		tmp, z+48
		eor		res, tmp

		std		y+48, res				; store in S_3,0
		;--------------------------------------------------

		; 1001000110000100
		ld		res, z
		ldd		tmp, z+12
		eor		res, tmp
		ldd		tmp, z+28
		eor		res, tmp
		ldd		tmp, z+32
		eor		res, tmp
		ldd		tmp, z+52
		eor		res, tmp

		std		y+52, res				; store in S_3,1
		;--------------------------------------------------

		; 1000110001000010
		ld		res, z
		ldd		tmp, z+16
		eor		res, tmp
		ldd		tmp, z+20
		eor		res, tmp
		ldd		tmp, z+36
		eor		res, tmp
		ldd		tmp, z+56
		eor		res, tmp

		std		y+56, res				; store in S_3,2
		;--------------------------------------------------

		; 0100011000100001
		ldd		res, z+4
		ldd		tmp, z+20
		eor		res, tmp
		ldd		tmp, z+24
		eor		res, tmp
		ldd		tmp, z+40
		eor		res, tmp
		ldd		tmp, z+60
		eor		res, tmp

		std		y+60, res				; store in S_3,3
		;--------------------------------------------------

		adiw	y, 0x01					; increment pointer to new state
		adiw	z, 0x01					; increment pointer to current state

		dec		byte					; decrement byte counter

		breq	mixSlices_updateState	; update state if byte counter is zero

		ret

	mixSlices_updateState:
		; let z-pointer point to the start of the input data
		mov		zl, r24
		mov		zh, r25	

		; let y-pointer point to start of free SRAM
		mov		yl, r22
		mov		yh, r23

		ldi		byte, 64

		; update the state
		mixSlices_updateState_loop:
			ld		tmp, y+
			st		z+, tmp

			dec		byte
			brne	mixSlices_updateState_loop

	ret


; ################################################################ shiftPlanes ################################################################

shiftPlanes:
	; let z-pointer point to the start of the input data
	mov		zl, r24
	mov		zh, r25

	mov		tmp, round				; determine even or odd round
	andi	tmp, 0x01
	brne	shiftPlanes_odd

	call	shiftPlanes_even

	ret

	shiftPlanes_odd:
	; shifts in odd round: 1, 24, 26, 31

		eor		tmp, tmp			; clear the tmp register

		; rotate right lane S_0,0 by 1 bit
		ld		reg1, z
		ldd		reg2, z+1
		ldd		reg3, z+2
		ldd		reg4, z+3

		lsr		reg4
		ror		reg3
		ror		reg2
		ror		reg1

		brcc	shiftPlanes_odd_1_noCarry_S00
		ori		reg4, 0x80

		shiftPlanes_odd_1_noCarry_S00:

		st		z, reg1
		std		z+1, reg2
		std		z+2, reg3
		std		z+3, reg4

		; rotate right lane S_0,1 by 1 bit
		ldd		reg1, z+4
		ldd		reg2, z+5
		ldd		reg3, z+6
		ldd		reg4, z+7

		lsr		reg4
		ror		reg3
		ror		reg2
		ror		reg1

		brcc	shiftPlanes_odd_1_noCarry_S01
		ori		reg4, 0x80

		shiftPlanes_odd_1_noCarry_S01:

		std		z+4, reg1
		std		z+5, reg2
		std		z+6, reg3
		std		z+7, reg4

		; rotate right lane S_0,2 by 1 bit
		ldd		reg1, z+8
		ldd		reg2, z+9
		ldd		reg3, z+10
		ldd		reg4, z+11

		lsr		reg4
		ror		reg3
		ror		reg2
		ror		reg1

		brcc	shiftPlanes_odd_1_noCarry_S02
		ori		reg4, 0x80

		shiftPlanes_odd_1_noCarry_S02:

		std		z+8, reg1
		std		z+9, reg2
		std		z+10, reg3
		std		z+11, reg4

		; rotate right lane S_0,3 by 1 bit
		ldd		reg1, z+12
		ldd		reg2, z+13
		ldd		reg3, z+14
		ldd		reg4, z+15

		lsr		reg4
		ror		reg3
		ror		reg2
		ror		reg1

		brcc	shiftPlanes_odd_1_noCarry_S03
		ori		reg4, 0x80

		shiftPlanes_odd_1_noCarry_S03:

		std		z+12, reg1
		std		z+13, reg2
		std		z+14, reg3
		std		z+15, reg4
		;----------------------------------------------------

		; rotate right lane S_1,0 by 24 bits (= 8 bits left)
		ldi		counter, 8
		
		ldd		reg1, z+16
		ldd		reg2, z+17
		ldd		reg3, z+18
		ldd		reg4, z+19

		shiftPlanes_odd_24_S10:
			lsl		reg1
			rol		reg2
			rol		reg3
			rol		reg4

			adc		reg1, tmp

			dec		counter
			brne	shiftPlanes_odd_24_S10

		std		z+16, reg1
		std		z+17, reg2
		std		z+18, reg3
		std		z+19, reg4

		; rotate right lane S_1,1 by 24 bits (= 8 bits left)
		ldi		counter, 8
		
		ldd		reg1, z+20
		ldd		reg2, z+21
		ldd		reg3, z+22
		ldd		reg4, z+23

		shiftPlanes_odd_24_S11:
			lsl		reg1
			rol		reg2
			rol		reg3
			rol		reg4

			adc		reg1, tmp

			dec		counter
			brne	shiftPlanes_odd_24_S11

		std		z+20, reg1
		std		z+21, reg2
		std		z+22, reg3
		std		z+23, reg4

		; rotate right lane S_1,2 by 24 bits (= 8 bits left)
		ldi		counter, 8
		
		ldd		reg1, z+24
		ldd		reg2, z+25
		ldd		reg3, z+26
		ldd		reg4, z+27

		shiftPlanes_odd_24_S12:
			lsl		reg1
			rol		reg2
			rol		reg3
			rol		reg4

			adc		reg1, tmp

			dec		counter
			brne	shiftPlanes_odd_24_S12

		std		z+24, reg1
		std		z+25, reg2
		std		z+26, reg3
		std		z+27, reg4

		; rotate right lane S_1,3 by 24 bits (= 8 bits left)
		ldi		counter, 8
		
		ldd		reg1, z+28
		ldd		reg2, z+29
		ldd		reg3, z+30
		ldd		reg4, z+31

		shiftPlanes_odd_24_S13:
			lsl		reg1
			rol		reg2
			rol		reg3
			rol		reg4

			adc		reg1, tmp

			dec		counter
			brne	shiftPlanes_odd_24_S13

		std		z+28, reg1
		std		z+29, reg2
		std		z+30, reg3
		std		z+31, reg4
		;----------------------------------------------------

		; rotate right lane S_2,0 by 26 bits (= 6 bits left)
		ldi		counter, 6
		
		ldd		reg1, z+32
		ldd		reg2, z+33
		ldd		reg3, z+34
		ldd		reg4, z+35

		shiftPlanes_odd_26_S20:
			lsl		reg1
			rol		reg2
			rol		reg3
			rol		reg4

			adc		reg1, tmp

			dec		counter
			brne	shiftPlanes_odd_26_S20

		std		z+32, reg1
		std		z+33, reg2
		std		z+34, reg3
		std		z+35, reg4

		; rotate right lane S_2,1 by 26 bits (= 6 bits left)
		ldi		counter, 6
		
		ldd		reg1, z+36
		ldd		reg2, z+37
		ldd		reg3, z+38
		ldd		reg4, z+39

		shiftPlanes_odd_26_S21:
			lsl		reg1
			rol		reg2
			rol		reg3
			rol		reg4

			adc		reg1, tmp

			dec		counter
			brne	shiftPlanes_odd_26_S21

		std		z+36, reg1
		std		z+37, reg2
		std		z+38, reg3
		std		z+39, reg4

		; rotate right lane S_2,2 by 26 bits (= 6 bits left)
		ldi		counter, 6
		
		ldd		reg1, z+40
		ldd		reg2, z+41
		ldd		reg3, z+42
		ldd		reg4, z+43

		shiftPlanes_odd_26_S22:
			lsl		reg1
			rol		reg2
			rol		reg3
			rol		reg4

			adc		reg1, tmp

			dec		counter
			brne	shiftPlanes_odd_26_S22

		std		z+40, reg1
		std		z+41, reg2
		std		z+42, reg3
		std		z+43, reg4

		; rotate right lane S_2,3 by 26 bits (= 6 bits left)
		ldi		counter, 6
		
		ldd		reg1, z+44
		ldd		reg2, z+45
		ldd		reg3, z+46
		ldd		reg4, z+47

		shiftPlanes_odd_26_S23:
			lsl		reg1
			rol		reg2
			rol		reg3
			rol		reg4

			adc		reg1, tmp

			dec		counter
			brne	shiftPlanes_odd_26_S23

		std		z+44, reg1
		std		z+45, reg2
		std		z+46, reg3
		std		z+47, reg4
		;----------------------------------------------------

		; rotate right lane S_3,0 by 31 bits (= 1 bit left)
		ldd		reg1, z+48
		ldd		reg2, z+49
		ldd		reg3, z+50
		ldd		reg4, z+51

		lsl		reg1
		rol		reg2
		rol		reg3
		rol		reg4

		adc		reg1, tmp

		std		z+48, reg1
		std		z+49, reg2
		std		z+50, reg3
		std		z+51, reg4

		; rotate right lane S_3,1 by 31 bits (= 1 bit left)
		ldd		reg1, z+52
		ldd		reg2, z+53
		ldd		reg3, z+54
		ldd		reg4, z+55

		lsl		reg1
		rol		reg2
		rol		reg3
		rol		reg4

		adc		reg1, tmp

		std		z+52, reg1
		std		z+53, reg2
		std		z+54, reg3
		std		z+55, reg4

		; rotate right lane S_3,2 by 31 bits (= 1 bit left)
		ldd		reg1, z+56
		ldd		reg2, z+57
		ldd		reg3, z+58
		ldd		reg4, z+59

		lsl		reg1
		rol		reg2
		rol		reg3
		rol		reg4

		adc		reg1, tmp

		std		z+56, reg1
		std		z+57, reg2
		std		z+58, reg3
		std		z+59, reg4

		; rotate right lane S_3,3 by 31 bits (= 1 bit left)
		ldd		reg1, z+60
		ldd		reg2, z+61
		ldd		reg3, z+62
		ldd		reg4, z+63

		lsl		reg1
		rol		reg2
		rol		reg3
		rol		reg4

		adc		reg1, tmp

		std		z+60, reg1
		std		z+61, reg2
		std		z+62, reg3
		std		z+63, reg4
		;----------------------------------------------------

	ret

	shiftPlanes_even:
	; shifts in even round: 0, 4, 12, 26

		; rotate right lane S_1,0 by 4 bits
		ldi		counter, 4
		
		ldd		reg1, z+16
		ldd		reg2, z+17
		ldd		reg3, z+18
		ldd		reg4, z+19

		shiftPlanes_even_4_S10:
			lsr		reg4
			ror		reg3
			ror		reg2
			ror		reg1

			brcc	shiftPlanes_even_4_noCarry_S10
			ori		reg4, 0x80

			shiftPlanes_even_4_noCarry_S10:

			dec		counter
			brne	shiftPlanes_even_4_S10

		std		z+16, reg1
		std		z+17, reg2
		std		z+18, reg3
		std		z+19, reg4

		; rotate right lane S_1,1 by 4 bits
		ldi		counter, 4
		
		ldd		reg1, z+20
		ldd		reg2, z+21
		ldd		reg3, z+22
		ldd		reg4, z+23

		shiftPlanes_even_4_S11:
			lsr		reg4
			ror		reg3
			ror		reg2
			ror		reg1

			brcc	shiftPlanes_even_4_noCarry_S11
			ori		reg4, 0x80

			shiftPlanes_even_4_noCarry_S11:

			dec		counter
			brne	shiftPlanes_even_4_S11

		std		z+20, reg1
		std		z+21, reg2
		std		z+22, reg3
		std		z+23, reg4

		; rotate right lane S_1,2 by 4 bits
		ldi		counter, 4
		
		ldd		reg1, z+24
		ldd		reg2, z+25
		ldd		reg3, z+26
		ldd		reg4, z+27

		shiftPlanes_even_4_S12:
			lsr		reg4
			ror		reg3
			ror		reg2
			ror		reg1

			brcc	shiftPlanes_even_4_noCarry_S12
			ori		reg4, 0x80

			shiftPlanes_even_4_noCarry_S12:

			dec		counter
			brne	shiftPlanes_even_4_S12

		std		z+24, reg1
		std		z+25, reg2
		std		z+26, reg3
		std		z+27, reg4

		; rotate right lane S_1,3 by 4 bits
		ldi		counter, 4
		
		ldd		reg1, z+28
		ldd		reg2, z+29
		ldd		reg3, z+30
		ldd		reg4, z+31

		shiftPlanes_even_4_S13:
			lsr		reg4
			ror		reg3
			ror		reg2
			ror		reg1

			brcc	shiftPlanes_even_4_noCarry_S13
			ori		reg4, 0x80

			shiftPlanes_even_4_noCarry_S13:

			dec		counter
			brne	shiftPlanes_even_4_S13

		std		z+28, reg1
		std		z+29, reg2
		std		z+30, reg3
		std		z+31, reg4
		;----------------------------------------------------

		; rotate right lane S_2,0 by 12 bits
		ldi		counter, 12
		
		ldd		reg1, z+32
		ldd		reg2, z+33
		ldd		reg3, z+34
		ldd		reg4, z+35

		shiftPlanes_even_12_S20:
			lsr		reg4
			ror		reg3
			ror		reg2
			ror		reg1

			brcc	shiftPlanes_even_12_noCarry_S20
			ori		reg4, 0x80

			shiftPlanes_even_12_noCarry_S20:

			dec		counter
			brne	shiftPlanes_even_12_S20

		std		z+32, reg1
		std		z+33, reg2
		std		z+34, reg3
		std		z+35, reg4

		; rotate right lane S_2,1 by 12 bits
		ldi		counter, 12
		
		ldd		reg1, z+36
		ldd		reg2, z+37
		ldd		reg3, z+38
		ldd		reg4, z+39

		shiftPlanes_even_12_S21:
			lsr		reg4
			ror		reg3
			ror		reg2
			ror		reg1

			brcc	shiftPlanes_even_12_noCarry_S21
			ori		reg4, 0x80

			shiftPlanes_even_12_noCarry_S21:

			dec		counter
			brne	shiftPlanes_even_12_S21

		std		z+36, reg1
		std		z+37, reg2
		std		z+38, reg3
		std		z+39, reg4

		; rotate right lane S_2,2 by 12 bits
		ldi		counter, 12
		
		ldd		reg1, z+40
		ldd		reg2, z+41
		ldd		reg3, z+42
		ldd		reg4, z+43

		shiftPlanes_even_12_S22:
			lsr		reg4
			ror		reg3
			ror		reg2
			ror		reg1

			brcc	shiftPlanes_even_12_noCarry_S22
			ori		reg4, 0x80

			shiftPlanes_even_12_noCarry_S22:

			dec		counter
			brne	shiftPlanes_even_12_S22

		std		z+40, reg1
		std		z+41, reg2
		std		z+42, reg3
		std		z+43, reg4

		; rotate right lane S_2,3 by 12 bits
		ldi		counter, 12
		
		ldd		reg1, z+44
		ldd		reg2, z+45
		ldd		reg3, z+46
		ldd		reg4, z+47

		shiftPlanes_even_12_S23:
			lsr		reg4
			ror		reg3
			ror		reg2
			ror		reg1

			brcc	shiftPlanes_even_12_noCarry_S23
			ori		reg4, 0x80

			shiftPlanes_even_12_noCarry_S23:

			dec		counter
			brne	shiftPlanes_even_12_S23

		std		z+44, reg1
		std		z+45, reg2
		std		z+46, reg3
		std		z+47, reg4
		;----------------------------------------------------

		; rotate right lane S_3,0 by 26 bits (=6 bits left)
		ldi		counter, 6
		
		ldd		reg1, z+48
		ldd		reg2, z+49
		ldd		reg3, z+50
		ldd		reg4, z+51

		shiftPlanes_even_26_S30:
			lsl		reg1
			rol		reg2
			rol		reg3
			rol		reg4

			adc		reg1, tmp

			dec		counter
			brne	shiftPlanes_even_26_S30

		std		z+48, reg1
		std		z+49, reg2
		std		z+50, reg3
		std		z+51, reg4

		; rotate right lane S_3,1 by 26 bits (=6 bits left)
		ldi		counter, 6
		
		ldd		reg1, z+52
		ldd		reg2, z+53
		ldd		reg3, z+54
		ldd		reg4, z+55

		shiftPlanes_even_26_S31:
			lsl		reg1
			rol		reg2
			rol		reg3
			rol		reg4

			adc		reg1, tmp

			dec		counter
			brne	shiftPlanes_even_26_S31

		std		z+52, reg1
		std		z+53, reg2
		std		z+54, reg3
		std		z+55, reg4

		; rotate right lane S_3,2 by 26 bits (=6 bits left)
		ldi		counter, 6
		
		ldd		reg1, z+56
		ldd		reg2, z+57
		ldd		reg3, z+58
		ldd		reg4, z+59

		shiftPlanes_even_26_S32:
			lsl		reg1
			rol		reg2
			rol		reg3
			rol		reg4

			adc		reg1, tmp

			dec		counter
			brne	shiftPlanes_even_26_S32

		std		z+56, reg1
		std		z+57, reg2
		std		z+58, reg3
		std		z+59, reg4

		; rotate right lane S_3,3 by 26 bits (=6 bits left)
		ldi		counter, 6
		
		ldd		reg1, z+60
		ldd		reg2, z+61
		ldd		reg3, z+62
		ldd		reg4, z+63

		shiftPlanes_even_26_S33:
			lsl		reg1
			rol		reg2
			rol		reg3
			rol		reg4

			adc		reg1, tmp

			dec		counter
			brne	shiftPlanes_even_26_S33

		std		z+60, reg1
		std		z+61, reg2
		std		z+62, reg3
		std		z+63, reg4

	ret


; ################################################################ addConstants ################################################################

addConstants:
	; let z-pointer point to the start of the input data
	mov		zl, r24
	mov		zh, r25

	; process lane S_0,0 (using constant C0)
	ldi		con1, 0x75
	ldi		con2, 0x81
	ldi		con3, 0x7B
	ldi		con4, 0x9D

	tst		round						; skip rotation in round 0
	breq	addConstants_noRotate_S00

	mov		counter, round
	eor		tmp, tmp

	addConstants_rotate_S00:
		lsl		con4
		rol		con3
		rol		con2
		rol		con1

		adc		con4, tmp

		dec		counter
		brne	addConstants_rotate_S00

	addConstants_noRotate_S00:
		ld		tmp, z
		eor		tmp, con4
		st		z+, tmp
		ld		tmp, z
		eor		tmp, con3
		st		z+, tmp
		ld		tmp, z
		eor		tmp, con2
		st		z+, tmp
		ld		tmp, z
		eor		tmp, con1
		st		z+, tmp
	;----------------------------------------------------

	; process lane S_0,1 (using constant C1)
	ldi		con1, 0xB2
	ldi		con2, 0xC5
	ldi		con3, 0xFE
	ldi		con4, 0xF0

	mov		counter, round
	ldi		tmp, 0x01
	add		counter, tmp

	eor		tmp, tmp

	addConstants_rotate_S01:
		lsl		con4
		rol		con3
		rol		con2
		rol		con1

		adc		con4, tmp

		dec		counter
		brne	addConstants_rotate_S01

	ld		tmp, z
	eor		tmp, con4
	st		z+, tmp
	ld		tmp, z
	eor		tmp, con3
	st		z+, tmp
	ld		tmp, z
	eor		tmp, con2
	st		z+, tmp
	ld		tmp, z
	eor		tmp, con1
	st		z+, tmp
	;----------------------------------------------------

	; process lane S_0,2 (using constant C0)
	ldi		con1, 0x75
	ldi		con2, 0x81
	ldi		con3, 0x7B
	ldi		con4, 0x9D

	mov		counter, round
	ldi		tmp, 0x02
	add		counter, tmp

	eor		tmp, tmp

	addConstants_rotate_S02:
		lsl		con4
		rol		con3
		rol		con2
		rol		con1

		adc		con4, tmp

		dec		counter
		brne	addConstants_rotate_S02

	ld		tmp, z
	eor		tmp, con4
	st		z+, tmp
	ld		tmp, z
	eor		tmp, con3
	st		z+, tmp
	ld		tmp, z
	eor		tmp, con2
	st		z+, tmp
	ld		tmp, z
	eor		tmp, con1
	st		z+, tmp
	;----------------------------------------------------

	; process lane S_0,3 (using constant C1)
	ldi		con1, 0xB2
	ldi		con2, 0xC5
	ldi		con3, 0xFE
	ldi		con4, 0xF0

	mov		counter, round
	ldi		tmp, 0x03
	add		counter, tmp

	eor		tmp, tmp

	addConstants_rotate_S03:
		lsl		con4
		rol		con3
		rol		con2
		rol		con1

		adc		con4, tmp

		dec		counter
		brne	addConstants_rotate_S03

	ld		tmp, z
	eor		tmp, con4
	st		z+, tmp
	ld		tmp, z
	eor		tmp, con3
	st		z+, tmp
	ld		tmp, z
	eor		tmp, con2
	st		z+, tmp
	ld		tmp, z
	eor		tmp, con1
	st		z+, tmp
	;--------------------------------------------------------------------------------------------------------

	; process lane S_1,0 (using constant C0)
	ldi		con1, 0x75
	ldi		con2, 0x81
	ldi		con3, 0x7B
	ldi		con4, 0x9D

	mov		counter, round
	ldi		tmp, 0x04
	add		counter, tmp

	eor		tmp, tmp

	addConstants_rotate_S10:
		lsl		con4
		rol		con3
		rol		con2
		rol		con1

		adc		con4, tmp

		dec		counter
		brne	addConstants_rotate_S10

	ld		tmp, z
	eor		tmp, con4
	st		z+, tmp
	ld		tmp, z
	eor		tmp, con3
	st		z+, tmp
	ld		tmp, z
	eor		tmp, con2
	st		z+, tmp
	ld		tmp, z
	eor		tmp, con1
	st		z+, tmp
	;----------------------------------------------------

	; process lane S_1,1 (using constant C1)
	ldi		con1, 0xB2
	ldi		con2, 0xC5
	ldi		con3, 0xFE
	ldi		con4, 0xF0

	mov		counter, round
	ldi		tmp, 0x05
	add		counter, tmp

	eor		tmp, tmp

	addConstants_rotate_S11:
		lsl		con4
		rol		con3
		rol		con2
		rol		con1

		adc		con4, tmp

		dec		counter
		brne	addConstants_rotate_S11

	ld		tmp, z
	eor		tmp, con4
	st		z+, tmp
	ld		tmp, z
	eor		tmp, con3
	st		z+, tmp
	ld		tmp, z
	eor		tmp, con2
	st		z+, tmp
	ld		tmp, z
	eor		tmp, con1
	st		z+, tmp
	;----------------------------------------------------

	; process lane S_1,2 (using constant C0)
	ldi		con1, 0x75
	ldi		con2, 0x81
	ldi		con3, 0x7B
	ldi		con4, 0x9D

	mov		counter, round
	ldi		tmp, 0x06
	add		counter, tmp

	eor		tmp, tmp

	addConstants_rotate_S12:
		lsl		con4
		rol		con3
		rol		con2
		rol		con1

		adc		con4, tmp

		dec		counter
		brne	addConstants_rotate_S12

	ld		tmp, z
	eor		tmp, con4
	st		z+, tmp
	ld		tmp, z
	eor		tmp, con3
	st		z+, tmp
	ld		tmp, z
	eor		tmp, con2
	st		z+, tmp
	ld		tmp, z
	eor		tmp, con1
	st		z+, tmp
	;----------------------------------------------------

	; process lane S_1,3 (using constant C1)
	ldi		con1, 0xB2
	ldi		con2, 0xC5
	ldi		con3, 0xFE
	ldi		con4, 0xF0

	mov		counter, round
	ldi		tmp, 0x07
	add		counter, tmp

	eor		tmp, tmp

	addConstants_rotate_S13:
		lsl		con4
		rol		con3
		rol		con2
		rol		con1

		adc		con4, tmp

		dec		counter
		brne	addConstants_rotate_S13

	ld		tmp, z
	eor		tmp, con4
	st		z+, tmp
	ld		tmp, z
	eor		tmp, con3
	st		z+, tmp
	ld		tmp, z
	eor		tmp, con2
	st		z+, tmp
	ld		tmp, z
	eor		tmp, con1
	st		z+, tmp
	;--------------------------------------------------------------------------------------------------------

	; process lane S_2,0 (using constant C0)
	ldi		con1, 0x75
	ldi		con2, 0x81
	ldi		con3, 0x7B
	ldi		con4, 0x9D

	mov		counter, round
	ldi		tmp, 0x08
	add		counter, tmp

	eor		tmp, tmp

	addConstants_rotate_S20:
		lsl		con4
		rol		con3
		rol		con2
		rol		con1

		adc		con4, tmp

		dec		counter
		brne	addConstants_rotate_S20

	ld		tmp, z
	eor		tmp, con4
	st		z+, tmp
	ld		tmp, z
	eor		tmp, con3
	st		z+, tmp
	ld		tmp, z
	eor		tmp, con2
	st		z+, tmp
	ld		tmp, z
	eor		tmp, con1
	st		z+, tmp
	;----------------------------------------------------

	; process lane S_2,1 (using constant C1)
	ldi		con1, 0xB2
	ldi		con2, 0xC5
	ldi		con3, 0xFE
	ldi		con4, 0xF0

	mov		counter, round
	ldi		tmp, 0x09
	add		counter, tmp

	eor		tmp, tmp

	addConstants_rotate_S21:
		lsl		con4
		rol		con3
		rol		con2
		rol		con1

		adc		con4, tmp

		dec		counter
		brne	addConstants_rotate_S21

	ld		tmp, z
	eor		tmp, con4
	st		z+, tmp
	ld		tmp, z
	eor		tmp, con3
	st		z+, tmp
	ld		tmp, z
	eor		tmp, con2
	st		z+, tmp
	ld		tmp, z
	eor		tmp, con1
	st		z+, tmp
	;----------------------------------------------------

	; process lane S_2,2 (using constant C0)
	ldi		con1, 0x75
	ldi		con2, 0x81
	ldi		con3, 0x7B
	ldi		con4, 0x9D

	mov		counter, round
	ldi		tmp, 0x0A
	add		counter, tmp

	eor		tmp, tmp

	addConstants_rotate_S22:
		lsl		con4
		rol		con3
		rol		con2
		rol		con1

		adc		con4, tmp

		dec		counter
		brne	addConstants_rotate_S22

	ld		tmp, z
	eor		tmp, con4
	st		z+, tmp
	ld		tmp, z
	eor		tmp, con3
	st		z+, tmp
	ld		tmp, z
	eor		tmp, con2
	st		z+, tmp
	ld		tmp, z
	eor		tmp, con1
	st		z+, tmp
	;----------------------------------------------------

	; process lane S_2,3 (using constant C1)
	ldi		con1, 0xB2
	ldi		con2, 0xC5
	ldi		con3, 0xFE
	ldi		con4, 0xF0

	mov		counter, round
	ldi		tmp, 0x0B
	add		counter, tmp

	eor		tmp, tmp

	addConstants_rotate_S23:
		lsl		con4
		rol		con3
		rol		con2
		rol		con1

		adc		con4, tmp

		dec		counter
		brne	addConstants_rotate_S23

	ld		tmp, z
	eor		tmp, con4
	st		z+, tmp
	ld		tmp, z
	eor		tmp, con3
	st		z+, tmp
	ld		tmp, z
	eor		tmp, con2
	st		z+, tmp
	ld		tmp, z
	eor		tmp, con1
	st		z+, tmp
	;--------------------------------------------------------------------------------------------------------

	; process lane S_3,0 (using constant C0)
	ldi		con1, 0x75
	ldi		con2, 0x81
	ldi		con3, 0x7B
	ldi		con4, 0x9D

	mov		counter, round
	ldi		tmp, 0x0C
	add		counter, tmp

	eor		tmp, tmp

	addConstants_rotate_S30:
		lsl		con4
		rol		con3
		rol		con2
		rol		con1

		adc		con4, tmp

		dec		counter
		brne	addConstants_rotate_S30

	ld		tmp, z
	eor		tmp, con4
	st		z+, tmp
	ld		tmp, z
	eor		tmp, con3
	st		z+, tmp
	ld		tmp, z
	eor		tmp, con2
	st		z+, tmp
	ld		tmp, z
	eor		tmp, con1
	st		z+, tmp
	;----------------------------------------------------

	; process lane S_3,1 (using constant C1)
	ldi		con1, 0xB2
	ldi		con2, 0xC5
	ldi		con3, 0xFE
	ldi		con4, 0xF0

	mov		counter, round
	ldi		tmp, 0x0D
	add		counter, tmp

	eor		tmp, tmp

	addConstants_rotate_S31:
		lsl		con4
		rol		con3
		rol		con2
		rol		con1

		adc		con4, tmp

		dec		counter
		brne	addConstants_rotate_S31

	ld		tmp, z
	eor		tmp, con4
	st		z+, tmp
	ld		tmp, z
	eor		tmp, con3
	st		z+, tmp
	ld		tmp, z
	eor		tmp, con2
	st		z+, tmp
	ld		tmp, z
	eor		tmp, con1
	st		z+, tmp
	;----------------------------------------------------

	; process lane S_3,2 (using constant C0)
	ldi		con1, 0x75
	ldi		con2, 0x81
	ldi		con3, 0x7B
	ldi		con4, 0x9D

	mov		counter, round
	ldi		tmp, 0x0E
	add		counter, tmp

	eor		tmp, tmp

	addConstants_rotate_S32:
		lsl		con4
		rol		con3
		rol		con2
		rol		con1

		adc		con4, tmp

		dec		counter
		brne	addConstants_rotate_S32

	ld		tmp, z
	eor		tmp, con4
	st		z+, tmp
	ld		tmp, z
	eor		tmp, con3
	st		z+, tmp
	ld		tmp, z
	eor		tmp, con2
	st		z+, tmp
	ld		tmp, z
	eor		tmp, con1
	st		z+, tmp
	;----------------------------------------------------

	; process lane S_3,3 (using constant C1)
	ldi		con1, 0xB2
	ldi		con2, 0xC5
	ldi		con3, 0xFE
	ldi		con4, 0xF0

	mov		counter, round
	ldi		tmp, 0x0F
	add		counter, tmp

	eor		tmp, tmp

	addConstants_rotate_S33:
		lsl		con4
		rol		con3
		rol		con2
		rol		con1

		adc		con4, tmp

		dec		counter
		brne	addConstants_rotate_S33

	addConstants_noRotate_S33:
		ld		tmp, z
		eor		tmp, con4
		st		z+, tmp
		ld		tmp, z
		eor		tmp, con3
		st		z+, tmp
		ld		tmp, z
		eor		tmp, con2
		st		z+, tmp
		ld		tmp, z
		eor		tmp, con1
		st		z+, tmp
	;--------------------------------------------------------------------------------------------------------

	ret
