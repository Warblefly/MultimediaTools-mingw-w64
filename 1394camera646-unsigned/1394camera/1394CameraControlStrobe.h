/**\file 1394CameraControlStrobe.h
 * \brief Declares C1394CameraControlStrobe
 * \ingroup	camopt
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


#ifndef __1394CAMERACONTROLSTROBE_H__
#define __1394CAMERACONTROLSTROBE_H__

class C1394Camera;

/**\brief Encapsulates the operation of the strobe control
 * \ingroup strobe
 *
 * This class is must be initialized with a parent C1394Camera class
 * for proper operation.  Thenceforth, this  class can be used to monitor
 * and manipulate the strobe functionality of the indicated camera.
 *
 * This is basically a sematics wrapper over C1394CameraControl, except that
 * the strobe offsets must be acquired from the container camera instead of simply
 * deriving them from the core offsets.  This functionality has been placed in 
 * C1394CameraControlStrobe::Inquire()
 */
class CAMAPI C1394CameraControlStrobe : public C1394CameraControl
{
public:
	C1394CameraControlStrobe(C1394Camera *pCamera, unsigned long strobeID);
	~C1394CameraControlStrobe();
	bool HasPolarity();
	int SetPolarity(BOOL polarity);
	bool StatusPolarity();
	// Overrides
	bool HasAutoMode();
	bool HasManualMode();
	int SetAutoMode(BOOL on);
	bool StatusAutoMode();
	int Inquire(unsigned long *pRawData = NULL);
	// Identification Stuff
	const char *GetName();
	const char *GetUnits();
	CAMERA_FEATURE GetFeatureID();
private:
	unsigned long m_strobeID;
};

#endif // __1394CAMERACONTROLSTROBE_H__
