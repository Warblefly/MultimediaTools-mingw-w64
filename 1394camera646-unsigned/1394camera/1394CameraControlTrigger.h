/**\file 1394CameraControlTrigger.h
 * \brief Declares C1394CameraControlTrigger
 * \ingroup	camfeat
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


#ifndef __1394CAMERACONTROLTRIGGER_H__
#define __1394CAMERACONTROLTRIGGER_H__

class C1394Camera;

/**\brief Encapsulates the operation of the trigger control
 *
 * This class is must be initialized with a parent C1394Camera class
 * for proper operation.  Thenceforth, this  class can be used to monitor
 * and manipulate the trigger functionality of the indicated camera.
 *
 * This is basically a sematics wrapper over C1394CameraControl.  The min
 * integer value is really a bitmask, and the value bits in the status register
 * map to mode and parameter
 */
class CAMAPI C1394CameraControlTrigger : public C1394CameraControl
{
public:
	C1394CameraControlTrigger(C1394Camera *pCamera);
	~C1394CameraControlTrigger();
	int SetMode(unsigned short mode, unsigned short parameter = 0);
	bool HasMode(unsigned short mode);
	int GetMode(unsigned short *mode, unsigned short *parameter);
	bool HasPolarity();
	int SetPolarity(BOOL polarity);
	bool StatusPolarity();
	// Overrides
	bool HasAutoMode();
	bool HasManualMode();
	int SetAutoMode(BOOL on);
	bool StatusAutoMode();
	// 1.31
	bool HasValueReadout();
	void GetValueReadout(unsigned short *val);
	
	bool HasSoftwareTrigger();
	int  DoSoftwareTrigger();
	
	bool HasTriggerSource(unsigned short src);
	void GetTriggerSource(unsigned short *src);
	int  SetTriggerSource(unsigned short src);
protected:
	TRIGGER_INQUIRY_REGISTER *m_pTriggerInquiry;
	TRIGGER_STATUS_REGISTER *m_pTriggerStatus;
};

#endif // __1394CAMERACONTROLTRIGGER_H__
