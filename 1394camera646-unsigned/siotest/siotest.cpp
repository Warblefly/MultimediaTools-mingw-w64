#include <windows.h>
#include <1394Camera.h>
#include <stdio.h>

struct StatusByte {
	unsigned char transmitReady:1;
	unsigned char _res0:1;
	unsigned char receiveReady:1;
	unsigned char _res1:1;
	unsigned char bufferOverrun:1;
	unsigned char framingError:1;
	unsigned char parityError:1;
	unsigned char _res2:1;
};

const char *FormatStatusString(StatusByte &statusByte)
{
	static char buf[64];
	sprintf(buf,"( %s%s%s%s%s%s%s%s)",
		statusByte.transmitReady ? "TxRdy " : "",
		statusByte.receiveReady ?  "RxRdy " : "",
		statusByte.bufferOverrun ? "OvRun " : "",
		statusByte.framingError ? "FrErr " : "",
		statusByte.parityError ? "PyErr " : "",
		statusByte._res0 ? "Res0 " : "",
		statusByte._res1 ? "Res1 " : "",
		statusByte._res2 ? "Res2 " : "");
	return buf;
}

int main()
{
	unsigned int totalSent = 0, totalReceived = 0, totalNonMatching = 0;
	C1394Camera theCamera;
	theCamera.CheckLink();
	theCamera.SelectCamera(0);
	theCamera.InitCamera(1);

	theCamera.SIOConfigPort(300,8,1,0);
	theCamera.SIOEnable(1,1);
	unsigned char ibuf[64],obuf[64];
	for(int ii = 0; ii < 26; ++ii)
	{
		obuf[ii] = 'a' + ii;
		obuf[ii+26] = 'A' + ii;
		if(ii < 10)
		{
			obuf[ii+52] = '0' + ii;
		}
	}

	obuf[62]='+';
	obuf[63]='-';

	for(int rounds=0; rounds<2; rounds++)
	{
		for(int ii = 0; ii<64; ++ii)
		{
			int ret = theCamera.SIOWriteBytes(obuf,ii+1);
			printf("Wrote %d of %d bytes\n",ret,ii+1);
			totalSent += ret;
			bool mustReset = false;
			for(int jj=0; jj <ii+1; )
			{
				Sleep(10);
				ret = theCamera.SIOReadBytes(ibuf+jj,64-jj);
				totalReceived += ret;
				StatusByte statusByte;
				theCamera.GetSIOStatusByte((unsigned char *)&statusByte);
				//printf(" -> Read back %d bytes (status = %s):\n",ret,FormatStatusString(statusByte));
				for(int kk = 0; kk < ret; ++kk)
				{
					if(ibuf[jj+kk] != obuf[jj+kk])
					{
						printf("   -> Match Fail: (%02x != %02x) : %s\n",(unsigned int)ibuf[jj+kk],(unsigned int)obuf[jj+kk],FormatStatusString(statusByte));
						++totalNonMatching;
						mustReset = true;
					}
				}
				jj += ret;
			}
			if(mustReset)
			{
				theCamera.SIOEnable(1,1);
			}

		}
	}

	printf("Loopback Tests Complete: Sent %d, Received %d, Errors = %d  (%.1f%%)\n",
		totalSent,totalReceived,totalNonMatching,100.0 * (double)(totalNonMatching) / (double)(totalReceived));

	unsigned long ulConfigRegister;
	theCamera.GetSIOConfig(&ulConfigRegister);
	printf(" - Config register = %08x -\n",ulConfigRegister);
	return 0;
}
