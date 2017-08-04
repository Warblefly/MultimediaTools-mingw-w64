/**\file tables.c
 * \ingroup capi
 * \brief Implements static tables and accessors to raw IIDC spec data
 */

/*
 *	Version 6.4
 *
 *  Copyright 8/2006
 *
 *  Christopher Baker
 *  Robotics Institute
 *  Carnegie Mellon University
 *  Pittsburgh, PA
 *
 *	Copyright 5/2000
 * 
 *	Iwan Ulrich
 *	Robotics Institute
 *	Carnegie Mellon University
 *	Pittsburgh, PA
 *
 *  This file is part of the CMU 1394 Digital Camera Driver
 *
 *  The CMU 1394 Digital Camera Driver is free software; you can redistribute 
 *  it and/or modify it under the terms of the GNU Lesser General Public License 
 *  as published by the Free Software Foundation; either version 2.1 of the License,
 *  or (at your option) any later version.
 *
 *  The CMU 1394 Digital Camera Driver is distributed in the hope that it will 
 *  be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public License
 *  along with the CMU 1394 Digital Camera Driver; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include "pch.h"

/** \brief Human-Readable descriptions of the various possible camera features 
 */
static struct feature_description {
	LPCSTR name;
	LPCSTR unit;	
} tableFeatDesc[FEATURE_NUM_FEATURES] = 
{
	{"Brightness","%"},
	{"Auto Exposure","eV"},
	{"Sharpness",""},
	{"White Balance", "K"},
	{"Hue","deg"},
	{"Saturation","%"},
	{"Gamma",""},
	{"Shutter","sec"},
	{"Gain","dB"},
	{"Iris","F"},
	{"Focus","m"},
	{"Temperature",""},
	{"Trigger","times"},
	{"Trigger Delay","Sec"},
	{"White Shading",""},
	{"Frame Rate","fps"},
	{NULL,NULL},{NULL,NULL},{NULL,NULL},{NULL,NULL},//19
	{NULL,NULL},{NULL,NULL},{NULL,NULL},{NULL,NULL},//23
	{NULL,NULL},{NULL,NULL},{NULL,NULL},{NULL,NULL},//27
	{NULL,NULL},{NULL,NULL},{NULL,NULL},{NULL,NULL},//31
	{"Zoom","X"},//32
	{"Pan","deg"},
	{"Tilt","deg"},
	{"Optical Filter",""},
	{NULL,NULL},{NULL,NULL},{NULL,NULL},{NULL,NULL},//39
	{NULL,NULL},{NULL,NULL},{NULL,NULL},{NULL,NULL},//43
	{NULL,NULL},{NULL,NULL},{NULL,NULL},{NULL,NULL},//47
	{"Capture Size",""},//48
	{"Capture Quality",""},
	{NULL,NULL},{NULL,NULL},//51
	{NULL,NULL},{NULL,NULL},{NULL,NULL},{NULL,NULL},//55
	{NULL,NULL},{NULL,NULL},{NULL,NULL},{NULL,NULL},//59
	{NULL,NULL},{NULL,NULL},{NULL,NULL},{NULL,NULL}//63
};

/**\brief Get the CSR offset for the indicated feature
 *\ingroup capi
 */
ULONG CAMAPI dc1394GetFeatureOffset(CAMERA_FEATURE id)
{
	if(id < FEATURE_NUM_FEATURES)
		if(tableFeatDesc[id].name != NULL)
			return id << 2;
	return FEATURE_INVALID_FEATURE;
}

/**\brief Get a human-readable string describing the indicated feature
 *\ingroup capi
 */
LPCSTR CAMAPI dc1394GetFeatureName(CAMERA_FEATURE id)
{
	return id < FEATURE_NUM_FEATURES ? tableFeatDesc[id].name : NULL;
}

/**\brief Get a human-readable string describing the indicated feature's units in absolute mode
 *\ingroup capi
 */
LPCSTR CAMAPI dc1394GetFeatureUnits(CAMERA_FEATURE id)
{
	return id < FEATURE_NUM_FEATURES ? tableFeatDesc[id].unit : NULL;
}

/**\brief Attempt to find a CAMERA_FEATURE that matches <i>name</i>
 *\ingroup capi
 */
CAMERA_FEATURE CAMAPI dc1394GetFeatureId(const char *name)
{
	int i;
	for(i=0; i<FEATURE_NUM_FEATURES; i++)
	{
		if(!StrCmp(tableFeatDesc[i].name,name))
			return i;
	}
	return FEATURE_INVALID_FEATURE;
}

/**\brief Human-readable descriptions and bits-per-pixel for known color codes */
static struct _colorcode_description {
	LPCSTR name;
	ULONG bpp;
} tableCCDesc[COLOR_CODE_MAX] = 
{
	{"Mono (8-bit)"        ,8 },
	{"YUV 4:1:1"           ,12},
	{"YUV 4:2:2"           ,16},
	{"YUV 4:4:4"           ,24},
	{"RGB (8-bit)"         ,24},
	{"Mono (16-bit)"       ,16},
	{"RGB (16-bit)"        ,48},
	{"Mono (16-bit Signed)",16},
	{"RGB (16-bit Signed)" ,48},
	{"RAW (8-bit)"         ,8 },
	{"RAW (16-bit)"        ,16}
};

/**\brief width, height and color code for the core formats (0-2) */
static VIDEO_MODE_DESCRIPTOR tableModeDesc[3][8] = 
{
	{
		{160 ,120 ,COLOR_CODE_YUV444},
		{320 ,240 ,COLOR_CODE_YUV422},
		{640 ,480 ,COLOR_CODE_YUV411},
		{640 ,480 ,COLOR_CODE_YUV422},
		{640 ,480 ,COLOR_CODE_RGB8},
		{640 ,480 ,COLOR_CODE_Y8},
		{640 ,480 ,COLOR_CODE_Y16},
		{0   ,0   ,COLOR_CODE_MAX}
	},{
		{800 ,600 ,COLOR_CODE_YUV422},
		{800 ,600 ,COLOR_CODE_RGB8},
		{800 ,600 ,COLOR_CODE_Y8},
		{1024,768 ,COLOR_CODE_YUV422},
		{1024,768 ,COLOR_CODE_RGB8},
		{1024,768 ,COLOR_CODE_Y8},
		{800 ,600 ,COLOR_CODE_Y16},
		{1024,768 ,COLOR_CODE_Y16}
	},{
		{1280,960 ,COLOR_CODE_YUV422},
		{1280,960 ,COLOR_CODE_RGB8},
		{1280,960 ,COLOR_CODE_Y8},
		{1600,1200,COLOR_CODE_YUV422},
		{1600,1200,COLOR_CODE_RGB8},
		{1600,1200,COLOR_CODE_Y8},
		{1280,960 ,COLOR_CODE_Y16},
		{1600,1200,COLOR_CODE_Y16}
	}
};

/**\brief Compute the Frame buffer size for format f, mode m
 *\ingroup capi
 */
ULONG CAMAPI dc1394GetBufferSize(ULONG f, ULONG m)
{
	ULONG bytes;
	if(f >= 3 || m >= 8)
		return 0;

	bytes = tableCCDesc[tableModeDesc[f][m].colorcode].bpp;
	bytes *= tableModeDesc[f][m].width;
	bytes *= tableModeDesc[f][m].height;
	bytes >>= 3;
	return bytes;
}

/**\brief Populate a descriptor for format f, mode m
 *\ingroup capi
 */
LONG CAMAPI dc1394GetModeDescriptor(ULONG f, ULONG m, PVIDEO_MODE_DESCRIPTOR pDesc)
{
	if(f >= 3 || m >= 8)
		return -1;

	pDesc->width = tableModeDesc[f][m].width;
	pDesc->height = tableModeDesc[f][m].height;
	pDesc->colorcode = tableModeDesc[f][m].colorcode;
	return 0;
}

/**\brief Format a string to describe format f, mode m
 *\ingroup capi
 */
ULONG CAMAPI dc1394GetModeString(ULONG f, ULONG m, LPSTR buf, ULONG buflen)
{
	size_t len;
	if(f >= 3 || m >= 8)
		return 0;

	StringCbPrintf(buf,buflen,"%dX%d %s",
		tableModeDesc[f][m].width,
		tableModeDesc[f][m].height,
		tableCCDesc[tableModeDesc[f][m].colorcode].name
	);

	StringCchLength(buf,buflen,&len);
	return (ULONG)len;
}

/**\brief Retrieve a human-readable string describing the indicated color code 
 *\ingroup capi
 */
LPCTSTR CAMAPI dc1394GetColorCodeDescription(COLOR_CODE code)
{
	if(code < COLOR_CODE_MAX && code != COLOR_CODE_INVALID)
		return tableCCDesc[code].name;
	else
		return "Invalid Color Code";
}

/**\brief Retrieve the number of bits per pixel for the color code
 *\ingroup capi
 */
LONG CAMAPI dc1394GetBitsPerPixel(COLOR_CODE code)
{
	return code < COLOR_CODE_MAX ? tableCCDesc[code].bpp : 0;
}

/**\brief the magic quadlets-per-packet structure as [format][mode][rate]
 *
 * This should be calculable from width, height, framerate, and a 125 us packet rate
 */
static int tableQPP[3][8][8] = 
// [format][mode][rate]
{	
	{	
		// format 0
		{   0,   0,  15,  30,  60, 120,	240, 480},					
		{  10,  20,  40,  80, 160, 320, 640,1280},	
		{  30,  60, 120, 240, 480, 960,1920,3840},	
		{  40,  80, 160, 320, 640,1280,2560,5120},	
		{  60, 120, 240, 480, 960,1920,3840,7680},	
		{  20,  40,  80, 160, 320, 640,1280,2560},
		{  40,  80, 160, 320, 640,1280,2560,5120},
		{   0,   0,   0,   0,   0,   0,   0,   0}

	},{
		// format 1
		{   0, 125, 250, 500,1000,2000,4000,8000},
		{   0,   0, 375, 750,1500,3000,6000,   0},	
		{   0,   0, 125, 250, 500,1000,2000,4000},	
		{  96, 192, 384, 768,1536,3072,6144,   0},	
		{ 144, 288, 576,1152,2304,4608,   0,   0},	
		{  48,  96, 192, 384, 768,1536,3072,6144},
		{   0, 125, 250, 500,1000,2000,4000,8000},
		{  96, 192, 384, 768,1536,3072,6144,   0},	
	
	},{	
		// format 2
		{ 160, 320, 640,1280,2560,5120,   0,   0},
		{ 240, 480, 960,1920,3840,7680,   0,   0},	
		{  80, 160, 320, 640,1280,2560,5120,   0},	
		{ 250, 500,1000,2000,4000,8000,   0,   0},	
		{ 375, 750,1500,3000,6000,   0,   0,   0},	
		{ 125, 250, 500,1000,2000,4000,8000,   0},
		{ 160, 320, 640,1280,2560,5120,   0,   0},
		{ 250, 500,1000,2000,4000,8000,   0,   0},	
	}
};

/**\brief Retrieve the magic QPP for (f,m,r) 
 *\ingroup capi
 */
LONG CAMAPI dc1394GetQuadletsPerPacket(ULONG f, ULONG m, ULONG r)
{
	if(f >= 3 || m >= 8 || r >= 8)
		return -1;

	if(1)
	{
		return tableQPP[f][m][r];
	} else {
		// a way to derive this... but the table is already there and works
		int k;
		double n,fpart;

		n = dc1394GetBufferSize(f,m); // total buffer size to start with
		n *= 1.875; // base frame rate
		n *= (double)(1<<r);  // real frame rates are exponential in r 
		n /= 4.0;  // reduce to quadlets		
		// the 1024x768 modes work just a little differently (slower)
		// to make the QPP divide nicely into the buffer size
		if(tableModeDesc[f][m].width == 1024)
			n /= 1.066666666;

		// now we have total quadlets per second and we multiply by the 1394 cycle time
		n *= 0.000125;
		// and account for the fact that only 90% is for isochronous
		n /= 0.9;

		// and round
		k = (int)(n + 0.5);
		fpart = n - (double)(k);
		if(fpart < 0)
			fpart = -fpart;

		// qpp is not valid for partial quadlets or for qpp > 8000 (max allowed by 3200 mbps 1394b)
		if(k > 8000 || fpart > 0.1)
			k = 0;
		return k;
	}

}

static unsigned short _tableTriggerParameters[16][3] =  // [mode][id,min,max]
{
	{ 0, 0, 0 }, // mode 0 is simple trigger, no parameter
	{ 0, 0, 0 }, // mode 1 is integrate-while-depressed, no parameter
	{ 1, 2, 65535 }, // mode 2 is integrate-over N triggers, need at least start,end, so N >= 2
	{ 1, 1, 65535 }, // mode 3 is divide-internal-trigger-by-N
	{ 1, 1, 65535 }, // mode 4 is accumulate-N-exposures
	{ 1, 1, 65535 }, // mode 5 is accumulate-N-trigger-length-exposures
	{ 1, 0, 65535 }, 
	{ 1, 0, 65535 },
	{ 1, 0, 65535 },
	{ 1, 0, 65535 },
	{ 1, 0, 65535 }, // modes 6-14 are unspecified/vendor-unique, but we will assume a parameter
	{ 1, 0, 65535 }, // for now and leave it unconstrained
	{ 1, 0, 65535 },
	{ 1, 0, 65535 },
	{ 1, 0, 65535 },
	{ 1, 1, 65535 } // mode 15 is N frames-per trigger (effectively triggered multishot
};

/**\brief DCAM Protocol accessor for whether a trigger mode has a parameter, and the camera-independent min and max values
 * \param nModeId The mode to query, valid values are 0-15, inclusive, all else will return false
 * \param minValue Pointer to recipient of min value, ignored if null and modified only on a TRUE return value;
 * \param maxValue Pointer to recipient of max value, ignored if null and modified only on a TRUE return value;
 * \return boolean indication of whether the mode has a parameter
 *
 * This protocol policy was previously embedded in the demo application.  It has been moved here for clarity/consistency
 * with the treatment of other protocol values
 */
BOOL CAMAPI dc1394TriggerModeHasParameter(ULONG nModeId, unsigned short *minValue, unsigned short *maxValue)
{
	if(nModeId < 16)
	{
		if(_tableTriggerParameters[nModeId][0] == 1)
		{
			if(minValue != NULL)
			{
				*minValue = _tableTriggerParameters[nModeId][1];
			}
			if(maxValue != NULL)
			{
				*maxValue = _tableTriggerParameters[nModeId][2];
			}
			return TRUE;
		}// fall trough to FALSE below
	} // invalid parameter

	return FALSE;
}
