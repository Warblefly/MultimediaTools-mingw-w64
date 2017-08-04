// isochtest.cpp : Defines the entry point for the console application.
//

#include <windows.h>
#include <1394Camera.h>
#include <stdio.h>
#include <conio.h>
#include <time.h>

#include <vector>

unsigned long g_errorCount = 0;

FILE *logfile = NULL;
#define TEST_REPORT(FMT,...) fprintf(logfile,"%s:%d | NOTICE | " FMT, __FILE__, __LINE__, __VA_ARGS__);
#define TEST_REPORT_ERROR(FMT,...) fprintf(logfile,"%s:%d |  ERROR | " FMT, __FILE__, __LINE__, __VA_ARGS__); ++g_errorCount;

static const char *StrLastError()
{
	DWORD err = GetLastError();
	static char buf[512];
	FormatMessage( 
		FORMAT_MESSAGE_FROM_SYSTEM | 
		FORMAT_MESSAGE_IGNORE_INSERTS,
		NULL,
		err,
		MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), // Default language
		(LPTSTR) &buf,
		512,
		NULL );
    return buf;
}

bool testIsochStreamAlloc(LPSTR szDeviceName, ULONG nMaxBytesPerFrame, ULONG nMaxBufferSize)
{
	DWORD dwRet;
	ISOCH_STREAM_PARAMS isp;
	GetMaxIsochSpeed(szDeviceName,&isp.fulSpeed);
	isp.nChannel = 0;
	isp.nMaxBytesPerFrame = nMaxBytesPerFrame;
	isp.nNumberOfBuffers = 30;
	isp.nMaxBufferSize = nMaxBufferSize;

	TEST_REPORT(" - Testing bpf %lu, bufsize %lu (%luK)\n",nMaxBytesPerFrame,nMaxBufferSize,nMaxBufferSize >> 10);
	if((dwRet = t1394IsochSetupStream(szDeviceName,&isp)) == CAM_SUCCESS)
	{
		TEST_REPORT("   - successfully set up stream\n");
		if((dwRet = t1394IsochTearDownStream(szDeviceName)) == CAM_SUCCESS)
		{
			TEST_REPORT("   - successfully tore down stream\n");
            return true; // embedded success case
		} else {
			TEST_REPORT("   X Failed to tear down stream (%d:%s)\n",dwRet,StrLastError());
		}
	} else {
		TEST_REPORT("   X Failed to setup stream (%d:%s)\n",dwRet,StrLastError());
	}
    return false; // common failure case
}

bool testIsochBufferSize(LPSTR szDeviceName)
{
    SYSTEM_INFO si;
    GetSystemInfo(&si);

	ULARGE_INTEGER uli;
	t1394_GetHostDmaCapabilities(szDeviceName,NULL,&uli);

	TEST_REPORT("*** Starting Isoch Tests For Camera:\n%s\n",szDeviceName);
	TEST_REPORT(" - Max DMA Buffer: %I64u\n",uli);

	ISOCH_QUERY_RESOURCES iqr;
	GetMaxIsochSpeed(szDeviceName,&iqr.fulSpeed);
	t1394IsochQueryResources(szDeviceName,&iqr);
	TEST_REPORT(" - IsochResources: fulSpeed: %08x\n",iqr.fulSpeed);
	TEST_REPORT(" - IsochResources: bpfAvail: %d\n",iqr.BytesPerFrameAvailable);
	TEST_REPORT(" - IsochResources: channels: %016I64x\n",iqr.ChannelsAvailable);

	for(int jj = 1; jj <= 4096; jj <<= 1)
	{
        unsigned long bufsize = jj*1024*3;
        bool expectedRet = bufsize <= uli.QuadPart - si.dwPageSize;
		bool bRet = testIsochStreamAlloc(szDeviceName,4096,bufsize);
        if(expectedRet != bRet)
        {
            TEST_REPORT_ERROR(" - unexpected %s for bufsize %u",bRet ? "SUCCESS" : "FAILURE", bufsize);
        }
	}

    if(uli.HighPart == 0 &&
       uli.LowPart < (1<<26) )
    {
        // probably on a 64-bit machine, explicitly test one page short of max, and max:
        SYSTEM_INFO si;
	    GetSystemInfo(&si);
	    if(!testIsochStreamAlloc(szDeviceName,4096,uli.LowPart - si.dwPageSize))
        {
            TEST_REPORT_ERROR(" - unexpected FAILURE for bufsize %u",uli.LowPart - si.dwPageSize);
        }

	    if(testIsochStreamAlloc(szDeviceName,4096,uli.LowPart))
        {
            TEST_REPORT_ERROR(" - unexpected SUCCESS for bufsize %u",uli.LowPart);
        }
    }
    return true;
}

bool testFullStreamSetup(LPSTR szDeviceName, ULONG frameBufferSize, ULONG bytesPerPacket, ULONG nFrameBuffers)
{
    TEST_REPORT("*** Starting Full Stream Setup Test: fb = %u, bpp = %u, n = %u\n",
            frameBufferSize, bytesPerPacket, nFrameBuffers);

	// tear down: just in case
	(void)(t1394IsochTearDownStream(szDeviceName));
	
    bool bRet = false;
    SYSTEM_INFO si;
    GetSystemInfo(&si);
    TEST_REPORT(" - Host Page Size: %u\n",si.dwPageSize);

	ULARGE_INTEGER uli;
	t1394_GetHostDmaCapabilities(szDeviceName,NULL,&uli);
	TEST_REPORT(" - Max DMA Buffer: %I64u\n",uli);

	ISOCH_QUERY_RESOURCES iqr;
	GetMaxIsochSpeed(szDeviceName,&iqr.fulSpeed);
	t1394IsochQueryResources(szDeviceName,&iqr);
	TEST_REPORT(" - IsochResources: fulSpeed: %08x\n",iqr.fulSpeed);
	TEST_REPORT(" - IsochResources: bpfAvail: %d\n",iqr.BytesPerFrameAvailable);
	TEST_REPORT(" - IsochResources: channels: %016I64x\n",iqr.ChannelsAvailable);

	ULONG ulMaxSpeed = 0;
	GetMaxIsochSpeed(szDeviceName,&ulMaxSpeed);
	TEST_REPORT(" - Max Speed host <-> device = %08x\n",ulMaxSpeed);
	if(ulMaxSpeed < iqr.fulSpeed)
	{
		iqr.fulSpeed = ulMaxSpeed;
	}
/*
	ULONG ulData;
	ReadRegisterUL(szDeviceName,0x60c, &ulData);
	if(iqr.fulSpeed > 4 || ulData & 0x00008000)
	{
		//1394b mode, we pack the low 15 bits of 0x60C with channel,speed
		ulData |= 0x00008000;
		ulData &= 0xffff8000;
		// channel = 0
		ulData |= SpeedFlagToIndex(iqr.fulSpeed);
	} else {
		//1394a mode, we pack the high 8 bits of 0x60C with channel,speed
		ulData &= 0x0000ffff;
		ulData |= (SpeedFlagToIndex(iqr.fulSpeed) << 24);
	}
	WriteRegisterUL(szDeviceName, 0x60c, ulData);
*/
    if(bytesPerPacket > iqr.BytesPerFrameAvailable)
    {
        TEST_REPORT(" - bpf requested exceeds bpf available (%u > %u) - skipping test)\n",
               bytesPerPacket, iqr.BytesPerFrameAvailable);
        return true; // this is not an error case
    }

    if(bytesPerPacket > iqr.fulSpeed * 1024)
    {
        TEST_REPORT(" - bpf requested exceeds bus spec for single isoch frame at %u00 mpbs (%u > %u) - skipping test",
                    iqr.fulSpeed, bytesPerPacket, iqr.fulSpeed * 1024);
        return true; // this is not an error case either
    }

    std::vector<PACQUISITION_BUFFER> frameBuffers;
    for(ULONG ii = 0; ii < nFrameBuffers; ++ii)
    {
        PACQUISITION_BUFFER pab = dc1394BuildAcquisitonBuffer(frameBufferSize,(unsigned long)(uli.QuadPart),bytesPerPacket,ii);
        if(pab == NULL)
        {
            TEST_REPORT("   - Failed to allocate buffer %u",ii);
            goto _cleanup;
        } else {
            frameBuffers.push_back(pab);
        }
    }

	double leadingFrames = (double)(frameBuffers.front()->subBuffers[0].ulSize) / (double)bytesPerPacket;
	double trailingFrames = (double)(frameBuffers.front()->subBuffers[frameBuffers.front()->nSubBuffers - 1].ulSize) / (double)bytesPerPacket;

	TEST_REPORT(" - Allocated %u buffers of %u bytes each (%u sub-buffers, leading = %u@%u bytes (%.2f frames), trailing = %u bytes (%.2f frames))\n",
				nFrameBuffers,frameBuffers.front()->ulBufferSize, frameBuffers.front()->nSubBuffers,
				frameBuffers.front()->nSubBuffers - 1,frameBuffers.front()->subBuffers[0].ulSize,leadingFrames,
				frameBuffers.front()->subBuffers[frameBuffers.front()->nSubBuffers - 1].ulSize,trailingFrames);

	printf("   -> leadingBuffer = %.2f frames, trailingBuffer = %.2f frames\n", leadingFrames, trailingFrames);

	DWORD dwRet,dwBytesRet;
	ISOCH_STREAM_PARAMS isp;
	GetMaxIsochSpeed(szDeviceName,&isp.fulSpeed);
	isp.nChannel = -1;
    isp.nMaxBytesPerFrame = bytesPerPacket;
    isp.nNumberOfBuffers = 1 + (ULONG)(frameBuffers.size() * frameBuffers[0]->nSubBuffers);
	isp.nMaxBufferSize = frameBuffers[0]->subBuffers[0].ulSize;

	TEST_REPORT(" - Setting up stream for bpf %lu, bufsize %lu (%luK), %u buffers max\n",
        isp.nMaxBytesPerFrame,isp.nMaxBufferSize,isp.nMaxBufferSize >> 10, isp.nNumberOfBuffers);

	if((dwRet = t1394IsochSetupStream(szDeviceName,&isp)) == CAM_SUCCESS)
	{
		TEST_REPORT("   -> Post setup: channel = %d, bpf %lu, bufsize %lu (%luK), %u buffers max\n",
            isp.nChannel,isp.nMaxBytesPerFrame,isp.nMaxBufferSize,isp.nMaxBufferSize >> 10, isp.nNumberOfBuffers);

        // successfully setup the stream, attach buffers
        HANDLE hDevAcq = OpenDevice(szDeviceName,TRUE);
        for(std::vector<PACQUISITION_BUFFER>::iterator ii = frameBuffers.begin();
            ii != frameBuffers.end(); ++ii)
        {
            if((dwRet = dc1394AttachAcquisitionBuffer(hDevAcq,*ii)) != ERROR_SUCCESS)
            {
                TEST_REPORT("Error %08x while Attaching Buffer %u\n",dwRet,(*ii)->index);
			    goto _cleanup;
		    } else {
			    TEST_REPORT("  - attached buffer %u\n",(*ii)->index);
            }
	    }

		Sleep(100);
        for(std::vector<PACQUISITION_BUFFER>::iterator ii = frameBuffers.begin();
            ii != frameBuffers.end(); ++ii)
        {
			// check the IO status, just in case
            for(ULONG bb = 0; bb<(*ii)->nSubBuffers; ++bb)
            {
				TEST_REPORT("  - Pre-teardown: Checking on sub-buffer %d.%d\n",(*ii)->index,bb);
	    		if(!GetOverlappedResult(hDevAcq, &((*ii)->subBuffers[bb].overLapped), &dwBytesRet, FALSE))
		    	{
					TEST_REPORT("     - Buffer %d.%d reports error = %d:%s",
				    	    (*ii)->index,bb,GetLastError(),StrLastError());
				} else {
					TEST_REPORT("     - Buffer successfully attached@: %u bytes returned!\n",
								dwBytesRet );
				}

            }
		}

    	// isoch listen
	    if((dwRet = t1394IsochListen(szDeviceName)) != ERROR_SUCCESS)
	    {
			TEST_REPORT("Error on t1394IsochListen: %s",StrLastError());
			//CancelIo(hDevAcq);
	    	goto _cleanup;
		} else {
	        TEST_REPORT("**** SUCCESSFULLY ALLOCATED AND LISTENING, SLEEPING FOR A LITTLE WHILE ****\n");
		    Sleep(100);
			bRet = true;
		}


_cleanup:
        
        if((dwRet = t1394IsochTearDownStream(szDeviceName)) == CAM_SUCCESS)
		{
			TEST_REPORT("   - successfully tore down stream\n");
		} else {
			TEST_REPORT(" - Failed to tear down stream (%d:%s)\n",dwRet,StrLastError());
		}

        for(std::vector<PACQUISITION_BUFFER>::iterator ii = frameBuffers.begin();
            ii != frameBuffers.end(); ++ii)
        {
    		TEST_REPORT(" - cleaning up buffer %d\n",(*ii)->index);
			// check the IO status, just in case
            for(ULONG bb = 0; bb<(*ii)->nSubBuffers; ++bb)
            {
    			TEST_REPORT("  - Checking on sub-buffer %d.%d\n",(*ii)->index,bb);
	    		if(!GetOverlappedResult(hDevAcq, &((*ii)->subBuffers[bb].overLapped), &dwBytesRet, TRUE))
		    	{
					TEST_REPORT("     - warning: Buffer %d.%d has not been detached, error = %d:%s",
				    	    (*ii)->index,bb,GetLastError(),StrLastError());
				} else {
					TEST_REPORT("     - Buffer successfully detached: %u bytes returned!",
								dwBytesRet );
				}

            }
            dc1394FreeAcquisitionBuffer(*ii);
		}
        frameBuffers.clear();

        CloseHandle(hDevAcq);
	} else {
		TEST_REPORT("   X Failed to setup stream (%d:%s)\n",dwRet,StrLastError());
	}
    return bRet;
}

int main(int argc, const char **argv, const char **envp)
{
    std::string filename = getenv("UserProfile");
    filename += "\\Desktop\\isochtest-log.txt";
    logfile = fopen(filename.c_str(),"w");
    printf("Starting isochronous setup unit test: log file = %s\n",filename.c_str());
    if(logfile == NULL)
    {
        printf("  -> failed to open log file: redirecting test reports to stderr\n"),
        logfile = stderr;
    }

	HDEVINFO hDI = t1394CmdrGetDeviceList();
	printf("Enumerating connected cameras...\n");
	// count devices
	char buf[512];
	int ii;
	ULONG sz = sizeof(buf);
	for(ii=0; ;++ii)
	{
		sz = sizeof(buf);
		if(t1394CmdrGetDevicePath(hDI,ii,buf,&sz) <= 0)
		{
			printf(" --- no more devices\n");
			break;
		}

        printf(" -- testing camera %d (%s)\n",ii,buf);

        //testIsochBufferSize(buf);

        for(int ff = 0; ff < 3; ++ff)
        {
            for(int mm = 0; mm < 8; ++mm)
            {
                unsigned long bufSize = dc1394GetBufferSize(ff,mm);
                if(bufSize > 0)
                {
                    char modeName[256];
                    dc1394GetModeString(ff,mm,modeName,256);
                    for(int rr = 0; rr < 8; ++rr)
                    {
                        LONG qpp = dc1394GetQuadletsPerPacket(ff,mm,rr);
                        if(qpp > 0)
                        {
                            TEST_REPORT(" - Testing (%d,%d,%d) = %s @ %.3ffps\n",
                                ff,mm,rr,modeName,1.875 * (double)(1 << rr));
                            printf("   ---- Testing (%d,%d,%d) = %s @ %.3ffps\n",
                                ff,mm,rr,modeName,1.875 * (double)(1 << rr));
                            if(!testFullStreamSetup(buf,bufSize,(ULONG)qpp * 4,5))
                            {
                                TEST_REPORT_ERROR("   -> Unexpected failure setting up full stream!\n");
								printf("   -> ERROR (bufSize = %u, bpp = %u)\n",bufSize,(ULONG)qpp * 4);
								//return 0;
                            }
                        }
                    }
                }
            }
        }

        TEST_REPORT(" - Testing Format 7 Oddities\n");
        TEST_REPORT("   - Testing %d/%d\n",1449240,3716);
        if(!testFullStreamSetup(buf,1449240,3716,5))
        {
            TEST_REPORT_ERROR("   -> Unexpected failure setting up full stream!\n");
        }
    }

    printf("Finished! %u unexpected errors while processing %d cameras\n",
            g_errorCount, ii);

	SetupDiDestroyDeviceInfoList(hDI);
	_getch();
	return 0;
}

