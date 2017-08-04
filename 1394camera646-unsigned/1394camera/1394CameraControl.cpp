/**\file 1394CameraControl.cpp 
 * \brief Implementation of the C1394CameraControl class.
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

/**\defgroup camfeat Camera Feature Controls
 * \ingroup camcore
 * IIDC DCAM specifies some 20 or so basic features (brightness, zoom, etc) that may
 * be available on the camera.  This subset of functionality deals with those features
 */

//////////////////////////////////////////////////////////////////////
// Construction/Destruction
//////////////////////////////////////////////////////////////////////

/**\brief Initialize a Control instance
 * \param pCamera The parent/container C1394Camera that this control class will operate on
 * \param feature The ID of the feature to manipulate
 *
 * If a valid feature is passed in, this will retrieve and compute the appropriate offsets for
 * the inquiry and status.  If not (e.g. FEATURE_INVALID_FEATURE), then this step will be skipped 
 * so subclass constructors (e.g. C1394CameraControlStrobe have an opportunity to init them cleanly
 *
 * Also, bad things will happen if the parent camera pointer is invalid.
 */
C1394CameraControl::C1394CameraControl(C1394Camera *pCamera, CAMERA_FEATURE feature):
	m_pCamera(pCamera),
	m_feature(feature)
{
	if(m_pCamera == NULL)
		DllTrace(DLL_TRACE_ALWAYS,
		         "C1394CameraControl: Parent pointer is NULL while constructing %08x, bad things will happen\n",
				 this);

	// nuke the registers and absstuff
    *((unsigned long *)&this->m_InquiryReg) = 0;
    *((unsigned long *)&this->m_StatusReg) = 0;
    this->m_absmin = this->m_absmax = this->m_absval = 0.0f;

	// look up the offset and such
	if(m_feature >= FEATURE_BRIGHTNESS && m_feature < FEATURE_NUM_FEATURES)
	{
  		this->m_offset = dc1394GetFeatureOffset(feature);
		this->m_statusoffset = this->m_offset + FEATURE_STATUS_INDEX;
		this->m_inquiryoffset = this->m_offset + FEATURE_INQUIRY_INDEX;
	} else {
  		this->m_offset = 0;
		this->m_statusoffset = 0;
		this->m_inquiryoffset = 0;
	}
}

/**\brief Nothing to see here, move along */
C1394CameraControl::~C1394CameraControl()
{
}

/**\brief Read the Feature Inquiry Register
 * \param pRawData If non-NULL, the raw 32-bits of the inquiry register will be copied here
 * \return Essentially the same as C1394Camera::ReadQuadlet()
 *
 * This Reads the feature inquiry register determined by m_inquiryoffset into m_InquiryReg.  
 * If absolute control is supported, the min and max absolute values are
 * read into m_absmin and m_absmax respectively.
 *
 * Note: This is the only way to read these registers from the camera.  All other accessors
 * (HasStuff, GetRange) simply return the values in the class members.
 */
int C1394CameraControl::Inquire(unsigned long *pRawData)
{
	unsigned long* pulBits = (unsigned long *)&this->m_InquiryReg;
	int ret;

	if((ret = m_pCamera->ReadQuadlet(m_inquiryoffset, pulBits) != CAM_SUCCESS))
	{
		DllTrace(DLL_TRACE_ERROR,"C1394CameraControl::Inquire: error %d on ReadQuadlet (Inquiry)\n", ret);
		return ret;
	}

	if(m_InquiryReg.absctl)
	{
		/* has absolute value registers */
		if((ret = m_pCamera->ReadQuadlet(m_offset + FEATURE_ABSCTL_INDEX, &m_absctloffset) != CAM_SUCCESS))
		{
			DllTrace(DLL_TRACE_ERROR,"C1394CameraControl::Inquire: error %d on ReadQuadlet (Abs Offset)\n", ret);
			return ret;
		}
		
		// the returned offset is an absolute quadlet offset, requiring multiplication by 4 and a leading 0xF to work out
		m_absctloffset  = (m_absctloffset << 2) | 0xf0000000;
		DllTrace(DLL_TRACE_CHECK,"C1394CameraControl: Control %04x has absolute offset %08x\n",m_offset,m_absctloffset);

		// read min, max, val
		if((ret = m_pCamera->ReadQuadlet(m_absctloffset + 0x0, (unsigned long *)&m_absmin) != CAM_SUCCESS))
		{
			DllTrace(DLL_TRACE_ERROR,"C1394CameraControl::Inquire: error %d on ReadQuadlet(%08x)\n", ret,m_absctloffset + 0x0);
			return ret;
		}
		if((ret = m_pCamera->ReadQuadlet(m_absctloffset + 0x4, (unsigned long *)&m_absmax) != CAM_SUCCESS))
		{
			DllTrace(DLL_TRACE_ERROR,"C1394CameraControl::Inquire: error %d on ReadQuadlet(%08x)\n", ret,m_absctloffset + 0x4);
			return ret;
		}
	}

	if(pRawData)
		*pRawData = *pulBits;

	return CAM_SUCCESS;
}

/**\brief Accessor for min and max (integer) values
 * \param min Where to put the min value
 * \param max Where to put the max value
 * \see Inquire()
 *
 * If either parameter is NULL, the error is silently ignored
 */
void C1394CameraControl::GetRange(unsigned short *min, unsigned short *max)
{
	if(min != NULL && max != NULL)
	{
		*min = m_InquiryReg.min;
		*max = m_InquiryReg.max;
	}
}

/**\brief Accessor for min and max (float) values
 * \param min Where to put the min value
 * \param max Where to put the max value
 * \see Inquire()
 *
 * If either parameter is NULL, the error is silently ignored
 */
void C1394CameraControl::GetRangeAbsolute(float *min, float *max)
{
	if(min != NULL && max != NULL)
	{
		*min = m_absmin;
		*max = m_absmax;
	}
}

/**\brief Read the Feature Status Register
 * \param pRawData If non-NULL, the raw 32-bits of the status register will be copied here
 * \return Essentially the same as C1394Camera::ReadQuadlet()
 *
 * This Reads the feature status register determined by m_offset into m_StatusReg.  
 * If absolute control is active, the current absolute values is read into m_absval
 *
 * Note: This is the only way to read these variables from the camera.  All other accessors
 * (StatusStuff, GetValue) simply return the values in the class members.
 */
int C1394CameraControl::Status(unsigned long *pRawData)
{
	unsigned long *pulBits = (unsigned long *)&this->m_StatusReg; 
	int ret;
	
	if((ret = m_pCamera->ReadQuadlet(m_statusoffset, pulBits) != CAM_SUCCESS))
	{
		DllTrace(DLL_TRACE_ERROR,"C1394CameraControl::Status: error %d on ReadQuadlet\n", ret);
		return ret;
	}
	
	if(m_InquiryReg.absctl && m_StatusReg.absctl)
	{
		if((ret = m_pCamera->ReadQuadlet(m_absctloffset + 0x8, (unsigned long *)&m_absval) != CAM_SUCCESS))
		{
			DllTrace(DLL_TRACE_ERROR,"C1394CameraControl::Inquire: error %d on ReadQuadlet(%08x)\n", ret,m_absctloffset + 0x8);
			return ret;
		}
	}
	
	if(pRawData)
		*pRawData = *pulBits;
	
	DllTrace(DLL_TRACE_EXIT,"EXIT Control::Status@0x%02x: %08x\n", m_offset,*pulBits);
	return ret;
}

/**\brief Used to consistently define the simple accessors for register bits */
#define GEN_ACCESSOR(REGISTER,PREFIX,FUNCNAME,BITNAME) \
bool C1394CameraControl::##PREFIX##FUNCNAME() {return(##REGISTER.##BITNAME);}

/**\brief Used to consistently define the simple accessors for inquiry bits */
#define INQ_ACCESSOR(FN,BN) GEN_ACCESSOR(m_InquiryReg,Has,FN,BN)

INQ_ACCESSOR(Presence,present)
INQ_ACCESSOR(AbsControl,absctl)
INQ_ACCESSOR(OnePush,onepush)
INQ_ACCESSOR(Readout,readout)
INQ_ACCESSOR(OnOff,onoff)
INQ_ACCESSOR(AutoMode,automode)
INQ_ACCESSOR(ManualMode,manualmode)

/**\brief Used to consistently define the simple accessors for status bits */
#define STA_ACCESSOR(FN,BN) GEN_ACCESSOR(m_StatusReg,Status,FN,BN)
STA_ACCESSOR(Presence,present)
STA_ACCESSOR(AbsControl,absctl)
STA_ACCESSOR(OnOff,onoff)
STA_ACCESSOR(OnePush,onepush)
STA_ACCESSOR(AutoMode,automode)

/**\brief Accessor for current (integer) values
 * \param v_lo Where to put the low 12 bits of the current value
 * \param v_hi Where to put the high 12 bits of the current value
 * \see Status()
 *
 * v_hi is only interesting for the temperature and whitebalance controls, and
 * for the C1394CameraControlTrigger class.
 *
 * NULL parameters are silently ignored
 */
void C1394CameraControl::GetValue(unsigned short *v_lo, unsigned short *v_hi)
{
	if(v_lo != NULL)
		*v_lo = m_StatusReg.v_lo;
	
	if(v_hi != NULL)
		*v_hi = m_StatusReg.v_hi;
}

/**\brief Accessor for current (integer) values
 * \param f Where to put the current absolute value
 * \see Status()
 *
 * NULL parameters are silently ignored
 */
void C1394CameraControl::GetValueAbsolute(float *f)
{
	if(f != NULL)
		*f = m_absval;
}

/**\brief Used to consistently define simple mutators */
#define STA_MUTATOR(FN,BN) \
int C1394CameraControl::Set##FN(BOOL on) { \
	m_StatusReg.##BN = on;\
	return SetStatus();\
}

STA_MUTATOR(AbsControl,absctl)
STA_MUTATOR(OnOff,onoff)
STA_MUTATOR(OnePush,onepush)
STA_MUTATOR(AutoMode,automode)

/**\brief Mutators for current (integer) values
 * \param v_lo What v_lo to set
 * \param v_hi What v_hi to set
 * \return Same as SetStatus()
 *
 * Again, v_hi is only interesting for the temperature and whitebalance controls, and
 * for the C1394CameraControlTrigger class.
 */
int C1394CameraControl::SetValue(unsigned short v_lo, unsigned short v_hi)
{
	m_StatusReg.v_lo = v_lo;
	m_StatusReg.v_hi = v_hi;
	return SetStatus();
}

/**\brief Accessor for current (absolute) value
 * \param f The value to set
 * \return
 *   - CAM_ERROR_NOT_UNSUPPORTED if the feature is not available and active
 *   - CAM_ERROR_PARAM_OUT_OF_RANGE if <i>f</i> exceeds the indicated range
 *   - Otherwise, Same as C1394Camera::WriteQuadlet()
 */
int C1394CameraControl::SetValueAbsolute(float f)
{
	int ret;
	if(m_InquiryReg.absctl && m_StatusReg.absctl)
	{
		if(f >= m_absmin && f <= m_absmax)
			ret = m_pCamera->WriteQuadlet(m_absctloffset + 0x8, *(unsigned long *)(&f));
		else
			ret = CAM_ERROR_PARAM_OUT_OF_RANGE;
	} else {
		ret = CAM_ERROR_UNSUPPORTED;
	}
	return ret;
}

/** \brief Wrapper for dc1394GetFeatureName() */
const char *C1394CameraControl::GetName()
{
	return dc1394GetFeatureName(this->m_feature);
}

/** \brief Wrapper for dc1394GetFeatureUnits() */
const char *C1394CameraControl::GetUnits()
{
	return dc1394GetFeatureUnits(this->m_feature);
}

/** \brief Accessor for m_feature */
CAMERA_FEATURE C1394CameraControl::GetFeatureID()
{
	return this->m_feature;
}

/**\brief Push the contents of m_StatusReg to the camera status register
 * \return Same as C1394Camera::WriteQuadlet();
 */
int C1394CameraControl::SetStatus()
{
	unsigned long *pulBits = (unsigned long *)&this->m_StatusReg;
	return m_pCamera->WriteQuadlet(this->m_statusoffset,*pulBits);
}