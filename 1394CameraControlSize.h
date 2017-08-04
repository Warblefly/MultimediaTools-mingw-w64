/**\file 1394CameraControlSize.h
 * \brief Declares C1394CameraControlSize
 * \ingroup	camfmr
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


#ifndef __1394CAMERACONTROLSIZE_H__
#define __1394CAMERACONTROLSIZE_H__

class C1394Camera;

/**\brief Scalable Image Format (Format 7) Control Class
 *
 * This class does its best to manage and maintain internal consistency for 
 * format 7 video modes, though doing so is troublesome at best
 */
class CAMAPI C1394CameraControlSize  
{
public:
	C1394CameraControlSize(C1394Camera *pCamera);
	~C1394CameraControlSize();
	
	void GetSizeLimits(unsigned short *hMax, unsigned short *vMax);
	void GetSizeUnits(unsigned short *hUnit, unsigned short *vUnit);
	void GetSize(unsigned short *width, unsigned short *height);
	int  SetSize(unsigned short width, unsigned short height);
	
	void GetPosLimits(unsigned short *hMax, unsigned short *vMax);
	void GetPosUnits(unsigned short *hUnit, unsigned short *vUnit);
	void GetPos(unsigned short *left, unsigned short *top);
	int SetPos(unsigned short left, unsigned short top);
	
	bool HasColorCode(COLOR_CODE code);
	void GetColorCode(COLOR_CODE *code);
	int  SetColorCode(COLOR_CODE code);
	
	void GetPixelsPerFrame(unsigned long *ppf);
	void GetBytesPerFrame(unsigned long *lo32, unsigned long *hi32 = NULL);
	
	void GetBytesPerPacketRange(unsigned short *min, unsigned short *max);
	void GetBytesPerPacket(unsigned short *current, unsigned short *recommended = NULL);
	void GetPacketsPerFrame(unsigned long *ppf);
	int  SetBytesPerPacket(unsigned short bpp);
	
	void GetDataDepth(unsigned short *depth);
	void GetColorFilter(unsigned short *filter);
	void GetFrameInterval(float *interval);
	
	bool CheckError1();
	bool CheckError2();
	
private:
	friend class C1394Camera; // the less ugly of the two to allow SetOffset
	int SetOffset(unsigned long offset);
	int UpdateStatic();
	int UpdateTier1(BOOL SetValues = FALSE);
	int UpdateTier2(BOOL SetValues = FALSE);
	int SetValues();
	// container camera
	C1394Camera* m_pCamera;
	// offset into the register space
	unsigned long m_offset;
	
	// static inquiry registers per mode
	unsigned long m_InqMaxSize;
	unsigned long m_InqUnitSize;
	unsigned long m_InqColorCodes;
	unsigned long m_InqUnitPos;      //1.30
	
	// tier 1 status registers, happiness will be reflected in Error 1
	unsigned long m_StaImagePos;
	unsigned long m_StaImageSize;
	unsigned long m_StaColorCode;
	unsigned long m_StaValueSetting; //1.30
	
	// tier 1 inquiry registers, updated on change of some tier 1 status registers
	unsigned long m_InqPixels;
	unsigned long m_InqBytesHi;
	unsigned long m_InqBytesLo;
	unsigned long m_InqPacketParam;
	unsigned long m_InqDataDepth;    //1.31
	unsigned long m_InqColorFilter;  //1.31
	
	// tier 2 status registers, happiness will be indicated in Error 2
	unsigned long m_StaBytesPerPacket;
	
	// tier 2 inquiry registers, updated on change of tier 2 status registers
	unsigned long m_InqPacketsPerFrame; //1.30
	unsigned long m_InqFrameInterval;   //1.31
};

#endif // __1394CAMERACONTROLSIZE_H__
