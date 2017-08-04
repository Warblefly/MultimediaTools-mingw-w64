/**\file 1394CameraControlSize.cpp
 * \brief Implementation of the C1394CameraControlSize class.
 * \ingroup camfmr
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

//////////////////////////////////////////////////////////////////////
// Construction/Destruction
//////////////////////////////////////////////////////////////////////

/**\brief Initiailze a Size control
 * \param pCamera The parent/container camera whose size os to be controlled
 * \todo change camera-by-pointer to camera-by reference so NULL isn't possible
 */
C1394CameraControlSize::C1394CameraControlSize(C1394Camera *pCamera):m_pCamera(pCamera)
{
	if(m_pCamera == NULL)
		DllTrace(DLL_TRACE_ALWAYS,"ControlSize: Construction: parent camera pointer is invalid: bad things will happen!\n");
	//SR
	m_offset			= 0;
	m_InqMaxSize		= 0;
	m_InqUnitSize		= 0;
	m_InqColorCodes		= 0;
	m_InqUnitPos		= 0; 
	m_StaImagePos		= 0;
	m_StaImageSize		= 0;
	m_StaColorCode		= 0;
	m_StaValueSetting	= 0; 
	m_InqPixels			= 0;
	m_InqBytesHi		= 0;
	m_InqBytesLo		= 0;
	m_InqPacketParam	= 0;
	m_InqDataDepth		= 0;
	m_InqColorFilter	= 0;
	m_StaBytesPerPacket	= 0;
	m_InqPacketsPerFrame= 0;
	m_InqFrameInterval  = 0;
}

/**\brief Nothing to see here, move along */
C1394CameraControlSize::~C1394CameraControlSize()
{}

/**\brief Accessor for horizontal and vertical image limits
 * \param hMax Where to put the horizontal max
 * \param vMax Where to put the vertical max
 *
 * NULL parameters are silently ignored.  Calling this function from an invalid video mode
 * will yield zeros in hMax,vMax
 */
void C1394CameraControlSize::GetSizeLimits(unsigned short *hMax, unsigned short *vMax)
{
	unsigned long data = this->m_offset != 0 ? this->m_InqMaxSize : 0;
	if(hMax != NULL)
		*hMax = (unsigned short)((data >> 16) & 0x0000FFFF);
	if(vMax != NULL)
		*vMax = (unsigned short)(data & 0x0000FFFF);
}

/**\brief Accessor for horizontal and vertical image increments
 * \param hUnit Where to put the horizontal increment
 * \param vUnit Where to put the vertical increment
 *
 * NULL parameters are silently ignored.  Calling this function from an invalid video mode
 * will yield zeros in hUnit,vUnit
 */
void C1394CameraControlSize::GetSizeUnits(unsigned short *hUnit, unsigned short *vUnit)
{
	unsigned long data = this->m_offset != 0 ? this->m_InqUnitSize : 0;
	if(hUnit != NULL)
		*hUnit = (unsigned short)((data >> 16) & 0x0000FFFF);
	if(vUnit != NULL)
		*vUnit = (unsigned short)(data & 0x0000FFFF);
}

/**\brief Accessor for the current image size
 * \param width Where to put the horizontal size
 * \param height Where to put the vertical size
 *
 * NULL parameters are silently ignored.  Calling this function from an invalid video mode
 * will yield zeros in width,height
 */
void C1394CameraControlSize::GetSize(unsigned short *width, unsigned short *height)
{
	unsigned long data = this->m_offset != 0 ? this->m_StaImageSize : 0;
	if(width != NULL)
		*width = (unsigned short)((data >> 16) & 0x0000FFFF);
	if(height != NULL)
		*height = (unsigned short)(data & 0x0000FFFF);
}

/**\brief Mutator for the current image size
 * \param width The horizontal size to set
 * \param height The vertical size to set
 * \return
 *  - CAM_ERROR_NOT_INITIALIZED if format 7 and a valid mode are not selected in the container camera
 *  - CAM_ERROR_PARAM_OUT_OF_RANGE if the provided size is either too large or is not a multiple of the size units
 *  - Other errors: bad things happened in WriteQuadlet
 *
 * Size overrides position, so if the current position is outside the bounds of 
 */
int  C1394CameraControlSize::SetSize(unsigned short width, unsigned short height)
{
	unsigned short maxh,maxv;
	unsigned short hunit,vunit;
	unsigned short top,left;
	int ret = CAM_SUCCESS; //SR

	DllTrace(DLL_TRACE_ENTER,"ENTER ControlSize::SetSize(%d,%d)\n",width,height);

	if(m_offset == 0)
	{
		ret = CAM_ERROR_NOT_INITIALIZED;
		goto _exit;
	}

	this->GetSizeLimits(&maxh,&maxv);
	this->GetSizeUnits(&hunit,&vunit);

	if(hunit == 0 || vunit == 0)
	{
		DllTrace(DLL_TRACE_ERROR,"ControlSize::SetSize: Broken Invariants: Size Units %d,%d\n",hunit,vunit);
		ret = CAM_ERROR;
		goto _exit;
	}

	if( width == 0 || height == 0 ||
		width > maxh || height > maxv ||
		(width % hunit) != 0 || (height % vunit) != 0)
	{
		DllTrace(DLL_TRACE_ERROR,"ControlSize::SetSize: Invalid parameter(s): %d,%d\n",width,height);
		ret = CAM_ERROR_PARAM_OUT_OF_RANGE;
		goto _exit;
	}

	// if we get here, the parameters are okay, so push the private register down
	m_StaImageSize = width;
	m_StaImageSize <<= 16;
	m_StaImageSize += height;
	if((ret = m_pCamera->WriteQuadlet(m_offset + 0x00C,m_StaImageSize)) != CAM_SUCCESS)
		goto _exit;

	// and check the position for consistency
	this->GetPos(&left,&top);
	this->GetPosLimits(&maxh,&maxv);
	if(left > maxh)
		left = maxh;
	if(top > maxv)
		top = maxv;
	if((ret = this->SetPos(left,top)) != CAM_SUCCESS)
		goto _exit;

	// SetSize mods the Tier 1 registers
	ret = this->UpdateTier1(TRUE);
_exit:
	if(ret != CAM_SUCCESS)
		DllTrace(DLL_TRACE_ERROR,"ControlSize::SetSize: Error %d\n",ret);
	DllTrace(DLL_TRACE_EXIT,"EXIT ControlSize::SetSize(%d)\n",ret);
	return ret;
}


/**\brief Accessor for horizontal and vertical position limits
 * \param hMax Where to put the horizontal max
 * \param vMax Where to put the vertical max
 *
 * The horiziontal position max is defined as the difference between the max
 * width. The vertical position max is similar
 *
 * NULL parameters are silently ignored.  Calling this function from an invalid video mode
 * will yield zeros in hMax,vMax.  
 */
void C1394CameraControlSize::GetPosLimits(unsigned short *hMax, unsigned short *vMax)
{
	unsigned short maxh,maxv;
	unsigned short width,height;

	this->GetSizeLimits(&maxh,&maxv);
	this->GetSize(&width,&height);

	if(hMax != NULL)
		*hMax = (width <= maxh ? maxh - width : 0);
	if(vMax != NULL)
		*vMax = (height <= maxv ? maxv - height : 0);
}

/**\brief Accessor for horizontal and vertical position increments
 * \param hUnit Where to put the horizontal max
 * \param vUnit Where to put the vertical max
 *
 * The positions increments are defined by m_InqUnitPos unless
 * m_InqUnitPos is zero, whereupon they are the same as the size units
 *
 * NULL parameters are silently ignored.  Calling this function from an invalid video mode
 * will yield zeros in hUnit,vUnit.  
 */
void C1394CameraControlSize::GetPosUnits(unsigned short *hUnit, unsigned short *vUnit)
{
	unsigned long data = 0;
	if(this->m_offset != 0)
		data = m_InqUnitPos != 0 ? m_InqUnitPos : m_InqUnitSize;
	if(hUnit != NULL)
		*hUnit = (unsigned short)((data >> 16) & 0x0000FFFF);
	if(vUnit != NULL)
		*vUnit = (unsigned short)(data & 0x0000FFFF);
}


/**\brief Accessor for the current image position
 * \param left Where to put the horizontal position
 * \param top Where to put the vertical position
 *
 * NULL parameters are silently ignored.  Calling this function from an invalid video mode
 * will yield zeros in left,top
 */
void C1394CameraControlSize::GetPos(unsigned short *left, unsigned short *top)
{
	unsigned long data = this->m_offset != 0 ? this->m_StaImagePos : 0;	if(left != NULL)
		*left = (unsigned short)((data >> 16) & 0x0000FFFF);
	if(top != NULL)
		*top = (unsigned short)(data & 0x0000FFFF);
}

/**\brief Mutator for the current image position
 * \param left The horizontal position to set
 * \param top The vertical position to set
 * \return
 *  - CAM_ERROR_NOT_INITIALIZED if format 7 and a valid mode are not selected in the container camera
 *  - CAM_ERROR_PARAM_OUT_OF_RANGE if the provided positions is either too large or is not a multiple of the position units
 *  - Other errors: bad things happened in WriteQuadlet
 *
 * Position does not affect anything other than itself
 */
int  C1394CameraControlSize::SetPos(unsigned short left, unsigned short top)
{
	unsigned short maxh,maxv;
	unsigned short hunit,vunit;
	int ret = CAM_SUCCESS;//SR

	DllTrace(DLL_TRACE_ENTER,"ENTER ControlSize::SetPos(%d,%d)\n",left,top);

	if(m_offset == 0)
	{
		ret = CAM_ERROR_NOT_INITIALIZED;
		goto _exit;
	}

	this->GetSizeLimits(&maxh,&maxv);
	this->GetPosUnits(&hunit,&vunit);

	if(hunit == 0 || vunit == 0)
	{
		DllTrace(DLL_TRACE_ERROR,"ControlSize::SetPos: Broken Invariants: Pos Units %d,%d\n",hunit,vunit);
		ret = CAM_ERROR;
		goto _exit;
	}

	if( left > maxh || top > maxv ||
		(left % hunit) != 0 || (top % vunit) != 0)
	{
		DllTrace(DLL_TRACE_ERROR,"ControlSize::SetPos: Invalid parameter(s): %d,%d\n",left,top);
		ret = CAM_ERROR_PARAM_OUT_OF_RANGE;
		goto _exit;
	}

	// if we get here, the parameters are okay, so push the private register down
	m_StaImagePos = left;
	m_StaImagePos <<= 16;
	m_StaImagePos += top;
	if((ret = m_pCamera->WriteQuadlet(m_offset + 0x008,m_StaImagePos)) != CAM_SUCCESS)
		goto _exit;

_exit:
	if(ret != CAM_SUCCESS)
		DllTrace(DLL_TRACE_ERROR,"ControlSize::SetPos: Error %d\n",ret);
	DllTrace(DLL_TRACE_EXIT,"EXIT ControlSize::SetPos(%d)\n",ret);
	return ret;
}

/**\brief Accessor for Color Code Availability
 * \param code The code to check
 * \return boolean presence
 */
bool C1394CameraControlSize::HasColorCode(COLOR_CODE code)
{
	if( this->m_offset == 0 || 
		code == COLOR_CODE_INVALID ||
		(int)code > 31)
		return false;

	return (m_InqColorCodes & (0x80000000 >> (int)code)) != 0;
}

/**\brief Accessor for Currently Selected Color Code
 * \param code Where to put the current code
 *
 * NULL parameters will be silently ignored.  A call to this function
 * without proper initialization will yield COLOR_CODE_INVALID in <i>code</i>
 */
void C1394CameraControlSize::GetColorCode(COLOR_CODE *code)
{
	if(code)
		*code = (this->m_offset != 0 ? (COLOR_CODE)((m_StaColorCode >> 24) & 0x00FF) : COLOR_CODE_INVALID);
}

/**\brief Mutator for color code selection
 * \param code The color code to set
 * \return
 *  - CAM_ERROR_NOT_INITIALIZED if format 7 and a valid mode are not selected in the container camera
 *  - CAM_ERROR_PARAM_OUT_OF_RANGE if the provided color code is not supported
 *  - Other errors: bad things happened in WriteQuadlet
 *
 * Modding the color code requires refreshment of the Tier 1 Registers
 */
int  C1394CameraControlSize::SetColorCode(COLOR_CODE code)
{
	int ret;
	if(this->m_offset == NULL)
		return CAM_ERROR_NOT_INITIALIZED;

	if(!this->HasColorCode(code))
		return CAM_ERROR_PARAM_OUT_OF_RANGE;

	m_StaColorCode &= 0x00FFFFFF;
	m_StaColorCode |= ((unsigned long)code) << 24;
	if((ret = m_pCamera->WriteQuadlet(m_offset + 0x010,m_StaColorCode)) != CAM_SUCCESS)
		return ret;
	return UpdateTier1(TRUE);
}

/**\brief Retrieve the number of Pixels per frame
 * \param ppf Where to put the number of pixels per frame
 *
 * NULL parameter will be silently ignored.  A call to this function
 * without proper initialization will yield 0 in <i>ppf</i>
 */
void C1394CameraControlSize::GetPixelsPerFrame(unsigned long *ppf)
{
	if(ppf)
		*ppf = this->m_offset != 0 ? this->m_InqPixels : 0;
}

/**\brief Retrieve the number of bytes per frame
 * \param lo32 Where to put the low 32-bits of the number of bytes per frame
 * \param hi32 Where to put the high 32-bits
 *
 * The number of bytes per frame is conceivably unlimited depending on the frame format
 * hi32 is NULL by default because it is not possible to a framebuffer > 4GB on most
 * machines anyway. 
 *
 * NULL parameters are silently ignored.
 * A call to this function without proper initialization will yield zeros
 */
void C1394CameraControlSize::GetBytesPerFrame(unsigned long *lo32, unsigned long *hi32)
{
	if(lo32)
		*lo32 = this->m_offset != 0 ? this->m_InqBytesLo : 0;
	if(hi32)
		*hi32 = this->m_offset != 0 ? this->m_InqBytesHi : 0;
}

/**\brief Retrieve the valid range of bytes per packet
 * \param min Where to put the min
 * \param max Where to put the max
 *
 * The number of bytes per packet generally determines the framerate of a format 7 stream.
 *
 * NULL parameters are silently ignored.
 * A call to this function without proper initialization will yield zeros
 */
void C1394CameraControlSize::GetBytesPerPacketRange(unsigned short *min, unsigned short *max)
{
	unsigned long data = 0;
	if(this->m_offset != 0)
		data = this->m_InqPacketParam;
	if(min != NULL)
		*min = (unsigned short)((data >> 16) & 0x0000FFFF);
	if(max != NULL)
		*max = (unsigned short)(data & 0x0000FFFF);
}

/**\brief Retrieve the valid range of bytes per packet
 * \param current Where to put the current value
 * \param recommended Where to put the recommended value (available in 1.30+)
 *
 * For cameras that do not provide a recommendation of their own, we offer the maximum
 *
 * NULL parameters are silently ignored.
 * A call to this function without proper initialization will yield zeros
 */
void C1394CameraControlSize::GetBytesPerPacket(unsigned short *current, unsigned short *recommended)
{
	unsigned long data = 0;
	if(this->m_offset != 0)
		data = this->m_StaBytesPerPacket;
	if(current != NULL)
		*current = (unsigned short)((data >> 16) & 0x0000FFFF);
	if(recommended != NULL)
	{
		*recommended = (unsigned short)(data & 0x0000FFFF);
		if(*recommended == 0)
			this->GetBytesPerPacketRange(NULL,recommended);
	}
}

/**\brief Retrieve the number of packets per frame
 * \param ppf where to put the result
 *
 * Packets per frame is either available directly (1.30 or later) or must be computed
 * NULL parameters are silently ignored.
 * A call to this function without proper initialization will yield zeros
 */
void C1394CameraControlSize::GetPacketsPerFrame(unsigned long *ppf)
{
	if(ppf != NULL)
	{
		*ppf = 0;
		if(this->m_offset != 0)
		{
			if(m_InqPacketsPerFrame == 0)
			{
				unsigned short bpp;
				unsigned long bpf;
				this->GetBytesPerFrame(&bpf,NULL);
				this->GetBytesPerPacket(&bpp);
				if(bpp > 0)
					*ppf = (bpf + (bpp - 1)) / bpp;
			} else {
				*ppf = m_InqPacketsPerFrame;
			}
		}
	}
}

/**\brief Set the number of bytes per packet
 * \param bpp The number to set
 * \return 
 *  - CAM_ERROR_NOT_INITIALIZED if format 7 and a valid mode are not selected in the container camera
 *  - CAM_ERROR_PARAM_OUT_OF_RANGE <i>bpp</i> is either out of bounds or does not conform to the required increments
 *  - Other errors: bad things happened in WriteQuadlet
 *
 * This is roughly analagous to setting the frame rate for most cameras supporting format 7
 */
int  C1394CameraControlSize::SetBytesPerPacket(unsigned short bpp)
{
	unsigned short min,max;
	int ret;

	if(this->m_offset == NULL)
		return CAM_ERROR_NOT_INITIALIZED;

	this->GetBytesPerPacketRange(&min,&max);
	if( min == 0 || max == 0 || 
		bpp < min || bpp > max ||
		(bpp % min) != 0)
	{
		DllTrace(DLL_TRACE_ERROR,"ControlSize::SetBytesPerPacket: Invalid Parameter (%d)\n",bpp);
		return CAM_ERROR_PARAM_OUT_OF_RANGE;
	}

	this->m_StaBytesPerPacket &= 0x0000FFFF;
	this->m_StaBytesPerPacket |= ((unsigned long)bpp)<<16;

	if((ret = m_pCamera->WriteQuadlet(m_offset + 0x044,m_StaBytesPerPacket)) != CAM_SUCCESS)
		return ret;
	
	// twiddling BytesPerPacket affects Tier 2 registers
	return UpdateTier2(TRUE);
}

/**\brief boolean accessor for ERROR_1 bit in the VALUE_SETTING register */
bool C1394CameraControlSize::CheckError1()
{
	return this->m_offset != NULL ? (this->m_StaValueSetting & 0x80800000) == 0x80800000 : false;
}

/**\brief boolean accessor for ERROR_2 bit in the VALUE_SETTING register */
bool C1394CameraControlSize::CheckError2()
{
	return this->m_offset != NULL ? (this->m_StaValueSetting & 0x80400000) == 0x80400000 : false;
}

/**\brief Retrieve effective pixel data depth (V1.31)
 * \param depth where to put the result
 *
 * NULL parameters are silently ignored.
 * A call to this function without proper initialization will result in zeros
 *
 * If this register is not supported, this will return 8 for 8-bit modes and 16 for 16-bit modes
 */
void C1394CameraControlSize::GetDataDepth(unsigned short *depth)
{
  if(depth != NULL)
  {
    if(this->m_offset == 0)
    {
      *depth = 0;
    } else {
      if(this->m_InqDataDepth != 0)
      {
        *depth = (unsigned short)((this->m_InqDataDepth >> 24) & 0x00FF);
      } else {
        // emulate
        COLOR_CODE code;
        this->GetColorCode(&code);
        if( code == COLOR_CODE_Y16 ||
            code == COLOR_CODE_RGB16 ||
            code == COLOR_CODE_RAW16)
          *depth = 16;
        else
          *depth = 8;
      }
    }
  }
}

/**\brief Retrieve the number of packets per frame (V1.31)
 * \param filter where to put the result
 *
 * NULL parameters are silently ignored.
 * A call to this function without proper initialization will result in zeros
 *
 * There is no way to differentiate between a Color Filter ID of 0 and this
 * register being unsupported
 */
void C1394CameraControlSize::GetColorFilter(unsigned short *filter)
{
  if(filter != NULL)
  {
    if(this->m_offset == 0)
      *filter = 0;
    else
      *filter = (unsigned short)((this->m_InqColorFilter >> 24) & 0x00FF);
  }
}

/**\brief Retrieve the interframe interval (V1.31)
 * \param interval where to put the result
 *
 * NULL parameters are silently ignored.
 * A call to this function without proper initialization will result in zeros
 *
 * If this register is unsupported, this will compute the optimum possible
 * interval as (packets per frame) * (packet interval) where the packet interval
 * is dictated to be 125 uS by the 1394 spec.
 */
void C1394CameraControlSize::GetFrameInterval(float *interval)
{
  if(interval != NULL)
  {
    if(this->m_offset == 0)
    {
      *interval = 0;
    } else {
      if(this->m_InqFrameInterval != 0)
      {
        *interval = *((float *)(&this->m_InqFrameInterval));
      } else {
        // emulate as packets per frame * bus cycle time
        unsigned long ppf;
        this->GetPacketsPerFrame(&ppf);
        *interval = (float)(0.000125 * (double)ppf);
      }
    }
  }
}

/*******************
 * PRIVATE METHODS *
 *******************/

/**\brief Set the Offset to use for the camera control
 * \param offset the (absolute) offset into the camera's register space to use for Format 7 control
 * \return CAM_SUCCESS if everything is okay, otherwise some error returned by C1394Camera::ReadQuadlet()
 *
 * This is meant to be called only from the container C1394Camera class
 * and only downstream of a validated SetMode(7,?).  It is not clear what the "right"
 * thing is to do here (perhaps make this private and make C1394Camera a friend?)
 */
int C1394CameraControlSize::SetOffset(unsigned long offset)
{
	int ret = -1; //SR
	DllTrace(DLL_TRACE_ENTER,"ENTER ControlSize::SetOffset(%08x)\n",offset);

	this->m_offset = offset;
	if(this->m_offset != 0)
	{
		unsigned short maxh,maxv;
		unsigned short unith,unitv;
		unsigned short width,height;
		COLOR_CODE code;

		// update statics
		if((ret = this->UpdateStatic()) != CAM_SUCCESS)
			goto _exit;

		// update tier1
		if((ret = this->UpdateTier1()) != CAM_SUCCESS)
			goto _exit;

		// update tier2
		if((ret = this->UpdateTier2()) != CAM_SUCCESS)
			goto _exit;

		// Now we insure internal consistency
		// If all cameras followed spec and self-initialized to a valid state
		// this would probably not be necessary, but alas.

		this->GetSizeLimits(&maxh,&maxv);
		this->GetSizeUnits(&unith,&unitv);
		this->GetSize(&width,&height);
		this->GetColorCode(&code);

		// check width against horizontal max, unit
		if(width > maxh)
		{
			DllTrace(DLL_TRACE_WARNING,"ControlSize::SetOffset: configured width %d exceeds horizontal max %d, truncating to %d\n",
				width,maxh,maxh);
			width = maxh;
		}

		if((width % unith) != 0)
		{
			DllTrace(DLL_TRACE_WARNING,"ControlSize::SetOffset: configured width %d is not a multiple of horizontal unit %d, truncating to %d\n",
				width,unith,width - (width % unith));

			width -= (width % unith);
		}

		if(width == 0)
		{
			DllTrace(DLL_TRACE_WARNING,"ControlSize::SetOffet: Invalid width (0), setting to horizontal unit %d\n",
				unith);
			width=unith;
		}

		// check height against vertical max, unit
		if(height > maxv)
		{
			DllTrace(DLL_TRACE_WARNING,"ControlSize::SetOffset: configured height %d exceeds vertical max %d, truncating to %d\n",
				height,maxv,maxv);
			height = maxv;
		}

		if((height % unitv) != 0)
		{
			DllTrace(DLL_TRACE_WARNING,"ControlSize::SetOffset: configured height %d is not a multiple of vertical unit %d, truncating to %d\n",
				height,unitv,height - (height % unitv));

			height -= (height % unitv);
		}

		if(height == 0)
		{
			DllTrace(DLL_TRACE_WARNING,"ControlSize::SetOffet: Invalid height (0), setting to horizontal unit %d\n",
				unitv);
			height=unitv;
		}

		// validate the current color code, search for one if it exists
		if(!this->HasColorCode(code))
		{
			for(int i=0; i<(int)COLOR_CODE_MAX; i++)
			{
				code = (COLOR_CODE)i;
				if(this->HasColorCode((COLOR_CODE)i))
					break;
			}
		}
		
		// bail if we haven't found a valid setup at this point
		if( code == COLOR_CODE_MAX ||
			width == 0 || height == 0)
		{
			DllTrace(DLL_TRACE_ERROR,"ControlSize::SetOffset: Unable to find a valid combination: %d,%d,%d\n",
				width,height,code);
			ret = CAM_ERROR;
			goto _exit;
		}

		// setting the size will ensure the consistency of the offsets, and the color code will update and validate
		// the various relevant isoch packet information

		DllTrace(DLL_TRACE_CHECK,"ControlSize::SetOffset: Setting width,height,color code to %d,%d,%d\n",
			width,height,code);

		if((ret = this->SetSize(width,height)) != CAM_SUCCESS)
			goto _exit;

		if((ret = this->SetColorCode(code)) != CAM_SUCCESS)
			goto _exit;

	} else {
		// basically this turns the control off
		DllTrace(DLL_TRACE_CHECK,"ControlSize::SetOffset: Control %08x Deactivated\n",this);
		ret = CAM_SUCCESS;
	}
_exit:
	if(ret != CAM_SUCCESS)
	{
		DllTrace(DLL_TRACE_ERROR,"ControlSize::SetOffset Failed (%d)\n",ret);
		this->m_offset = 0;
	}
	DllTrace(DLL_TRACE_EXIT,"EXIT ControlSize::SetOffset(%d)\n",ret);
	return ret;
}

/**\brief Utility structure for reading a large group of registers into local variables
 * \todo Investigate whether this might be pushed into the official C API, or else subsumed into the C1394Camera or C1394CameraControlSize classes
 * \see ReadRegisterMap
 */
struct register_mapping {
	unsigned short offset;   ///< The offset into the register space to read
	unsigned short optional; ///< Optional = "failure is acceptable"
	unsigned long *data;     ///< Where to put the result of the read
};

int ReadRegisterMap(C1394Camera *pCamera, unsigned long root_offset, struct register_mapping *regs);

/**\brief Read all the static inquiry registers for the currently-selected partial scan mode */
int C1394CameraControlSize::UpdateStatic()
{
	int ret = CAM_SUCCESS;
	struct register_mapping staticinq[] = {
		{0x000,0,&this->m_InqMaxSize},
		{0x004,0,&this->m_InqUnitSize},
		{0x014,0,&this->m_InqColorCodes},
		{0x04C,1,&this->m_InqUnitPos},
		{0,0,0}
	};
	DllTrace(DLL_TRACE_ENTER,"ENTER ControlSize::UpdateStatic()\n");
	ret = ReadRegisterMap(this->m_pCamera,this->m_offset,staticinq);
	DllTrace(DLL_TRACE_EXIT,"EXIT ControlSize::UpdateStatic(%d)\n",ret);
	return ret;
}

/**\brief Read all the tier 1 status and inquiry registers
 * \param CallSetValues Whether we need to do additional work
 *
 * If CallSetValues is true, then we are probably coming from a call
 * to SetImageSize() or SetColorCode(), which requires:
 *   - That we frob the VALUE_SETTING register if it is present
 *   - That we do a sanity check on the value of BytesPerPacket
 */
int C1394CameraControlSize::UpdateTier1(BOOL CallSetValues)
{
	int ret = CAM_SUCCESS;
	struct register_mapping tier1sta[] = {
		{0x008,0,&this->m_StaImagePos},
		{0x00C,0,&this->m_StaImageSize},
		{0x010,0,&this->m_StaColorCode},
		{0x07C,1,&this->m_StaValueSetting},
		{0,0,0}
	};
	struct register_mapping tier1inq[] = {
		{0x034,0,&this->m_InqPixels},
		{0x038,0,&this->m_InqBytesHi},
		{0x03C,0,&this->m_InqBytesLo},
		{0x040,0,&this->m_InqPacketParam},
		{0x054,1,&this->m_InqDataDepth},
		{0x058,1,&this->m_InqColorFilter},
		{0,0,0}
	};
	
	DllTrace(DLL_TRACE_ENTER,"ENTER ControlSize::UpdateTier1(%d)\n",CallSetValues);
	ret = ReadRegisterMap(this->m_pCamera,this->m_offset,tier1sta);
	if(ret == CAM_SUCCESS)
	{
		if(CallSetValues == TRUE)
		{
			if((ret = this->SetValues()) != CAM_SUCCESS)
				goto _exit;
		}
		// read out the INQ register map
		ret = ReadRegisterMap(this->m_pCamera,this->m_offset,tier1inq);
		if(ret == CAM_SUCCESS && CallSetValues == TRUE)
		{
			unsigned short min,max,cur,rec;
			DllTrace(DLL_TRACE_CHECK,"UpdateTier1: Sanity-Checking BytesPerPacket...\n");
			this->GetBytesPerPacketRange(&min,&max);
			this->GetBytesPerPacket(&cur,&rec);
			
			if((cur % min) != 0)
			{
				cur /= min;
				cur *= min;
				if(cur == 0)
					cur = min;
			}
			
			if(cur < min || cur > max)
			{
				if(rec > max)
					rec = max;
				DllTrace(DLL_TRACE_CHECK,"UpdateTier1: bpp %d is now out of range (%d-%d), setting to %d\n",
					cur,min,max,rec);
				cur = rec;
			}
			ret = this->SetBytesPerPacket(cur); // indirectly calls UpdateTier2()
		}		
	}
_exit:
	DllTrace(DLL_TRACE_EXIT,"EXIT ControlSize::UpdateTier1(%d)\n",ret);
	return ret;
}

/**\brief Read all the tier 2 status and inquiry registers
 * \param CallSetValues Whether we need to do additional work
 * \return same a UpdateTier1()
 */
int C1394CameraControlSize::UpdateTier2(BOOL CallSetValues)
{
	int ret = CAM_SUCCESS;
	struct register_mapping tier2sta[] = {
		{0x044,0,&this->m_StaBytesPerPacket},
		{0,0,0}
	};
	struct register_mapping tier2inq[] = {
		{0x048,1,&this->m_InqPacketsPerFrame},
		{0x050,1,&this->m_InqFrameInterval},
		{0,0,0}
	};
	
	DllTrace(DLL_TRACE_ENTER,"ENTER ControlSize::UpdateTier2(%d)\n",CallSetValues);
	ret = ReadRegisterMap(this->m_pCamera,this->m_offset,tier2sta);
	if(ret == CAM_SUCCESS)
	{
		if(CallSetValues == TRUE)
		{
			if((ret = this->SetValues()) != CAM_SUCCESS)
				goto _exit;

			ret = ReadRegisterMap(this->m_pCamera,this->m_offset,tier2inq);
			// at this point, some important things may have changed,
			// so we need to call UpdateParameters(), specifying that we only want to
			// refresh, not enforce the internal state.
			this->m_pCamera->UpdateParameters(TRUE);
		} else {
			ret = ReadRegisterMap(this->m_pCamera,this->m_offset,tier2inq);
		}
	}
_exit:
	DllTrace(DLL_TRACE_EXIT,"EXIT ControlSize::UpdateTier2(%d)\n",ret);
	return ret;
}

/**\brief This is a helper function that may make its way all the way up into the camera class.
 * \param pCamera The camera whose registers are to be read.
 * \param root_offset  The root (absolute) offset to start at, zero for none
 * \param regs    The NULL-terminated register mapping to read.
 *
 * This will read registers in <i>regs</i> offset from <i>root_offset</i> and store them
 * at the struct register_mapping::data pointer until a NULL data pointer is encountered
 *
 * \todo: NULL-termination is hacky, local, unscoped methods are hacky, consider pulling this into a dedicated utility class
 */
int ReadRegisterMap(C1394Camera *pCamera, unsigned long root_offset, struct register_mapping *regs)
{
	int i,ret = CAM_SUCCESS;

	DllTrace(DLL_TRACE_ENTER,"ENTER ReadRegisterMap(%08x,%08x,%08x)\n",
		pCamera,root_offset,regs);

	for(i=0; ret == CAM_SUCCESS && regs[i].data != NULL; i++)
	{
		DllTrace(DLL_TRACE_CHECK,"ReadRegisterMap: %03x -> %08x\n",
			regs[i].offset,regs[i].data);
		ret = pCamera->ReadQuadlet(
			root_offset + regs[i].offset,
			regs[i].data);

		if(ret != CAM_SUCCESS && regs[i].optional == 1)
		{
			DllTrace(DLL_TRACE_WARNING,
				"ReadRegisterMap: Warning: failed to read optional register %03x\n",
				regs[i].offset);
			*(regs[i].data) = 0;
			ret = CAM_SUCCESS;
		}
	}

	if(ret != CAM_SUCCESS)
		DllTrace(DLL_TRACE_ERROR,"ReadRegisterMap: Error %d while reading %08x + %03x\n",
			ret,root_offset,regs[i-1].offset);

	DllTrace(DLL_TRACE_EXIT,"EXIT ReadRegisterMap(%d)\n",ret);
	return ret;
}

/**\brief Encapsulate the bit twiddling necessary to push new parameters into the camera
 * \return CAM_SUCCESS on success, otherwise the same as WriteQuadlet(),ReadQuadlet()
 */
int C1394CameraControlSize::SetValues()
{
	int ret = 0;
	int i;

	if((m_StaValueSetting & 0x80000000) != 0)
	{
		// we need to hit the camera update bit before reading the Tier 1 inquiry regs
		if((ret = m_pCamera->WriteQuadlet(m_offset + 0x7C,0x40000000)) != CAM_SUCCESS)
			goto _exit;
		
		for(i=0; i<10; i++)
		{
			DllTrace(DLL_TRACE_CHECK,"ControlSize::SetValues: Probing value setting register (%d)...\n",i);
			if((ret = m_pCamera->ReadQuadlet(m_offset + 0x7C,&m_StaValueSetting)) != CAM_SUCCESS)
				goto _exit;
			
			if(!(m_StaValueSetting & 0x40000000))
				break;
		}
		DllTrace(DLL_TRACE_CHECK,"ControlSize::SetValues: Done Probing (%d iterations)\n",i);
		ret = CAM_SUCCESS;
	}
_exit:
	return ret;
}
