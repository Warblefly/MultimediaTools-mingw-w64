/**\file 1394CamRGB.cpp
 * \brief Implements color conversion for the C1394Camera class.
 * \ingroup camrgb
 */

//////////////////////////////////////////////////////////////////////
//
//	Version 6.4
//
//  Copyright 8/2006
//
//  Christopher Baker
//  Robotics Institute
//  Carnegie Mellon University
//  Pittsburgh, PA
//
//	Copyright 5/2000
// 
//	Iwan Ulrich
//	Robotics Institute
//	Carnegie Mellon University
//	Pittsburgh, PA
//
//  This file is part of the CMU 1394 Digital Camera Driver
//
//  The CMU 1394 Digital Camera Driver is free software; you can redistribute 
//  it and/or modify it under the terms of the GNU Lesser General Public License 
//  as published by the Free Software Foundation; either version 2.1 of the License,
//  or (at your option) any later version.
//
//  The CMU 1394 Digital Camera Driver is distributed in the hope that it will 
//  be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU Lesser General Public License for more details.
//
//  You should have received a copy of the GNU Lesser General Public License
//  along with the CMU 1394 Digital Camera Driver; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//
//////////////////////////////////////////////////////////////////////

#include "pch.h"

/**\defgroup camrgb Color Conversion
 * \ingroup camcore
 * \brief Optimized routines to convert raw camera data to RGB
 */

/**\brief Multiplexor for the color conversion.
 * \ingroup camrgb
 * \param pBitmap Where to put the converted data.
 * \param length Length of the buffer pointed to by pBitmap
 *
 * this checks the current format and mode and calls the appropriate 
 * conversion routines.
 * 
 * pBitmap Must point to a buffer that is at least (m_width * m_height * 3) bytes long
 */
int C1394Camera::getRGB(unsigned char *pBitmap, unsigned long length)
{
	int ret = CAM_ERROR;
	unsigned long outputlength = m_width * m_height * 3;
	
	DllTrace(DLL_TRACE_ENTER,"ENTER getRGB (%08x,%d)\n",pBitmap,length);
	if(pBitmap == NULL)
	{
		DllTrace(DLL_TRACE_ERROR,"getRGB, pBitmap is NULL, bailing out\n");
		goto _exit;
	}
	
	if(length < outputlength)
	{
		DllTrace(DLL_TRACE_ERROR,"getRGB, insufficient output buffer length, %d < %d\n",
			length,outputlength);
		goto _exit;
	}
	
	if(m_pCurrentBuffer == NULL)
	{
		DllTrace(DLL_TRACE_ERROR,"getRGB, No frame available for processing\n");
		ret = CAM_ERROR_NOT_INITIALIZED;
		goto _exit;
	}

    // flatten the buffer if necessary
    // note: this could be made more efficient by folding the buffer-non-flatness into the RGB conversion-ness
    // but that would be ugly coupling.  The "smart" way to do this is to provide an stl-containerlike iterator
    // mechanism that "hides" the flattened-or-not-ness.  We'll put that one on the wish list...
    dc1394FlattenAcquisitionBuffer(m_pCurrentBuffer);

	switch(m_colorCode)
	{
	case COLOR_CODE_Y8:
		ret = YtoRGB(pBitmap,length);
		break;
	case COLOR_CODE_YUV411:
		ret = YUV411toRGB(pBitmap,length);
		break;
	case COLOR_CODE_YUV422:
		ret = YUV422toRGB(pBitmap,length);
		break;
	case COLOR_CODE_YUV444:
		ret = YUV444toRGB(pBitmap,length);
		break;
	case COLOR_CODE_RGB8:
		if(m_pCurrentBuffer->ulBufferSize < outputlength)
		{
			DllTrace(DLL_TRACE_ERROR,"getRGB,RGB insufficient frame buffer length, %d < %d\n",
				m_pCurrentBuffer->ulBufferSize, outputlength);
			ret = CAM_ERROR_INSUFFICIENT_RESOURCES;
		} else {
			CopyMemory(pBitmap,m_pCurrentBuffer->pFrameStart,outputlength);
			ret = CAM_SUCCESS;
		}
		break;
	case COLOR_CODE_Y16:
		ret = Y16toRGB(pBitmap,length);
		break;
	case COLOR_CODE_RGB16:
		ret = RGB16toRGB(pBitmap,length);
		break;
	case COLOR_CODE_RAW8:
	case COLOR_CODE_RAW16:
		DllTrace(DLL_TRACE_ERROR,"getRGB: Custom conversion is required for RAW formats\n");
		ret = CAM_ERROR_INVALID_VIDEO_SETTINGS;
		break;
	default:
		DllTrace(DLL_TRACE_ERROR,"getRGB, invalid color code %d\n",m_colorCode);
		ret = CAM_ERROR_INVALID_VIDEO_SETTINGS;
		break;
	}
	
_exit:
	DllTrace(DLL_TRACE_EXIT,"EXIT getRGB(%d)\n",ret);
	return ret;
}

/**\brief convert to RGB, and place in the windows-native bottom-up BGR format
 * \ingroup camrgb
 * \param pBitmap where to put the data.
 * \param length Length of the buffer pointed to by pBitmap
 *
 * pBitmap Must point to a buffer that is at least (m_width * m_height * 3) bytes long
 */
int C1394Camera::getDIB(unsigned char *pBitmap, unsigned long length)
{
	unsigned char *top, *bot, *pend;
	int ret, ystep = m_width * 3;
	top = pBitmap;
	pend = top + m_height * m_width * 3;
	bot = pend - ystep;
	unsigned char t[3];
	
    // note: redirection to getRGB here "flattens" the buffer for us
    // if we ever get smarter here, we must remember to flatten here as well...
	if((ret = getRGB(pBitmap,length)) != CAM_SUCCESS)
	{
		DllTrace(DLL_TRACE_ERROR,"getDIB, error %d on getRGB\n",ret);
		return ret;
	}
	
	while(top < bot)
	{
		while(bot < pend)
		{
			t[0] = *top++;
			t[1] = *top++;
			t[2] = *top;
			
			*top-- = *bot++;
			*top-- = *bot++;
			*top   = *bot;
			top += 3;
			
			*bot-- = t[0];
			*bot-- = t[1];
			*bot   = t[2];
			bot += 3;
		}
		
		pend -= ystep;
		bot = pend - ystep;
	}
	return CAM_SUCCESS;
}

/**********************************************
 *  The actual conversion stuff starts here.  *
 *  This code is highly optimized, uses only  *
 *  integer math, and usually outperforms     *
 *  Intel's IPL by a 10-20% margin.           *
 **********************************************/

/*
 * Note on computation of deltaG,
 *
 * We are still using 0.1942 U + 0.5094 V, except
 * they have been multiplied by 65536 so we can use integer
 * multiplication, then a bitshift, instead of using the
 * slower FPU.  Because each channel is only 8 bits, the loss
 * in precision has negligible effects on the result.
 */

// I'm not overly fond of macros in this case, but this gets used a LOT

#define CLAMP_TO_UCHAR(a) (unsigned char)((a) < 0 ? 0 : ((a) > 255 ? 255 : (a)))

/**\brief Convert the YUV4,4,4 format to RGB8
 * \ingroup camrgb
 * \param pBitmap where to put the data.
 * \param length Length of the buffer pointed to by pBitmap
 *
 * The YUV4,4,4 format is simply U,Y,V per pixel in memory.
 *
 * pBitmap Must point to a buffer that is at least (m_width * m_height * 3) bytes long
 */
int C1394Camera::YUV444toRGB(unsigned char* pBitmap, unsigned long length)
{
	long Y, U, V, deltaG;
	unsigned char *srcptr, *srcend, *destptr;
	unsigned long outputlength = m_width * m_height * 3;
	int ret = CAM_ERROR;
	
	DllTrace(DLL_TRACE_ENTER,"ENTER YUV444toRGB (%08x,%d)\n",pBitmap,length);
	// check output
	if(pBitmap == NULL)
	{
		DllTrace(DLL_TRACE_ERROR,"YUV444toRGB, pBitmap is NULL, bailing out\n");
		goto _exit;
	}
	
	// check output length
	if(length < outputlength)
	{
		DllTrace(DLL_TRACE_ERROR,"YUV444toRGB, insufficient output buffer length, %d < %d\n",
			length,outputlength);
		goto _exit;
	}
	
	// check input
	if(m_pCurrentBuffer == NULL)
	{
		DllTrace(DLL_TRACE_ERROR,"YUV444toRGB, No frame available for processing\n");
		ret = CAM_ERROR_NOT_INITIALIZED;
		goto _exit;
	}
	
	srcptr = m_pCurrentBuffer->pFrameStart;
	srcend = srcptr + outputlength;
	destptr = pBitmap;
	
	// data pattern, UYV
	// unroll it to 4 pixels/round
	
	while(srcptr < srcend)
	{
		U = (*srcptr++) - 128;
		Y = (*srcptr++);
		V = (*srcptr++) - 128;
		
		deltaG = (12727 * U + 33384 * V);
		deltaG += (deltaG > 0 ? 32768 : -32768);
		deltaG >>= 16;
		
		*destptr++ = CLAMP_TO_UCHAR( Y + V );
		*destptr++ = CLAMP_TO_UCHAR( Y - deltaG );
		*destptr++ = CLAMP_TO_UCHAR( Y + U );
		
		U = (*srcptr++) - 128;
		Y = (*srcptr++);
		V = (*srcptr++) - 128;
		
		deltaG = (12727 * U + 33384 * V);
		deltaG += (deltaG > 0 ? 32768 : -32768);
		deltaG >>= 16;
		
		*destptr++ = CLAMP_TO_UCHAR( Y + V );
		*destptr++ = CLAMP_TO_UCHAR( Y - deltaG );
		*destptr++ = CLAMP_TO_UCHAR( Y + U );
		
		U = (*srcptr++) - 128;
		Y = (*srcptr++);
		V = (*srcptr++) - 128;
		
		deltaG = (12727 * U + 33384 * V);
		deltaG += (deltaG > 0 ? 32768 : -32768);
		deltaG >>= 16;
		
		*destptr++ = CLAMP_TO_UCHAR( Y + V );
		*destptr++ = CLAMP_TO_UCHAR( Y - deltaG );
		*destptr++ = CLAMP_TO_UCHAR( Y + U );
		
		U = (*srcptr++) - 128;
		Y = (*srcptr++);
		V = (*srcptr++) - 128;
		
		deltaG = (12727 * U + 33384 * V);
		deltaG += (deltaG > 0 ? 32768 : -32768);
		deltaG >>= 16;
		
		*destptr++ = CLAMP_TO_UCHAR( Y + V );
		*destptr++ = CLAMP_TO_UCHAR( Y - deltaG );
		*destptr++ = CLAMP_TO_UCHAR( Y + U );
	}
	ret = CAM_SUCCESS;
_exit:
	DllTrace(DLL_TRACE_EXIT,"Exit YUV444toRGB(%d)\n",ret);
	return ret;
}

/**\brief Convert the YUV4,2,2 format to RGB8
 * \ingroup camrgb
 * \param pBitmap where to put the data.
 * \param length Length of the buffer pointed to by pBitmap
 *
 * The YUV4,2,2 format is UYVY for two adjacent pixels.  More clever techniques may use 
 * some kind of spatial averaging, but here we keep it simple and stupid.
 *
 * pBitmap Must point to a buffer that is at least (m_width * m_height * 3) bytes long
 */
int C1394Camera::YUV422toRGB(unsigned char *pBitmap, unsigned long length)
{
	long Y, U, V, deltaG;
	unsigned char *srcptr, *srcend, *destptr;
	unsigned long outputlength = m_width * m_height * 3;
	int ret = CAM_ERROR;
	
	DllTrace(DLL_TRACE_ENTER,"ENTER YUV422toRGB (%08x,%d)\n",pBitmap,length);
	// check output
	if(pBitmap == NULL)
	{
		DllTrace(DLL_TRACE_ERROR,"YUV422toRGB, pBitmap is NULL, bailing out\n");
		goto _exit;
	}
	
	// check output length
	if(length < outputlength)
	{
		DllTrace(DLL_TRACE_ERROR,"YUV422toRGB, insufficient output buffer length, %d < %d\n",
			length,outputlength);
		goto _exit;
	}
	
	// check input
	if(m_pCurrentBuffer == NULL)
	{
		DllTrace(DLL_TRACE_ERROR,"YUV422toRGB, No frame available for processing\n");
		ret = CAM_ERROR_NOT_INITIALIZED;
		goto _exit;
	}
	
	srcptr = m_pCurrentBuffer->pFrameStart;
	srcend = srcptr + ((outputlength * 16)/24);
	destptr = pBitmap;
	
	// data pattern, UYVY
	while(srcptr < srcend)
	{
		U = *srcptr;
		U -= 128;
		V = *(srcptr+2);
		V -= 128;
		
		deltaG = (12727 * U + 33384 * V);
		deltaG += (deltaG > 0 ? 32768 : -32768);
		deltaG >>= 16;
		
		Y = *(srcptr + 1);
		*destptr++ = CLAMP_TO_UCHAR( Y + V );
		*destptr++ = CLAMP_TO_UCHAR( Y - deltaG );
		*destptr++ = CLAMP_TO_UCHAR( Y + U );
		
		Y = *(srcptr + 3);
		*destptr++ = CLAMP_TO_UCHAR( Y + V );
		*destptr++ = CLAMP_TO_UCHAR( Y - deltaG );
		*destptr++ = CLAMP_TO_UCHAR( Y + U );
		
		srcptr += 4;
		
		// twice in the same loop... just like halving the loop overhead
		
		U = (*srcptr) - 128;
		V = (*(srcptr+2)) - 128;
		
		deltaG = (12727 * U + 33384 * V);
		deltaG += (deltaG > 0 ? 32768 : -32768);
		deltaG >>= 16;
		
		Y = *(srcptr + 1);
		*destptr++ = CLAMP_TO_UCHAR( Y + V );
		*destptr++ = CLAMP_TO_UCHAR( Y - deltaG );
		*destptr++ = CLAMP_TO_UCHAR( Y + U );
		
		Y = *(srcptr + 3);
		*destptr++ = CLAMP_TO_UCHAR( Y + V );
		*destptr++ = CLAMP_TO_UCHAR( Y - deltaG );
		*destptr++ = CLAMP_TO_UCHAR( Y + U );
		
		srcptr += 4;
		
	}
	ret = CAM_SUCCESS;
_exit:
	DllTrace(DLL_TRACE_EXIT,"Exit YUV422toRGB(%d)\n",ret);
	return ret;
}

/**\brief Convert the YUV4,1,1 format to RGB8
 * \ingroup camrgb
 * \param pBitmap where to put the data.
 * \param length Length of the buffer pointed to by pBitmap
 *
 * The YUV4,1,1 format is UYYVYY for four adjacent pixels.  More clever techniques may use 
 * some kind of spatial averaging, but here we keep it simple and stupid.
 *
 * pBitmap Must point to a buffer that is at least (m_width * m_height * 3) bytes long
 */
int C1394Camera::YUV411toRGB(unsigned char *pBitmap, unsigned long length)
{
	long Y, U, V, deltaG;
	unsigned char *srcptr, *srcend, *destptr;
	unsigned long outputlength = m_width * m_height * 3;
	int ret = CAM_ERROR;
	
	DllTrace(DLL_TRACE_ENTER,"ENTER YUV411toRGB (%08x,%d)\n",pBitmap,length);
	// check output
	if(pBitmap == NULL)
	{
		DllTrace(DLL_TRACE_ERROR,"YUV411toRGB, pBitmap is NULL, bailing out\n");
		goto _exit;
	}
	
	// check output length
	if(length < outputlength)
	{
		DllTrace(DLL_TRACE_ERROR,"YUV411toRGB, insufficient output buffer length, %d < %d\n",
			length,outputlength);
		goto _exit;
	}
	
	// check input
	if(m_pCurrentBuffer == NULL)
	{
		DllTrace(DLL_TRACE_ERROR,"YUV411toRGB, No frame available for processing\n");
		ret = CAM_ERROR_NOT_INITIALIZED;
		goto _exit;
	}
	
	srcptr = m_pCurrentBuffer->pFrameStart;
	srcend = srcptr + ((outputlength * 12)/24);
	destptr = pBitmap;
	// data pattern, UYYVYY
	while(srcptr < srcend)
	{
		U = (*srcptr) - 128;
		V = (*(srcptr+3)) - 128;
		
		deltaG = (12727 * U + 33384 * V);
		deltaG += (deltaG > 0 ? 32768 : -32768);
		deltaG >>= 16;
		
		Y = *(srcptr + 1);
		*destptr++ = CLAMP_TO_UCHAR( Y + V );
		*destptr++ = CLAMP_TO_UCHAR( Y - deltaG );
		*destptr++ = CLAMP_TO_UCHAR( Y + U );
		
		Y = *(srcptr + 2);
		*destptr++ = CLAMP_TO_UCHAR( Y + V );
		*destptr++ = CLAMP_TO_UCHAR( Y - deltaG );
		*destptr++ = CLAMP_TO_UCHAR( Y + U );
		
		Y = *(srcptr + 4);
		*destptr++ = CLAMP_TO_UCHAR( Y + V );
		*destptr++ = CLAMP_TO_UCHAR( Y - deltaG );
		*destptr++ = CLAMP_TO_UCHAR( Y + U );
		
		Y = *(srcptr + 5);
		*destptr++ = CLAMP_TO_UCHAR( Y + V );
		*destptr++ = CLAMP_TO_UCHAR( Y - deltaG );
		*destptr++ = CLAMP_TO_UCHAR( Y + U );
		
		srcptr += 6;
	}
	ret = CAM_SUCCESS;
_exit:
	DllTrace(DLL_TRACE_EXIT,"Exit YUV411toRGB(%d)\n",ret);
	return ret;
}

/**\brief Convert the Y format to RGB8
 * \ingroup camrgb
 * \param pBitmap where to put the data.
 * \param length Length of the buffer pointed to by pBitmap
 *
 * This is grayscale, so the bytes are simply replicated to make an RGB8 bitmap.
 *
 * pBitmap Must point to a buffer that is at least (m_width * m_height * 3) bytes long
 */
int C1394Camera::YtoRGB(unsigned char *pBitmap, unsigned long length)
{
	unsigned char *srcptr, *srcend, *destptr;
	unsigned long outputlength = m_width * m_height * 3;
	int ret = CAM_ERROR;
	
	DllTrace(DLL_TRACE_ENTER,"ENTER YtoRGB (%08x,%d)\n",pBitmap,length);
	// check output
	if(pBitmap == NULL)
	{
		DllTrace(DLL_TRACE_ERROR,"YtoRGB, pBitmap is NULL, bailing out\n");
		goto _exit;
	}
	
	// check output length
	if(length < outputlength)
	{
		DllTrace(DLL_TRACE_ERROR,"YtoRGB, insufficient output buffer length, %d < %d\n",
			length,outputlength);
		goto _exit;
	}
	
	// check input
	if(m_pCurrentBuffer == NULL)
	{
		DllTrace(DLL_TRACE_ERROR,"YtoRGB, No frame available for processing\n");
		ret = CAM_ERROR_NOT_INITIALIZED;
		goto _exit;
	}
	
	srcptr = m_pCurrentBuffer->pFrameStart;
	srcend = srcptr + ((outputlength * 8)/24);
	destptr = pBitmap;
	
	// just Y's (monochrome)
	// unroll it to 4 per cycle
	while(srcptr < srcend)
	{
		*destptr++ = *srcptr;
		*destptr++ = *srcptr;
		*destptr++ = *srcptr;
		srcptr++;
		
		*destptr++ = *srcptr;
		*destptr++ = *srcptr;
		*destptr++ = *srcptr;
		srcptr++;
		
		*destptr++ = *srcptr;
		*destptr++ = *srcptr;
		*destptr++ = *srcptr;
		srcptr++;
		
		*destptr++ = *srcptr;
		*destptr++ = *srcptr;
		*destptr++ = *srcptr;
		srcptr++;
	}
	ret = CAM_SUCCESS;
_exit:
	DllTrace(DLL_TRACE_EXIT,"Exit YtoRGB(%d)\n",ret);
	return ret;
}

/**\brief Convert the Y16 format to RGB8
 * \ingroup camrgb
 * \param pBitmap where to put the data.
 * \param length Length of the buffer pointed to by pBitmap
 *
 * This is 16-bit grayscale, so the high 8 bits are simply replicated to make an RGB8 bitmap.
 * Note, this may not be the correct behavior if you are using a 10-bit camera that puts the 
 * information in the low 10 bits.
 *
 * pBitmap Must point to a buffer that is at least (m_width * m_height * 3) bytes long
 */
int C1394Camera::Y16toRGB(unsigned char *pBitmap, unsigned long length)
{
	unsigned char *srcptr, *srcend, *destptr;
	unsigned long outputlength = m_width * m_height * 3;
	int ret = CAM_ERROR;
	
	DllTrace(DLL_TRACE_ENTER,"ENTER Y16toRGB (%08x,%d)\n",pBitmap,length);
	// check output
	if(pBitmap == NULL)
	{
		DllTrace(DLL_TRACE_ERROR,"Y16toRGB, pBitmap is NULL, bailing out\n");
		goto _exit;
	}
	
	// check output length
	if(length < outputlength)
	{
		DllTrace(DLL_TRACE_ERROR,"Y16toRGB, insufficient output buffer length, %d < %d\n",
			length,outputlength);
		goto _exit;
	}
	
	// check input
	if(m_pCurrentBuffer == NULL)
	{
		DllTrace(DLL_TRACE_ERROR,"Y16toRGB, No frame available for processing\n");
		ret = CAM_ERROR_NOT_INITIALIZED;
		goto _exit;
	}
	
	srcptr = m_pCurrentBuffer->pFrameStart;
	srcend = srcptr + ((outputlength * 16)/24);
	destptr = pBitmap;
	
	// just Y's (monochrome, 16-bit big endian)
	// unroll it to 4 per cycle
	while(srcptr < srcend)
	{
		*destptr++ = *srcptr;
		*destptr++ = *srcptr;
		*destptr++ = *srcptr;
		srcptr += 2;
		
		*destptr++ = *srcptr;
		*destptr++ = *srcptr;
		*destptr++ = *srcptr;
		srcptr += 2;
		
		*destptr++ = *srcptr;
		*destptr++ = *srcptr;
		*destptr++ = *srcptr;
		srcptr += 2;
		
		*destptr++ = *srcptr;
		*destptr++ = *srcptr;
		*destptr++ = *srcptr;
		srcptr += 2;
	}
	ret = CAM_SUCCESS;
_exit:
	DllTrace(DLL_TRACE_EXIT,"Exit Y16toRGB(%d)\n",ret);
	return ret;
}

/**\brief Convert the RGB16 format to RGB8
 * \ingroup camrgb
 * \param pBitmap where to put the data.
 * \param length Length of the buffer pointed to by pBitmap
 *
 * This just clips off the low 8 bits of each pixel.
 * Note, this may not be the correct behavior if you are using a 10-bit camera that puts the 
 * information in the low 10 bits.
 *
 * pBitmap Must point to a buffer that is at least (m_width * m_height * 3) bytes long
 */
int C1394Camera::RGB16toRGB(unsigned char *pBitmap, unsigned long length)
{
	unsigned char *srcptr, *srcend, *destptr;
	unsigned long outputlength = m_width * m_height * 3;
	int ret = CAM_ERROR;
	
	DllTrace(DLL_TRACE_ENTER,"ENTER RGB16toRGB (%08x,%d)\n",pBitmap,length);
	// check output
	if(pBitmap == NULL)
	{
		DllTrace(DLL_TRACE_ERROR,"RGB16toRGB, pBitmap is NULL, bailing out\n");
		goto _exit;
	}
	
	// check output length
	if(length < outputlength)
	{
		DllTrace(DLL_TRACE_ERROR,"RGB16toRGB, insufficient output buffer length, %d < %d\n",
			length,outputlength);
		goto _exit;
	}
	
	// check input
	if(m_pCurrentBuffer == NULL)
	{
		DllTrace(DLL_TRACE_ERROR,"RGB16toRGB, No frame available for processing\n");
		ret = CAM_ERROR_NOT_INITIALIZED;
		goto _exit;
	}
	
	srcptr = m_pCurrentBuffer->pFrameStart;
	srcend = srcptr + ((outputlength * 48)/24);
	destptr = pBitmap;
	
	
	// R,G,B are 16-bit big-endian, chop of the top 8 and feed 
	// unroll it to 3 per cycle
	while(srcptr < srcend)
	{
		*destptr++ = *srcptr;
		srcptr += 2;
		
		*destptr++ = *srcptr;
		srcptr += 2;
		
		*destptr++ = *srcptr;
		srcptr += 2;
	}
	ret = CAM_SUCCESS;
_exit:
	DllTrace(DLL_TRACE_EXIT,"Exit RGB16toRGB(%d)\n",ret);
	return ret;
}

