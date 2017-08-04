/**\file 1394CameraControlTrigger.cpp
 * \brief Implementation of the C1394CameraControlTrigger class.
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

//////////////////////////////////////////////////////////////////////
// Construction/Destruction
// These aren't very interesting
//////////////////////////////////////////////////////////////////////

/**\brief Init a Trigger Control
 * \param pCamera the camera whose trigger needs controlling
 */
C1394CameraControlTrigger::C1394CameraControlTrigger(C1394Camera *pCamera):
	C1394CameraControl(pCamera,FEATURE_TRIGGER_MODE),
	m_pTriggerInquiry((TRIGGER_INQUIRY_REGISTER *)(&m_InquiryReg)),
	m_pTriggerStatus((TRIGGER_STATUS_REGISTER *)(&m_StatusReg))
{}

/**\brief Nothing to see here, move along */
C1394CameraControlTrigger::~C1394CameraControlTrigger()
{}

/**\brief Set the trigger mode
 * \param mode The mode to set
 * \param parameter The (optional) parameter to the mode
 * \return
 *   - CAM_ERROR_UNSUPPORTED if the trigger mode is not supported
 *   - Otherwise same as C1394CameraControl::SetStatus()
 */
int C1394CameraControlTrigger::SetMode(unsigned short mode, unsigned short parameter)
{
	if(HasMode(mode))
	{
		// maintain camera invariants
		if(mode == 2 && parameter < 2)
			parameter = 2;
		if(mode == 3 && parameter < 1)
			parameter = 1;
		if(parameter > 4095)
			parameter = 4095;
		m_pTriggerStatus->mode = mode;
		m_pTriggerStatus->parameter = parameter;
		return SetStatus();
	}
	return CAM_ERROR_UNSUPPORTED;
}

/**\brief Get the current Trigger Mode
 * \param mode Where to put the mode
 * \param parameter Where to put the parameter to the mode
 * \return
 *   - CAM_ERROR_UNSUPPORTED if the trigger mode is not supported
 *   - Otherwise CAM_SUCCESS;
 *
 * NULL parameters are silently ignored
 */
int C1394CameraControlTrigger::GetMode(unsigned short *mode, unsigned short *parameter)
{
	if(HasPresence())
	{
		if(mode)
			*mode = m_pTriggerStatus->mode;
		if(parameter)
			*parameter = m_pTriggerStatus->parameter;
		return CAM_SUCCESS;
	}
	return CAM_ERROR_UNSUPPORTED;
}

/**\brief Check for a supported trigger mode
 * \param mode The mode to check
 * \return boolean as to whether the mode is supported
 */
bool C1394CameraControlTrigger::HasMode(unsigned short mode)
{
	if(mode < 16)
	{
		return (m_pTriggerInquiry->modebits & (1 << (15-mode))) != 0;
	} else {
		return false;
	}
}

/**\brief Check whether the trigger control supports polarity inversion
 *
 * The polarity bit for the trigger control is the same as the automode bit
 * in the others, so this basically wraps C1394Camera::HasAutoMode()
 */
bool C1394CameraControlTrigger::HasPolarity()
{
	return m_pTriggerInquiry->polarity;
}

/**\brief Check whether the trigger control is using polarity inversion
 *
 * The polarity bit for the trigger control is the same as the automode bit
 * in the others, so this basically wraps C1394Camera::StatusAutoMode()
 */
bool C1394CameraControlTrigger::StatusPolarity()
{
	return m_pTriggerStatus->polarity;
}

/**\brief Set the Polarity Inversion Bit
 *
 * The polarity bit for the trigger control is the same as the automode bit
 * in the others, so this basically wraps C1394Camera::SetAutoMode()
 */
int C1394CameraControlTrigger::SetPolarity(BOOL polarity)
{
	m_pTriggerStatus->polarity = polarity;
	return SetStatus();
}

/**\brief The auto mode bit means something else for the trigger, so always return false */
bool C1394CameraControlTrigger::HasAutoMode()
{
	return false;
}

/**\brief The manual mode bit means something else for the trigger, so always return false */
bool C1394CameraControlTrigger::HasManualMode()
{
	return false;
}

/**\brief The auto mode bit means something else for the trigger, so always return CAM_ERROR_UNSUPPORTED */
int C1394CameraControlTrigger::SetAutoMode(BOOL on)
{
	return CAM_ERROR_UNSUPPORTED;
}

/**\brief The auto mode bit means something else for the trigger, so always return false */
bool C1394CameraControlTrigger::StatusAutoMode()
{
	return false;
}

/******************
 * IIDC DCAM 1.31 *
 ******************/

/**\brief Boolean accessor for whether the trigger supports reading the trigger pin value */
bool C1394CameraControlTrigger::HasValueReadout()
{
	return m_pTriggerInquiry->valueread != 0;
}

/**\brief Retrieve the current value of the trigger pin
 * \param val where to put the value (which will be 0 or 1)
 *
 * NULL parameter will be silently ignored, unsupported feature will yield 0 in val,
 * This is a simple accessor, to get the most up-to-date information, you must call
 * Status() first
 */
void C1394CameraControlTrigger::GetValueReadout(unsigned short *val)
{
	if(val)
		*val = (unsigned short)(this->HasValueReadout() ? m_pTriggerStatus->value : 0);
}

/**\brief Boolean accessor for whether the trigger supports software triggering */
bool C1394CameraControlTrigger::HasSoftwareTrigger()
{
	return this->HasTriggerSource(7);
}

/**\brief Boolean accessor for whether the trigger supports a particular source
 * \param src The source to check (0-7)
 */
bool C1394CameraControlTrigger::HasTriggerSource(unsigned short src)
{
	if(src < 8)
		return (m_pTriggerInquiry->sourcebits & (1 << (7-src))) != 0;
	else
		return false;
}

/**\brief Frob the software trigger
 * \return
 *   - CAM_ERROR_NOT_INITIALIZED if trigger input 7 is not selected
 *   - CAM_ERROR_UNSUPPORTED if the camera does not claim to support SW triggering
 */
int  C1394CameraControlTrigger::DoSoftwareTrigger()
{
	if(this->HasSoftwareTrigger())
	{
		unsigned short src;
		this->GetTriggerSource(&src);
		if(src == 7)
			return m_pCamera->WriteQuadlet(0x062C,0x80000000);
		return CAM_ERROR_NOT_INITIALIZED;
	}
	return CAM_ERROR_UNSUPPORTED;
}

/**\brief Retrieve the currently selected trigger source */
void C1394CameraControlTrigger::GetTriggerSource(unsigned short *src)
{
	if(src)
		*src = m_pTriggerStatus->source;
}

/**\brief Set the Trigger Source 
 * \param src The source to select (0-7)
 * \return
 *  - CAM_ERROR_UNSUPPORTED: The camera does not claim to support the requested input source
 *  - Otherwise, the same as C1394CameraControl::SetValue()
 */
int  C1394CameraControlTrigger::SetTriggerSource(unsigned short src)
{
	if(this->HasTriggerSource(src))
	{
		m_pTriggerStatus->source = src;
		return SetStatus();
	} else {
		return CAM_ERROR_UNSUPPORTED;
	}
}
