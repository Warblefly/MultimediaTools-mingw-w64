/**\file 1394CamFMR.cpp
 * \brief Implements Format, Mode, Rate manipulation for the C1394Camera class.
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

/** \defgroup camfmr Video Format Controls
 *  \ingroup camcore
 *  \brief Protected accessors and mutators for manipulation of video settings.
 */

/**\brief Set the Video Format
 * \ingroup camfmr
 * \param format The format in [0,7] that you wish to use
 * \return
 *  - CAM_SUCCESS: Format selection is successful.
 *  - CAM_ERROR_NOT_INITIALIZED: No camera celected and/or camera not initialized
 *  - CAM_ERROR_BUSY: The camera is actively acquiring images
 *  - CAM_ERROR: WriteRegister() has failed, use GetLastError() to find out why.
 *
 *  For a valid format selection, the first valid mode and rate will be automatically 
 *  selected to maintain internal consistency.
 */
int C1394Camera::SetVideoFormat(unsigned long format)
{
	DWORD dwRet;
	int ret = CAM_ERROR;
	
	DllTrace(DLL_TRACE_ENTER,"ENTER SetVideoFormat (%d)\n",format);
	
	if (!m_pName || !m_cameraInitialized)
	{
		DllTrace(DLL_TRACE_ERROR,"SetVideoFormat: Camera is not initialized\n");
		ret = CAM_ERROR_NOT_INITIALIZED;
		goto _exit;
	}
	
	if(m_hDeviceAcquisition != INVALID_HANDLE_VALUE)
	{
		DllTrace(DLL_TRACE_ERROR,"SetVideoFormat: Camera is busy\n");
		ret = CAM_ERROR_BUSY;
		goto _exit;
	}
	
	if(this->HasVideoFormat(format))
	{
		// shift it over into the most significant bits
		if(dwRet = WriteQuadlet(0x608, format << 29))
		{
			DllTrace(DLL_TRACE_ERROR,"SetVideoFormat: error %08x on WriteRegister\n",dwRet);
			ret = CAM_ERROR;
		} else {
			m_videoFormat = format;
			// update parameters is a little funky, but leave it anyway
			UpdateParameters();
			ret = CAM_SUCCESS;
		}
	} else {
		DllTrace(DLL_TRACE_ERROR,"SetVideoFormat: Format %d not supported\n",format);
		ret = CAM_ERROR_INVALID_VIDEO_SETTINGS;
	}
_exit:
    DllTrace(DLL_TRACE_CHECK,"SetVideoFormat(%d) -> %d",format,ret);
	DllTrace(DLL_TRACE_EXIT,"EXIT SetVideoFormat (%d)\n",ret);
	return ret;
}

/**\brief Set the Video Mode
 * \ingroup camfmr
 * \param mode The desired mode in [0,7] that you wish to set
 * \return
 *  - CAM_SUCCESS: Mode selection completed.
 *  - CAM_ERROR_NOT_INITIALIZED: No camera celected and/or camera not initialized
 *  - CAM_ERROR_BUSY: The camera is actively acquiring images
 *  - CAM_ERROR: WriteRegister has failed, use GetLastError() to find out why.
 *
 * This function is invalid for Format 7
 *
 * For a valid mode selection, the first valid framerate will be selected for consistency
 */
int C1394Camera::SetVideoMode(unsigned long mode)
{
	DWORD dwRet;
	int ret = CAM_ERROR;
	
	DllTrace(DLL_TRACE_ENTER,"ENTER SetVideoMode (%d)\n",mode);
	
	if (!m_pName || !m_cameraInitialized)
	{
		DllTrace(DLL_TRACE_ERROR,"SetVideoMode: Camera is not initialized\n");
		ret = CAM_ERROR_NOT_INITIALIZED;
		goto _exit;
	}
	
	if(m_hDeviceAcquisition != INVALID_HANDLE_VALUE)
	{
		DllTrace(DLL_TRACE_ERROR,"SetVideoMode: Camera is busy\n");
		ret = CAM_ERROR_BUSY;
		goto _exit;
	}
	
	if(this->HasVideoMode(m_videoFormat,mode))
	{
		if(dwRet = WriteQuadlet(0x604, mode << 29))
		{
			DllTrace(DLL_TRACE_ERROR,"SetVideoMode: error %08x on WriteRegister\n",dwRet);
			ret = CAM_ERROR;
		} else {
			m_videoMode = mode;
			UpdateParameters();
			ret = CAM_SUCCESS;
		}
	} else {
		DllTrace(DLL_TRACE_ERROR,"SetVideoMode: mode %d is not supported under format %d\n",mode,m_videoFormat);
		ret = CAM_ERROR_INVALID_VIDEO_SETTINGS;
	}
_exit:
    DllTrace(DLL_TRACE_CHECK,"SetVideoMode(%d) -> %d",mode,ret);
	DllTrace(DLL_TRACE_EXIT,"EXIT SetVideoMode (%d)\n",ret);
	return ret;
}


/**\brief Set the Video Frame Rate
 * \ingroup camfmr
 * \param rate The desired frame rate in [0,7] that you wish to set
 * \return 
 *  - CAM_SUCCESS: All good.
 *  - CAM_ERROR_NOT_INITIALIZED: No camera celected and/or camera not initialized
 *  - CAM_ERROR_BUSY: The camera is actively acquiring images
 *  - CAM_ERROR: WriteRegister has failed, use GetLastError() to find out why.
 *
 * This function is invalid for Format 7
 */
int C1394Camera::SetVideoFrameRate(unsigned long rate)
{
	DWORD dwRet;
	int ret = CAM_ERROR;
	
	DllTrace(DLL_TRACE_ENTER,"ENTER SetVideoFramteRate (%d)\n",rate);
	
	if (!m_pName || !m_cameraInitialized)
	{
		DllTrace(DLL_TRACE_ERROR,"SetVideoFrameRate: Camera is not initialized\n");
		ret = CAM_ERROR_NOT_INITIALIZED;
		goto _exit;
	}
	
	if(m_hDeviceAcquisition != INVALID_HANDLE_VALUE)
	{
		DllTrace(DLL_TRACE_ERROR,"SetVideoFrameRate: Camera is busy\n");
		ret = CAM_ERROR_BUSY;
		goto _exit;
	}
	
	if(m_videoFormat != 7) 
	{
		if(this->HasVideoFrameRate(m_videoFormat,m_videoMode,rate))
		{
			if(dwRet = WriteQuadlet(0x600, rate << 29))
			{
				DllTrace(DLL_TRACE_ERROR,"SetVideoFrameRate: error %08x on WriteRegister\n",dwRet);
				ret = CAM_ERROR;
			} else {
				m_videoFrameRate = rate;
				UpdateParameters();
				ret = CAM_SUCCESS;
			}
		} else {
			DllTrace(DLL_TRACE_ERROR,"SetVideoFrameRate: rate %d unsupported\n",rate);
			ret = CAM_ERROR_INVALID_VIDEO_SETTINGS;
		}
	} else {
		DllTrace(DLL_TRACE_ERROR,"SetVideoFramerate: it is not meaningful to set the framerate for format 7\n");
		ret = CAM_ERROR_INVALID_VIDEO_SETTINGS;
	}
	
_exit:
    DllTrace(DLL_TRACE_CHECK,"SetVideoFrameRate(%d) -> %d",rate,ret);
    DllTrace(DLL_TRACE_EXIT,"EXIT SetVideoFrameRate (%d)\n",ret);
	return ret;
}


/**\brief get the current video format.
 * \ingroup camfmr
 * \return The current format, -1 if none selected.
 */
int C1394Camera::GetVideoFormat()
{
	return m_videoFormat;
}


/**\brief get the current video mode.
 * \ingroup camfmr
 * \return The current format, -1 if none selected.
 */
int C1394Camera::GetVideoMode()
{
	return m_videoMode;
}


/**\brief get the current video format.
 * \ingroup camfmr
 * \return The current format, -1 if none selected.
 */
int C1394Camera::GetVideoFrameRate()
{
	return m_videoFrameRate;
}


/**\brief Reads the format register and fills in m_InqVideoFormats
 * \ingroup camfmr
 * \return TRUE if the checks were successful, FALSE on a Read error
 */
BOOL C1394Camera::InquireVideoFormats()
{
	DWORD dwRet;
	
	// Read video formats at 0x100
	m_InqVideoFormats = 0;
	if(dwRet = ReadQuadlet(0x100,&m_InqVideoFormats))
	{
		DllTrace(DLL_TRACE_ERROR,"InquireVideoFormats: Error %08x on ReadRegister(0x100)\n",dwRet);
		return FALSE;
	} else {
		DllTrace(DLL_TRACE_CHECK,"InquireVideoFormats: We have 0x%08x\n",m_InqVideoFormats);
		//return TRUE; ///AAAAAAH!
	}
	
	// Read the current video format at 0x608
	if(dwRet = ReadQuadlet(0x608,(unsigned long *) &this->m_videoFormat))
	{
		DllTrace(DLL_TRACE_ERROR,"InquireVideoFormats: error %08x on ReadRegister\n",dwRet);
		this->m_videoFormat = -1;
		return FALSE;
	} else {
		this->m_videoFormat >>= 29;
		this->m_videoFormat &= 0x7;
		DllTrace(DLL_TRACE_CHECK,"InquireVideoFormats: Read current format as %d\n",m_videoFormat);
	}

	return TRUE;
}

/**\brief Check whether the provided camera settings are valid
 * \ingroup camfmr
 * \param format The format to check
 * \return Whether the settings are supported by the camera
 */
BOOL C1394Camera::HasVideoFormat(unsigned long format)
{
	BOOL bRet;

	if(format >= 8)
	{
		DllTrace(DLL_TRACE_WARNING,"HasVideoFormat: Invalid Format: %d\n",format);
		return FALSE;
	}
	
	bRet = (m_InqVideoFormats >> (31-format)) & 0x01;

	// QUIRK Check: All Formats must have at least one valid mode.
	if(bRet && ((m_InqVideoModes[format] & 0xFF000000) == 0))
	{
		DllTrace(DLL_TRACE_ALWAYS,"HasVideoFormat: QUIRK: Format %d presence in V_FORMAT_INQ (%08x) disagrees with V_MODE_INQ_%d(%08x)\n",
			format,m_InqVideoFormats,format,m_InqVideoModes[format]);
		bRet = FALSE;
	}

	return bRet;
}

/**\brief Reads the mode registers and fills in m_InqVideoModes
 * \ingroup camfmr
 * \return TRUE if the checks were successful, FALSE on a Read error
 */
BOOL C1394Camera::InquireVideoModes()
{
	ULONG format;
	DWORD dwRet;
	
	for (format=0; format<8; format++)
	{
		m_InqVideoModes[format] = 0xFF000000;
		if (this->HasVideoFormat(format))
		{
			// inquire video mode for current format
			DllTrace(DLL_TRACE_CHECK,"InquireVideoModes: Checking Format %d\n",format);
			if(dwRet = ReadQuadlet(0x180+format*4,&m_InqVideoModes[format]))
			{
				DllTrace(DLL_TRACE_ERROR,"InquireVideoModes, Error %08x on ReadRegister(%03x)\n",dwRet,0x180+format*4);
				return FALSE;
			} else {
				DllTrace(DLL_TRACE_CHECK,"InquireVideoModes: We have %08x for format %d\n",m_InqVideoModes[format],format);
			}
		} else {
			m_InqVideoModes[format] = 0;
		}
	}
	
	// Read the current video mode at 0x604
	if(dwRet = ReadQuadlet(0x604,(unsigned long *) &this->m_videoMode))
	{
		DllTrace(DLL_TRACE_ERROR,"InquireVideoModes: error %08x on ReadRegister\n",dwRet);
		this->m_videoMode = -1;
		return FALSE;
	} else {
		this->m_videoMode >>= 29;
		this->m_videoMode &= 0x7;
		DllTrace(DLL_TRACE_CHECK,"InquireVideoModes: Read current Mode as %d\n",m_videoMode);
	}
	
	return TRUE;
}

/**\brief Check whether the provided camera settings are valid
 * \ingroup camfmr
 * \param format The format to check
 * \param mode The mode to check
 * \return Whether the settings are supported by the camera
 */
BOOL C1394Camera::HasVideoMode(unsigned long format, unsigned long mode)
{
	BOOL bRet;
	if(format >= 8 || mode >= 8)
	{
		DllTrace(DLL_TRACE_WARNING,"HasVideoMode: Invalid Format,Mode: %d,%d\n",format,mode);
		return FALSE;
	}
	bRet = (m_InqVideoModes[format] >> (31-mode)) & 0x01;

	// QUIRK Check: All Modes must have at least one valid framerate.
	if(format < 3 && bRet && ((m_InqVideoRates[format][mode] & 0xFF000000) == 0))
	{
		DllTrace(DLL_TRACE_ALWAYS,
			"HasVideoFormat: QUIRK: Mode %d:%d presence in V_MODE_INQ_%d(%08x) disagrees with V_RATE_INQ_%d_%d = %08x\n",
			format,mode,format,m_InqVideoModes[format],format,mode,m_InqVideoRates[format][mode]);
		bRet = FALSE;
	}

	return bRet;
}

/**\brief Reads the rate registers and fills in m_InqVideoRates
 * \ingroup camfmr
 * \return TRUE if the checks were successful, FALSE on a Read error
 */
BOOL C1394Camera::InquireVideoRates()
{
	ULONG format, mode;
	DWORD dwRet;
	
	for (format=0; format<8; format++)
	{
		for (mode=0; mode<8; mode++)
		{
			m_InqVideoRates[format][mode] = 0xFF000000;
			if(this->HasVideoMode(format,mode))
			{
				// inquire video mode for current format
				if(dwRet = ReadQuadlet(0x200+format*32+mode*4,&m_InqVideoRates[format][mode]))
				{
					DllTrace(DLL_TRACE_ERROR,"InquireVideoRates, Error %08x on ReadRegister(%03x)\n",dwRet,0x200+format*32+mode*4);
					return FALSE;
				} else {
					DllTrace(DLL_TRACE_CHECK,"InquireVideoRates: We have %08x for %d,%d\n",m_InqVideoRates[format][mode],format,mode);
					if(format <= 2)
					{
						// Quirk-Check the rates against m_maxSpeed;
						ULONG rate;
						ULONG isomaxBPF= 1000 * m_maxSpeed;
						ULONG absmaxBPF= 1250 * m_maxSpeed;
						for(rate=0; rate<8; rate++)
						{
							if(this->HasVideoFrameRate(format,mode,rate))
							{
								ULONG BPF = 4 * dc1394GetQuadletsPerPacket(format,mode,rate);
								if(BPF > isomaxBPF)
								{
									if(BPF < absmaxBPF)
									{
										DllTrace(DLL_TRACE_ALWAYS,"QUIRK: Camera reports supported mode %d,%d,%d which may work at but otherwise exceeds strict 1394 bus spec at %d00mbps (%d > %d bpf)\n",
											format,mode,rate,m_maxSpeed,BPF,isomaxBPF);
									}
									DllTrace(DLL_TRACE_WARNING,"InquireVideoRates: Warning: disabling mode %d,%d,%d which exceeds maximum available bandwidth at %d00mbps (%d > %d)\n",
                                                                format,mode,rate,m_maxSpeed,BPF,absmaxBPF);
									m_InqVideoRates[format][mode] &= ~(0x80000000 >> rate);
								}
							}
						}
					}
				}
			} else {
				m_InqVideoRates[format][mode] = 0;
			}
		}
	}
	
	// Read the current video rate at 0x600
	if(dwRet = ReadQuadlet(0x600,(unsigned long *) &this->m_videoFrameRate))
	{
		DllTrace(DLL_TRACE_ERROR,"InquireVideoFrameRates: error %08x on ReadRegister\n",dwRet);
		this->m_videoFrameRate = -1;
		return FALSE;
	} else {
		this->m_videoFrameRate >>= 29;
		this->m_videoFrameRate &= 0x7;
		DllTrace(DLL_TRACE_CHECK,"InquireVideoFrameRates: Read current FrameRate as %d\n",m_videoFrameRate);
	}
	
	return TRUE;
}

/**\brief Check whether the provided camera settings are valid
 * \ingroup camfmr
 * \param format The format to check
 * \param mode The mode to check
 * \param rate The rate to check
 * \return Whether the settings are supported by the camera
 *
 * The notion of video frame rate does not apply to any but the first three video formats
 */
BOOL C1394Camera::HasVideoFrameRate(unsigned long format, unsigned long mode, unsigned long rate)
{
	if(format >= 3 || mode >= 8 || rate >= 8)
	{
		DllTrace(DLL_TRACE_WARNING,"HasVideoFrameRate: Invalid Format,Mode,Rate: %d,%d,%d\n",format,mode,rate);
		return FALSE;
	}
	return (m_InqVideoRates[format][mode] >> (31-rate)) & 0x01;
}

/**\brief Retrieve the width and height of the currently configured video mode
 * \ingroup camfmr
 * \param pWidth Receives the width, in pixels, of the current video mode, zero if none selected
 * \param pHeight Receives the height, in pixels, of the current video mode, zero if none selected
 */
void C1394Camera::GetVideoFrameDimensions(unsigned long *pWidth, unsigned long *pHeight)
{
	if(!pWidth || !pHeight)
	{
		DllTrace(DLL_TRACE_ERROR,"GetVideoFrameDimensions: Invalid Argument(s) %08x %08x\n",pWidth,pHeight);
	} else {
		*pWidth = m_width;
		*pHeight = m_height;
	}
}

/**\brief retrieve the effective data depth, in bits of the current video mode
 * \param depth Where to put it
 *
 * For IIDC 1.31 cameras, this tells us basically how many bits per channel
 * in the image data are actually representative of the image.  For instance,
 * many 16-bit formats actually produce 12-bit data
 */
void C1394Camera::GetVideoDataDepth(unsigned short *depth)
{
	if(depth == NULL)
		return;
	
	switch(this->m_videoFormat)
	{
	case 0:
	case 1:
	case 2:
		if(this->m_StatusVideoDepth != 0)
		{
			*depth = (unsigned short)((this->m_StatusVideoDepth >> 24) & 0x00FF);
		} else {
			if( this->m_colorCode == COLOR_CODE_Y16 ||
				this->m_colorCode == COLOR_CODE_RGB16 ||
				this->m_colorCode == COLOR_CODE_RAW16 ||
				this->m_colorCode == COLOR_CODE_Y16_SIGNED ||
				this->m_colorCode == COLOR_CODE_RGB16_SIGNED)
				*depth = 16;
			else
				*depth = 8;
		}
		break;
	case 7:
		this->m_pControlSize->GetDataDepth(depth);
		break;
	default:
		*depth = 0;
	}
}

/**\brief Maintains internal consistency of variables surrounding current video settings
 * \param UpdateOnly If TRUE, then no active changes are made to the settings, values are simply
 * retrieved.  Default is FALSE, causing a full sanity enforcement.
 * \ingroup camfmr
 *
 * This ensures that a valid combination of format,mode,and rate are selected and 
 * populates m_width, m_height, m_maxBytes, m_maxBufferSize accordingly.  Since this both 
 * calls and is called by the various SetVideoBlah functions and the ControlSize class, care
 * must be take to avoid recursive stupidity.
 */
void C1394Camera::UpdateParameters(BOOL UpdateOnly)
{
	VIDEO_MODE_DESCRIPTOR desc;
	ULONG qpp;
	
	if(!UpdateOnly && !CheckVideoSettings())
	{
		int i;
		DllTrace(DLL_TRACE_WARNING,
				"UpdateParameters: Video settings (%d,%d,%d) are invalid, seeking nearest neighbor\n",
				m_videoFormat, m_videoMode, m_videoFrameRate);
		if(!this->HasVideoFormat(m_videoFormat))
		{
			for(i=0; i<8; i++)
			{
				if(i != 6 && this->HasVideoFormat(i))
				{
					this->SetVideoFormat(i);
					break;
				}
			}
			return;
		}
		if(!this->HasVideoMode(m_videoFormat,m_videoMode))
		{
			for(i=0; i<8; i++)
			{
				if(this->HasVideoMode(m_videoFormat,i))
				{
					this->SetVideoMode(i);
					break;
					
				}
			}
			return;
		}
		if(m_videoFormat != 7)
		{
			if(!this->HasVideoFrameRate(m_videoFormat,m_videoMode,m_videoFrameRate))
			{
				for(i=0; i<8; i++)
				{
					if(this->HasVideoFrameRate(m_videoFormat,m_videoMode,i))
					{
						this->SetVideoFrameRate(i);
						break;
					}
				}
				return;
			}
		} else {
			m_videoFrameRate = -1;
		}
		
		if(!CheckVideoSettings())
		{
			DllTrace(DLL_TRACE_ERROR,"UpdateParameters: Unable to select a valid format!\n");
			return;
		}
		DllTrace(DLL_TRACE_CHECK,"UpdateParameters: Auto-selected %d,%d,%d\n",
			m_videoFormat,m_videoMode,m_videoFrameRate);
	}
	
	// now update the critical members
	if (m_videoFormat != 7)
	{
		if(dc1394GetModeDescriptor(m_videoFormat,m_videoMode,&desc) < 0)
			m_width = m_height = 0;
		m_width = desc.width;
		m_height = desc.height;
		m_colorCode = desc.colorcode;
		m_maxBufferSize = dc1394GetBufferSize(m_videoFormat, m_videoMode);
		
		qpp = dc1394GetQuadletsPerPacket(m_videoFormat,m_videoMode,m_videoFrameRate);
		m_maxBytes = 4 * qpp;
		// update the video depth register
		this->m_StatusVideoDepth = 0;
		this->ReadQuadlet(0x0630,&this->m_StatusVideoDepth);
	} else {
		unsigned short w,h,bpp;
		unsigned long ppf,bpf,n;
		unsigned long offset = this->m_InqVideoRates[this->m_videoFormat][this->m_videoMode];
		offset <<= 2;
		offset |= 0xf0000000;

		// note: SetOffset works because C1394Camera is a friend of C1394CameraControlSize
		if(!UpdateOnly && m_pControlSize->SetOffset(offset) != CAM_SUCCESS)
		{
			DllTrace(DLL_TRACE_ERROR,"UpdateParameters: Error on ControlSize::SetOffset");
			///\todo: Something smarter that bail-without-recourse in UpdateParameters when ControlSize::SetOffset fails
			return;
		}
		this->m_pControlSize->GetSize(&w,&h);
		this->m_pControlSize->GetBytesPerPacket(&bpp);
		this->m_pControlSize->GetPacketsPerFrame(&ppf);
		this->m_pControlSize->GetBytesPerFrame(&bpf,NULL);  // what if we have images > 4GB?
		this->m_pControlSize->GetColorCode(&this->m_colorCode);

		// now for a little sanity checking for quirky cameras
		n = dc1394GetBitsPerPixel(this->m_colorCode);
		n *= w * h;
		n /= 8;
		if(bpf < n)
		{
			DllTrace(DLL_TRACE_ALWAYS,
					"QUIRK: format 7 reported bytes per frame (%d) is less than computed bytes per frame (%d)\n",
					bpf,n);
			bpf = n;
		}

		n = (bpf + bpp - 1)/bpp;
		if(ppf != n)
		{
			DllTrace(DLL_TRACE_ALWAYS,
					"QUIRK: format 7 reported packets per frame (%d) is incorrect (should be %d)\n",
					ppf,n);
			ppf = n;
		}

		m_maxBytes = bpp;
		m_width = w;
		m_height = h;
		m_maxBufferSize = bpp * ppf;
		DllTrace(DLL_TRACE_CHECK,"UpdateParameters: Format 7 (%dx%d,%d:%d)\n",
			w,h,bpp * ppf, bpp);
	}
	DllTrace(DLL_TRACE_CHECK,"UpdateParameters: Using %dx%d, %d:%d\n",
		m_width,m_height,m_maxBufferSize,m_maxBytes);
}

/** \brief Check to make sure the selected video settings are valid
 *  \return boolean true if things are okay
 */
bool C1394Camera::CheckVideoSettings()
{
	bool bRet = false;
	if(m_cameraInitialized)
	{
		if(m_videoFormat != 7)
			bRet = (this->HasVideoFrameRate(m_videoFormat,m_videoMode,m_videoFrameRate) == TRUE);
		else
			bRet = (this->HasVideoMode(m_videoFormat,m_videoMode) == TRUE);

		// check the status register for the hell of it
		if(StatusVideoErrors(TRUE) && bRet)
		{
			DllTrace(DLL_TRACE_WARNING,"CheckVideoSettings: WARNING: Camera is angry about %d,%d,%d, but video flags disagree\n",
				m_videoFormat, m_videoMode, m_videoFrameRate);
		}
	}

	return bRet;
}

/**\brief Return whether there are video errors according to the error register
 * \param Refresh Boolean whether to re-read the registers or simply probe the bits
 * \return boolean state of the Video Error Register, if Valid
 */
bool C1394Camera::StatusVideoErrors(BOOL Refresh)
{
	if(!this->m_cameraInitialized || (this->m_InqBasicFunc & 0x40000000) == 0)
		return false;
	
	if(Refresh == TRUE)
	{
		if(this->ReadQuadlet(0x628,&this->m_StatusVideoError) != CAM_SUCCESS)
			return false;
	}	
	return (m_StatusVideoError & 0x80000000) != 0;
}