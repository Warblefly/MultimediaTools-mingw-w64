/**\file 1394CameraControl.h
 * \brief Declares C1394CameraControl
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

#ifndef __1394CAMERACONTROL_H__
#define __1394CAMERACONTROL_H__

// prototype the Camera class so we can make our parent pointer to it.
class C1394Camera;

/**\brief Encapsulates the operation of exactly one camera feature (control)
 *
 * This class is must be initialized with a parent C1394Camera class and a
 * feature ID of type CAMERA_FEATURE for proper operation.  Thenceforth, this 
 * class can be used to monitor and manipulate the indicated control on the 
 * indicated camera.
 */
class CAMAPI C1394CameraControl  
{
public:
	C1394CameraControl(C1394Camera *pCamera, CAMERA_FEATURE feature);
	~C1394CameraControl();
	
	// Inquiry Stuff
	int Inquire(unsigned long *pRawData = NULL);
	bool HasPresence();         ///< Accessor for m_InquiryReg.present    \see Inquire()
	bool HasAbsControl();       ///< Accessor for m_InquiryReg.absctl     \see Inquire()
	bool HasOnePush();          ///< Accessor for m_InquiryReg.onepush    \see Inquire()
	bool HasReadout();          ///< Accessor for m_InquiryReg.readout    \see Inquire()
	bool HasOnOff();            ///< Accessor for m_InquiryReg.onoff      \see Inquire()
	bool HasAutoMode();         ///< Accessor for m_InquiryReg.automode   \see Inquire()
	bool HasManualMode();       ///< Accessor for m_InquiryReg.manualmode \see Inquire()
	void GetRange(unsigned short *min, unsigned short *max);
	void GetRangeAbsolute(float *fmin, float *fmax);
	
	// Status Stuff
	int Status(unsigned long *pRawData = NULL);
	// Status Accessors
	bool StatusPresence();      ///< Accessor for m_StatusReg.present     \see Status()
	bool StatusAbsControl();    ///< Accessor for m_StatusReg.abscontrol  \see Status()
	bool StatusOnOff();         ///< Accessor for m_StatusReg.onoff       \see Status()
	bool StatusOnePush();      ///< Accessor for m_StatusReg.automode    \see Status()
	bool StatusAutoMode();      ///< Accessor for m_StatusReg.automode    \see Status()
	void GetValue(unsigned short *v_lo, unsigned short *v_hi=NULL);
	void GetValueAbsolute(float *f);
	// Status Mutators
	int SetAbsControl(BOOL on); ///< Mutator for m_StatusReg.AbsControl \return Same as SetStatus()
	int SetOnOff(BOOL on);      ///< Mutator for m_StatusReg.onoff      \return Same as SetStatus()
	int SetOnePush(BOOL on);    ///< Mutator for m_StatusReg.onepush    \return Same as SetStatus()
	int SetAutoMode(BOOL on);   ///< Mutator for m_StatusReg.automode   \return Same as SetStatus()
	int SetValue(unsigned short v_lo, unsigned short v_hi=0);
	int SetValueAbsolute(float f); 
	
	// Identification Stuff
	const char *GetName();
	const char *GetUnits();
	CAMERA_FEATURE GetFeatureID();
protected:
	int SetStatus();
	unsigned long  m_offset;
	unsigned long  m_statusoffset;
	unsigned long  m_inquiryoffset;
	unsigned long  m_absctloffset;
	C1394Camera* m_pCamera;
	CAMERA_FEATURE m_feature;
	FEATURE_INQUIRY_REGISTER m_InquiryReg;
	FEATURE_STATUS_REGISTER  m_StatusReg;
	float m_absmin, m_absmax, m_absval;
};

#endif // __1394CAMERACONTROL_H__
