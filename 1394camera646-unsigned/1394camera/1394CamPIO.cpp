/**\file 1394CamPIO.cpp
 * \brief Implements PIO Advanced Functionality
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

/**\defgroup camoptional Optional Extended Features
 * \ingroup camcore
 * 
 * IIDC DCAM 1.31 defines a collection of extensions to the core 
 * camera functionality, including parallel, serial and synchronization
 * connections.
 */

/**\defgroup pio Parallel I/O Functionality
 * \ingroup camoptional
 *
 * The simplest optional extension is 32 bits each of bitwise I/O,
 * accessed via a handful of registers.
 */

/**\brief Read the Input values of the PIO functionality
 * \ingroup pio
 * \param ulBits Where to put the bits
 * \return
 *  - CAM_ERROR_UNSUPPORTED if the feature is not available
 *  - Otherwise, same as ReadQuadlet()
 */
int C1394Camera::GetPIOInputBits (unsigned long *ulBits)
{
	if(!this->HasPIO())
		return CAM_ERROR_UNSUPPORTED;
	
	return this->ReadQuadlet(this->GetPIOControlOffset() + 0x004,ulBits);
}

/**\brief Read the Current Ouput values of the PIO functionality
 * \ingroup pio
 * \param ulBits Where to put the bits
 * \return
 *  - CAM_ERROR_UNSUPPORTED if the feature is not available
 *  - Otherwise, same as ReadQuadlet()
 */
int C1394Camera::GetPIOOutputBits(unsigned long *ulBits)
{
	if(!this->HasPIO())
		return CAM_ERROR_UNSUPPORTED;
	
	return this->ReadQuadlet(this->GetPIOControlOffset() + 0x000,ulBits);
}

/**\brief Set the output values of the PIO functionality
 * \ingroup pio
 * \param ulBits The bits to write
 * \return
 *  - CAM_ERROR_UNSUPPORTED if the feature is not available
 *  - Otherwise, same as WriteQuadlet()
 */
int C1394Camera::SetPIOOutputBits(unsigned long ulBits)
{
	if(!this->HasPIO())
		return CAM_ERROR_UNSUPPORTED;
	
	return this->WriteQuadlet(this->GetPIOControlOffset() + 0x000,ulBits);
}
