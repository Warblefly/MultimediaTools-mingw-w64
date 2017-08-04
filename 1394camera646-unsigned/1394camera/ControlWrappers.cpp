/**\file ControlWrappers.cpp
 * \brief Implements accessors/mutators for aggregated C1394CameraControl instances
 * \ingroup camfeat
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

/**\brief Poke the Inquiry and Status registers for all supported features
 * \param bForceAll If TRUE, then we ignore the FEATURE_[HI,LO]_INQ bitflags and check all the possible controls no matter what
 */
void C1394Camera::RefreshControlRegisters(BOOL bForceAll)
{
	int i;
	
	for(i=0; i<FEATURE_NUM_FEATURES; i++)
	{
		if(m_pControls[i] != NULL)
		{
			if(bForceAll || m_pControls[i] != NULL)
			{
				m_pControls[i]->Inquire();
				m_pControls[i]->Status();
			}
		}
	}

	if(m_pControlTrigger)
	{
		m_pControlTrigger->Inquire();
		m_pControlTrigger->Status();
	}
}

/**\brief Determine, from the feature availability registers, whether a feature is available
 * \param fID The feature to probe
 * \return boolena availability according to the FEATURE_[HI,LO]_INQ registers
 */
bool C1394Camera::HasFeature(CAMERA_FEATURE fID)
{
	int i = (int) fID;
	if(i >= 0 && i < FEATURE_NUM_FEATURES)
		return ((i < 32 ? m_InqFeatureHi : m_InqFeatureLo) & (0x80000000 >> (i & 31))) != 0;
	return false;
}

/**\brief Accessor for the Trigger control */
C1394CameraControlTrigger *C1394Camera::GetCameraControlTrigger()
{
	return m_pControlTrigger;
}

/**\brief Accessor for the Partial Scan control */
C1394CameraControlSize *C1394Camera::GetCameraControlSize()
{
	return m_pControlSize;
}

/**\brief One-line boolean to check for the presence of advanced features */
bool C1394Camera::HasAdvancedFeature()
{
	return (m_cameraInitialized && (m_InqBasicFunc & 0x80000000) != 0);
}

/**\brief One-line boolean to check for the presence of optional features */
bool C1394Camera::HasOptionalFeatures()
{
	return (m_cameraInitialized && (m_InqBasicFunc & 0x10000000) != 0);
}

/**\brief One-line boolean to check for the presence of Parallel I/O */
bool C1394Camera::HasPIO()
{
	return (m_cameraInitialized && (this->m_InqOptionalFunc & 0x40000000) != 0);
}

/**\brief One-line boolean to check for the presence of Serial I/O */
bool C1394Camera::HasSIO()
{
	return (m_cameraInitialized && (this->m_InqOptionalFunc & 0x20000000) != 0);
}

/**\brief One-line boolean to check for the presence of Strobe I/O */
bool C1394Camera::HasStrobe()
{
	return (m_cameraInitialized && (this->m_InqOptionalFunc & 0x10000000) != 0);
}

/**\brief Retrieve the register offset for advanced feature
 * \return absolute offset into the register space (in bytes, suitable for use with ReadQuadlet() and WriteQuadlet(), or 0 if not supported
 */
unsigned long C1394Camera::GetAdvancedFeatureOffset()
{
	if(this->HasAdvancedFeature())
		return this->m_AdvFuncOffset;
	return 0;
}


/**\brief Retrieve the register offset for the PIO Control Registers
 * \return absolute offset into the register space (in bytes, suitable for use with ReadQuadlet() and WriteQuadlet(), or 0 if not supported
 */
unsigned long C1394Camera::GetPIOControlOffset()
{
	if(this->HasPIO())
		return this->m_PIOFuncOffset;
	return 0;
}

/**\brief Retrieve the register offset for the SIO Control Registers
 * \return absolute offset into the register space (in bytes, suitable for use with ReadQuadlet() and WriteQuadlet(), or 0 if not supported
 */
unsigned long C1394Camera::GetSIOControlOffset()
{
	if(this->HasSIO())
		return this->m_SIOFuncOffset;
	return 0;
}

/**\brief Retrieve the register offset for the Strobe Control Registers
 * \return absolute offset into the register space (in bytes, suitable for use with ReadQuadlet() and WriteQuadlet(), or 0 if not supported
 */
unsigned long C1394Camera::GetStrobeControlOffset()
{
	if(this->HasStrobe())
		return this->m_StrobeFuncOffset;
	return 0;
}

/**\brief Retrieve the Strobe Control Class for the indicated strobe control
 * \param fID The feature control to retrieve
 * \return NULL if the control is unsupported, otherwise, a pointer to the proper class
 *
 * NOTE: this slightly breaks OO encapsulation by exposing a pointer to a private member, but
 * the register state on the camera has side effects that require that exactly one class instance
 * own the control at a time
 */
C1394CameraControl *C1394Camera::GetCameraControl(CAMERA_FEATURE fID)
{
	if(fID < FEATURE_NUM_FEATURES)
		return this->m_pControls[(int)(fID)];
	else
		return NULL;
}

/**\brief Retrieve the Strobe Control Class for the indicated strobe control
 * \param strobeID the strobe control to select (0-3)
 * \return NULL if the strobe control is unsupported, otherwise, a pointer to the proper class
 *
 * NOTE: this slightly breaks OO encapsulation by exposing a pointer to a private member, but
 * the register state on the camera has side effects that require that exactly one class instance
 * own the control at a time
 */
C1394CameraControlStrobe *C1394Camera::GetStrobeControl(unsigned long strobeID)
{
	if(strobeID > 3 || !this->HasStrobe() || !(this->m_StrobeRootCaps & (0x80000000 >> strobeID)))
	{
		return NULL;
	} else {
		if(	this->m_controlStrobes[strobeID] == NULL ||
			this->m_controlStrobes[strobeID]->Inquire() != CAM_SUCCESS)
			return NULL;
		return this->m_controlStrobes[strobeID];
	}
}

/**\brief Return whether there is a problem with a feature according to its error register
 * \param fID The Feature to Check
 * \param Refresh Boolean whether to re-read the registers or simply probe the bits
 * \return boolean state of the Feature Error Bit, if Valid
 *
 * This is unfortunately as ambiguous in the specification as it is here.
 * It basically says, "If this bit is high, <i>something</i> is wrong
 * with the feature".  There is no known option for getting extended info
 */
bool C1394Camera::StatusFeatureError(CAMERA_FEATURE fID, BOOL Refresh)
{
	int i = (int)(fID);
	if(!this->m_cameraInitialized || (this->m_InqBasicFunc & 0x20000000) == 0)
		return false;
	
	if(fID >= FEATURE_NUM_FEATURES)
		return false;
	
	if(Refresh == TRUE)
	{
		if(this->ReadQuadlet(0x640,&this->m_StatusFeatureErrorHi) != CAM_SUCCESS)
			return false;
		if(this->ReadQuadlet(0x644,&this->m_StatusFeatureErrorLo) != CAM_SUCCESS)
			return false;
	}
	return ((i < 32 ? this->m_StatusFeatureErrorHi : this->m_StatusFeatureErrorLo) & (0x80000000 >> (i&31))) != 0;
}