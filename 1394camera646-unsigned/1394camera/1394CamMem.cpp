/**\file 1394CamMem.cpp
 * \brief Implements On-Board Memory (For formats and Controls) for the C1394CameraClass
 * \ingroup cammem
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

/** \defgroup cammem Memory Manipulation
 *  \ingroup camcore
 *  \brief Camera setup memory manipulation.
 *
 * Some cameras have implemented the ability to store and retrieve configurations (format, 
 * mode, rate, shutter, btightness, etc) to and from on-board nonvaolatile memory.  These
 * functions interface to the controls for that functionality.
 */

/**\brief Get the number of available memory channels.
 * \ingroup cammem
 * \return The number of channels available, 0 if none, -1 on error
 *
 * Reads from the BASIC_FUNC_INQ register in search of the maximum memory channel,
 * which is bits 28-31 (the last four)
 */
int C1394Camera::MemGetNumChannels()
{
	return (m_cameraInitialized ? m_InqBasicFunc & 0xF : CAM_ERROR_NOT_INITIALIZED);
}

/**\brief Get the currently selected memory channel.
 * \ingroup cammem
 * \return current memory channel, 0 indicates factory defaults, -1 on error
 *
 * Reads from the CUR_MEM_CH = 0x624 register in search of the currently
 * loaded channel in bits 0-3.
 * which is bits 28-31 (the last four)
 */
int C1394Camera::MemGetCurrentChannel()
{
	ULONG ulRet, ulData;

	DllTrace(DLL_TRACE_ENTER,"ENTER MemGetCurrentChannel\n");
	if(CAM_SUCCESS != (ulRet = ReadQuadlet(0x624,&ulData)))
	{
		DllTrace(DLL_TRACE_ERROR,"MemGetCurrentChannel: error %08x on ReadQuadlet(0x624)\n",ulRet);
		return -1;
	}

	ulData = (ulData >> 28) & 15;

	DllTrace(DLL_TRACE_EXIT,"EXIT MemGetCurrentChannel (%d)\n",ulData);
	return (int) ulData;
}

/**\brief Load the values from a specified channel.
 * \ingroup cammem
 * \param channel Te channel to load
 * \return
 *  - CAM_SUCCESS: success
 *  - CAM_ERROR_PARAM_OUT_OF_RANGE : Invalid channel
 *  - Other Errors: originate from Read/WriteQuadlet, check GetLastError()
 *
 * Writes <i>channel</i> to the CUR_MEM_CH = 0x624 register, causing the contents thereof
 * to be loaded into the camera's control and status registers
 */
int C1394Camera::MemLoadChannel(int channel)
{
	ULONG ulRet, ulData;

	DllTrace(DLL_TRACE_ENTER,"ENTER MemLoadChannel (%d)\n",channel);

	if(channel < 0 || channel > MemGetNumChannels())
	{
		DllTrace(DLL_TRACE_ERROR,"MemLoadChannel: Invalid chanel: %d\n",channel);
		return CAM_ERROR_PARAM_OUT_OF_RANGE;
	}

	ulData = (unsigned long)(channel & 0xF) << 28;

	if(CAM_SUCCESS != (ulRet = WriteQuadlet(0x624, ulData)))
	{
		DllTrace(DLL_TRACE_ERROR,"MemLoadChannel: Error %08x on WriteQuadlet(0x624)\n");
		return ulRet;
	}

	DllTrace(DLL_TRACE_EXIT,"EXIT MemLoadChannel (%d)\n",channel);
	return CAM_SUCCESS;
}

/**\brief Store the current camera configuration to a specified channel.
 * \ingroup cammem
 * \param channel The channel to store the configuration to.
 * \return
 *  - CAM_SUCCESS: success
 *  - CAM_ERROR_PARAM_OUT_OF_RANGE : Invalid channel
 *  - Other Errors : originate from Read/WriteQuadlet, check GetLastError()
 *
 * Writes <i>channel</i> to the MEM_SAVE_CH = 0x620 register, then writes to MEMORY_SAVE = 0x618
 * causing the contents of the control and status registers to be saved to <i>channel</i> in the
 * camera's EEPROM.
 */
int C1394Camera::MemSaveChannel(int channel)
{
	ULONG ulRet, ulData;

	DllTrace(DLL_TRACE_ENTER,"ENTER MemSaveChannel (%d)\n",channel);

	if(channel <= 0 || channel > MemGetNumChannels())
	{
		DllTrace(DLL_TRACE_ERROR,"MemSaveChannel: Invalid chanel: %d\n",channel);
		return CAM_ERROR_PARAM_OUT_OF_RANGE;
	}

	ulData = (unsigned long)(channel & 0xF) << 28;

	if(CAM_SUCCESS != (ulRet = WriteQuadlet(0x620, ulData)))
	{
		DllTrace(DLL_TRACE_ERROR,"MemSaveChannel: Error %08x on WriteQuadlet(0x620)\n");
		return ulRet;
	}

	ulData = 0x80000000ul;

	if(CAM_SUCCESS != (ulRet = WriteQuadlet(0x618, ulData)))
	{
		DllTrace(DLL_TRACE_ERROR,"MemSaveChannel: Error %08x on WriteQuadlet(0x618)\n");
		return ulRet;
	}

	DllTrace(DLL_TRACE_EXIT,"EXIT MemSaveChannel (%d)\n",channel);
	return CAM_SUCCESS;
}
