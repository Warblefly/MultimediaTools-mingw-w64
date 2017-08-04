/**\file 1394CameraControlStrobe.cpp
 * \brief Implementation of the C1394CameraControlStrobe class.
 * \ingroup strobe
 *
 * The strobe class is very close to the Trigger class, but different enough to
 * require a separate subclass.
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

/**\defgroup strobe Strobe I/O Functionality
 * \ingroup camoptional
 *
 * The strobe outputs seem to be a set of controls to output a square pulse
 * with configurable delay and duration from the core frame clock
 */


//////////////////////////////////////////////////////////////////////
// Construction/Destruction
// These aren't very interesting
//////////////////////////////////////////////////////////////////////

/**\brief Init a strobe control
 * \param pCamera The parent camera
 * \param strobeID The strobe number (0-3) to control
 */
C1394CameraControlStrobe::C1394CameraControlStrobe(C1394Camera *pCamera, unsigned long strobeID):
	C1394CameraControl(pCamera,FEATURE_INVALID_FEATURE),m_strobeID(strobeID)
{}


C1394CameraControlStrobe::~C1394CameraControlStrobe()
{}

/**\brief Check whether the Strobe control supports polarity inversion
 *
 * The polarity bit for the Strobe control is the same as the automode bit
 * in the others, so this basically wraps C1394Camera::HasAutoMode()
 */
bool C1394CameraControlStrobe::HasPolarity()
{
  return C1394CameraControl::HasAutoMode();
}

/**\brief Check whether the Strobe control is using polarity inversion
 *
 * The polarity bit for the Strobe control is the same as the automode bit
 * in the others, so this basically wraps C1394Camera::StatusAutoMode()
 */
bool C1394CameraControlStrobe::StatusPolarity()
{
  return C1394CameraControl::StatusAutoMode();
}

/**\brief Set the Polarity Inversion Bit
 *
 * The polarity bit for the Strobe control is the same as the automode bit
 * in the others, so this basically wraps C1394Camera::SetAutoMode()
 */
int C1394CameraControlStrobe::SetPolarity(BOOL polarity)
{
  return C1394CameraControl::SetAutoMode(polarity);
}

/**\brief The auto mode bit means something else for the Strobe, so always return false */
bool C1394CameraControlStrobe::HasAutoMode()
{
  return false;
}

/**\brief The manual mode bit means something else for the Strobe, so always return false */
bool C1394CameraControlStrobe::HasManualMode()
{
  return false;
}

/**\brief The auto mode bit means something else for the Strobe, so always return CAM_ERROR_UNSUPPORTED */
int C1394CameraControlStrobe::SetAutoMode(BOOL on)
{
  return CAM_ERROR_UNSUPPORTED;
}

/**\brief The auto mode bit means something else for the Strobe, so always return false */
bool C1394CameraControlStrobe::StatusAutoMode()
{
  return false;
}

/** \brief Override Inquire to get offsets and such from the parent camera
 *  \param pRawData If non-NULL, this receives the raw 32-bits of the inquiry register 
 *  \return
 *   - CAM_ERROR_NOT_INITIALIZED if the container camera pointer is invalid
 *   - CAM_ERROR_UNSUPPORTED if the container camera does not seem to support this control
 *   - Otherwise, same as C1394CameraControl::Inquire()
 */
int C1394CameraControlStrobe::Inquire(unsigned long *pRawData)
{
	unsigned long rootoffset;

	if(!m_pCamera)
		return CAM_ERROR_NOT_INITIALIZED;

	if(m_strobeID >= 4 || !m_pCamera->HasStrobe() || (rootoffset = m_pCamera->GetStrobeControlOffset()) == 0)
		return CAM_ERROR_UNSUPPORTED;

	m_inquiryoffset = rootoffset + 0x0100 + (m_strobeID<<2);
	m_statusoffset = rootoffset + 0x0200 + (m_strobeID<<2);
	return C1394CameraControl::Inquire(pRawData);
}

// Identification Stuff
static const char *names[] = {
	"Strobe 0",
	"Strobe 1",
	"Strobe 2",
	"Strobe 3"};

/**\brief The name of a strobe is simply "Strobe [Number]" */
const char *C1394CameraControlStrobe::GetName()
{
	return this->m_strobeID < 4 ? names[this->m_strobeID] : "Invalid Strobe";
}

/**\brief Strobe Units are seconds */
const char *C1394CameraControlStrobe::GetUnits()
{
	return "sec";
}

/**\brief Strobes are not your typical feature */
CAMERA_FEATURE C1394CameraControlStrobe::GetFeatureID()
{
	return FEATURE_INVALID_FEATURE;
}
