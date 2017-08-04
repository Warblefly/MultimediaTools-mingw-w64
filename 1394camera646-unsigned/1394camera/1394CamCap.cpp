/**\file 1394CamCap.cpp
 * \brief Implements Capture functionality for the 1394Camera class
 * \ingroup camcap
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

/**\defgroup camcap Frame Capture
 * \brief Deprecated as of version 6.3.   
 * \ingroup camcore
 * \see camacq
 *
 * These now wrap the Image Acquisition functionality for backwards compatibility.
 */
 
/**\brief Wraps StartImageAcquisitionEx()
 * \ingroup camcap
 * \return Same as StartImageAcquisitionEx()
 *
 * Equivalent to StartImageAcquisitionEx(1,1000,0)
 */
int C1394Camera::StartImageCapture()
{
	return StartImageAcquisitionEx(1,1000,ACQ_START_VIDEO_STREAM);
}


/**\brief Wraps AcquireImageEx()
 * \ingroup camcap
 * \return Same as AcquireImageEx()
 *
 * Equivalent to AcquireImageEx(TRUE,NULL)
 */
int C1394Camera::CaptureImage()
{
	return AcquireImageEx(TRUE,NULL);
}


/**\brief Wraps StopImageAcquisition()
 * \ingroup camcap
 * \return Same as StopImageAcquisition()
 */
int C1394Camera::StopImageCapture()
{
	return StopImageAcquisition();
}
