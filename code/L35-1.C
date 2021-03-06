/*
 * C implementation of Bresenham's line drawing algorithm
 * for the EGA and VGA. Works in modes 0xE, 0xF, 0x10, and 0x12.
 *
 * Compiled with Borland C++
 *
 * By Michael Abrash
 */

#include <dos.h>     		/* contains MK_FP macro */

#define EVGA_SCREEN_WIDTH_IN_BYTES     80
                                       /* memory offset from start of
                                          one row to start of next */
#define EVGA_SCREEN_SEGMENT            0xA000
                                       /* display memory segment */
#define GC_INDEX                       0x3CE
                                       /* Graphics Controller
                                          Index register port */
#define GC_DATA                        0x3CF
                                       /* Graphics Controller
                                          Data register port */
#define SET_RESET_INDEX                0  /* indexes of needed */
#define ENABLE_SET_RESET_INDEX         1  /* Graphics Controller */
#define BIT_MASK_INDEX                 8  /* registers */

/*
 * Draws a dot at (X0,Y0) in whatever color the EGA/VGA hardware is
 * set up for. Leaves the bit mask set to whatever value the
 * dot required.
 */
void EVGADot(X0, Y0)
unsigned int X0;     /* coordinates at which to draw dot, with */
unsigned int Y0;     /* (0,0) at the upper left of the screen */
{
	unsigned char far *PixelBytePtr;
	unsigned char PixelMask;

	/* Calculate the offset in the screen segment of the byte in
	  which the pixel lies */
	PixelBytePtr = MK_FP(EVGA_SCREEN_SEGMENT,
		( Y0 * EVGA_SCREEN_WIDTH_IN_BYTES ) + ( X0 / 8 ));

	/* Generate a mask with a 1 bit in the pixel's position within the
	  screen byte */
	PixelMask = 0x80 >> ( X0 & 0x07 );

	/* Set up the Graphics Controller's Bit Mask register to allow
	  only the bit corresponding to the pixel being drawn to
	  be modified */
	outportb(GC_INDEX, BIT_MASK_INDEX);
	outportb(GC_DATA, PixelMask);

	/* Draw the pixel. Because of the operation of the set/reset
	  feature of the EGA/VGA, the value written doesn't matter.
	  The screen byte is ORed in order to perform a read to latch the
	  display memory, then perform a write in order to modify it. */
	*PixelBytePtr |= 0xFE;
}

/*
 * Draws a line in octant 0 or 3 ( |DeltaX| >= DeltaY ).
 */
void Octant0(X0, Y0, DeltaX, DeltaY, XDirection)
unsigned int X0, Y0;          /* coordinates of start of the line */
unsigned int DeltaX, DeltaY;  /* length of the line (both > 0) */
int XDirection;               /* 1 if line is drawn left to right,
                                -1 if drawn right to left */
{
	int DeltaYx2;
	int DeltaYx2MinusDeltaXx2;
	int ErrorTerm;

	/* Set up initial error term and values used inside drawing loop */
	DeltaYx2 = DeltaY * 2;
	DeltaYx2MinusDeltaXx2 = DeltaYx2 - (int) ( DeltaX * 2 );
	ErrorTerm = DeltaYx2 - (int) DeltaX;

	/* Draw the line */
	EVGADot(X0, Y0);              /* draw the first pixel */
	while ( DeltaX-- ) {
		/* See if it's time to advance the Y coordinate */
		if ( ErrorTerm >= 0 ) {
			/* Advance the Y coordinate & adjust the error term
			back down */
			Y0++;
			ErrorTerm += DeltaYx2MinusDeltaXx2;
		} else {
			/* Add to the error term */
			ErrorTerm += DeltaYx2;
		}
		X0 += XDirection;          /* advance the X coordinate */
		EVGADot(X0, Y0);           /* draw a pixel */
	}
}

/*
 * Draws a line in octant 1 or 2 ( |DeltaX| < DeltaY ).
 */
void Octant1(X0, Y0, DeltaX, DeltaY, XDirection)
unsigned int X0, Y0;          /* coordinates of start of the line */
unsigned int DeltaX, DeltaY;  /* length of the line (both > 0) */
int XDirection;               /* 1 if line is drawn left to right,
                                -1 if drawn right to left */
{
	int DeltaXx2;
	int DeltaXx2MinusDeltaYx2;
	int ErrorTerm;

	/* Set up initial error term and values used inside drawing loop */
	DeltaXx2 = DeltaX * 2;
	DeltaXx2MinusDeltaYx2 = DeltaXx2 - (int) ( DeltaY * 2 );
	ErrorTerm = DeltaXx2 - (int) DeltaY;

	EVGADot(X0, Y0);           /* draw the first pixel */
	while ( DeltaY-- ) {
		/* See if it's time to advance the X coordinate */
		if ( ErrorTerm >= 0 ) {
			/* Advance the X coordinate & adjust the error term
			back down */
			X0 += XDirection;
			ErrorTerm += DeltaXx2MinusDeltaYx2;
		} else {
			/* Add to the error term */
			ErrorTerm += DeltaXx2;
		}
		Y0++;                   /* advance the Y coordinate */
		EVGADot(X0, Y0);        /* draw a pixel */
	}
}

/*
 * Draws a line on the EGA or VGA.
 */
void EVGALine(X0, Y0, X1, Y1, Color)
int X0, Y0;    /* coordinates of one end of the line */
int X1, Y1;    /* coordinates of the other end of the line */
char Color;    /* color to draw line in */
{
	int DeltaX, DeltaY;
	int Temp;

	/* Set the drawing color */

	/* Put the drawing color in the Set/Reset register */
	outportb(GC_INDEX, SET_RESET_INDEX);
	outportb(GC_DATA, Color);
	/* Cause all planes to be forced to the Set/Reset color */
	outportb(GC_INDEX, ENABLE_SET_RESET_INDEX);
	outportb(GC_DATA, 0xF);

	/* Save half the line-drawing cases by swapping Y0 with Y1
	  and X0 with X1 if Y0 is greater than Y1. As a result, DeltaY
	  is always > 0, and only the octant 0-3 cases need to be
	  handled. */
	if ( Y0 > Y1 ) {
		Temp = Y0;
		Y0 = Y1;
		Y1 = Temp;
		Temp = X0;
		X0 = X1;
		X1 = Temp;
	}

	/* Handle as four separate cases, for the four octants in which
	  Y1 is greater than Y0 */
	DeltaX = X1 - X0;    /* calculate the length of the line
						   in each coordinate */
	DeltaY = Y1 - Y0;
	if ( DeltaX > 0 ) {
		if ( DeltaX > DeltaY ) {
			Octant0(X0, Y0, DeltaX, DeltaY, 1);
		} else {
			Octant1(X0, Y0, DeltaX, DeltaY, 1);
		}
	} else {
		DeltaX = -DeltaX;             /* absolute value of DeltaX */
		if ( DeltaX > DeltaY ) {
			Octant0(X0, Y0, DeltaX, DeltaY, -1);
		} else {
			Octant1(X0, Y0, DeltaX, DeltaY, -1);
		}
	}

	/* Return the state of the EGA/VGA to normal */
	outportb(GC_INDEX, ENABLE_SET_RESET_INDEX);
	outportb(GC_DATA, 0);
	outportb(GC_INDEX, BIT_MASK_INDEX);
	outportb(GC_DATA, 0xFF);
}
