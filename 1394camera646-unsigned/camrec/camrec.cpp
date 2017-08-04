#include <windows.h>
#include <1394Camera.h>
#include <stdio.h>
#include <conio.h>
#include <time.h>

// the buffer between the two threads will be this big
#define BUFFER_SIZE 128

// 640x480xYUV411 = 640*480*1.5 = 460800 bytes per frame
#define DATA_SIZE 460800

// it's kind of big for a global variable, but who cares?
unsigned char buffers[BUFFER_SIZE][DATA_SIZE];

C1394Camera theCamera;
HANDLE hReadyBlocksSem;
int keep_recording;
int firstready,firstfree;
FILE *outfile;
HANDLE houtfile,hGoEvent;
int frameswritten = 0,framesread = 0;
int grabberdone = 0,writerdone = 0;

struct rawcam_header
{
	int magic_number;
	int mode;
	int format;
	int nframes;
	int datasize;
};

DWORD WINAPI grabberThr(LPVOID pParams);
DWORD WINAPI writerThr(LPVOID pParams);
void WritePPMs();
void YUV411toRGB(unsigned char *in, unsigned char *out, int w, int h);

int main(int argc, char **argv, char **envp)
{
	HANDLE hGrabberThr,hWriterThr;
	DWORD dwGrabberThrId,dwWriterThrId,dwExitCode;
	char c;

	hReadyBlocksSem = CreateSemaphore(NULL,0,BUFFER_SIZE,NULL);
	if(hReadyBlocksSem == NULL)
	{
		printf("Couldn't Create Semaphore\n");
		return 0;
	}

	// we're using the raw windows calls here because they're
	// *much* faster than fstreams or FILE*'s

	// FILE_FLAG_SEQUENTIAL_SCAN tells windows to optimize its caching
	// for sequential reads and writes, which is handy when you're dumping
	// soooo much data into a file

	// it also helps if the file already exists and is defragmented
	// i.e. c:/camrec-raw.dat is a permanent 500 MB resident on my HDD

		if(theCamera.CheckLink())
	{
		printf("Error checking link for camera 0\n");
		CloseHandle(hReadyBlocksSem);
		return 0;
	}

	printf("Initializing Camera...\n");
	theCamera.InitCamera(TRUE);

	printf("Camera defaults to %d,%d,%d\n",
			theCamera.GetVideoFormat(),
			theCamera.GetVideoMode(),
			theCamera.GetVideoFrameRate());

	if(theCamera.HasSIO())
	{
		printf("Camera has SIO control at %p\n",theCamera.GetSIOControlOffset());
		theCamera.SIOConfigPort(9600,8,1,0);
		theCamera.SIOEnable(TRUE,TRUE);
		while(1)
		{
			int ret;
			unsigned char buf[8];
			buf[0] = 'a';
			buf[1] = 'X';
			buf[2] = 'Y';
			buf[3] = 's';
			buf[4] = 'r';
			buf[5] = 'Z';
			buf[6] = '5';
			buf[7] = '%';
			theCamera.SIOWriteBytes(buf,8);

			printf("wrote %d bytes\n",8);
			while((ret = theCamera.SIOReadBytes(buf,7)) > 0)
			{
				buf[ret] = 0;
				printf("Read %d bytes:%s\n",ret,buf);
			}
			Sleep(10);
		}
	}

	if(!theCamera.HasVideoFrameRate(0,2,2))
	{
		printf("This stupid little program only understands 640x480 YUV4:1:1 - and your camera does not support it.  Goodbye");
		return 0;
	}

	theCamera.SetVideoFormat(0);
	theCamera.SetVideoMode(2);
	theCamera.SetVideoFrameRate(2);

	printf("Camera configured to %d,%d,%d\n",
			theCamera.GetVideoFormat(),
			theCamera.GetVideoMode(),
			theCamera.GetVideoFrameRate());

	houtfile = CreateFile("c:/capture/camrec-raw.dat",
						  GENERIC_WRITE,
						  0,
						  NULL,
						  OPEN_ALWAYS,
						  FILE_FLAG_SEQUENTIAL_SCAN,
						  NULL);

	hGoEvent = CreateEvent(NULL,TRUE,FALSE,NULL);

	if(houtfile == INVALID_HANDLE_VALUE)
	{
		printf("Couldn't open output file (%d)\n",GetLastError());
		CloseHandle(hReadyBlocksSem);
		return 0;
	}

	keep_recording = 1;

	firstready = -1;
	firstfree = 0;

	hWriterThr = CreateThread(NULL,0,writerThr,NULL,0,&dwWriterThrId);
	printf("Writer Thread ID = %d\n",dwWriterThrId);

	hGrabberThr = CreateThread(NULL,0,grabberThr,NULL,0,&dwGrabberThrId);
	printf("Grabber Thread ID = %d\n",dwGrabberThrId);

	printf("press any key to begin recording, then press 'q' to quit\n\n");
	getch();

	SetEvent(hGoEvent);

	while(getch() != 'q');

	keep_recording = 0;

	while(!grabberdone || !writerdone)
		Sleep(200);

	while(STILL_ACTIVE == GetExitCodeThread(hGrabberThr,&dwExitCode))
		Sleep(200);

	printf("\nGrabber Thread exited with code %d\n",dwExitCode);

	while(STILL_ACTIVE == GetExitCodeThread(hWriterThr,&dwExitCode))
		Sleep(200);

	printf("Writer Thread exited with code %d\n",dwExitCode);

	printf("I wrote %d of %d frames (%f%% loss)\n",
		   frameswritten,
		   framesread, 
		   100.0f * (float)(framesread - frameswritten)/(float)(framesread));

	CloseHandle(hReadyBlocksSem);
	CloseHandle(houtfile);

	do
	{
		printf("Write Frames to PPM? (y/n)");
		c = getch();
	} while(c != 'y' && c != 'n');

	if(c == 'y')
		WritePPMs();	

	return 0;
}

// this thread grabs images from the camera and stuffs the raw data 
// into the buffer.  If the buffer's full, the frame is simply dropped.

DWORD WINAPI grabberThr(LPVOID pParams)
{
	int framesdumped;
	long prevcount;

	framesread = framesdumped = 0;
	WaitForSingleObject(hGoEvent,INFINITE);
	theCamera.StartImageAcquisition();
 	while(keep_recording)
	{
		theCamera.AcquireImage();
		framesread++;
		if(firstfree == firstready)
		{
			framesdumped++;
			printf("\r%d read, %d written, %d dumped (%f%% loss) buffer at (%d/%d)",
				   framesread,
				   frameswritten,
				   framesdumped,
				   100.0f * (float)(framesdumped)/(float)(framesread),
				   BUFFER_SIZE,
				   BUFFER_SIZE);
   					   
		} else {
			unsigned char *pRawData;
			unsigned long ulRawDataLen;
			pRawData = theCamera.GetRawData(&ulRawDataLen);
			if(pRawData)
			{
				memcpy(buffers[firstfree],pRawData,ulRawDataLen);
				firstfree = (firstfree + 1) % BUFFER_SIZE;
				ReleaseSemaphore(hReadyBlocksSem,1,&prevcount);
				printf("\r%d read, %d written, %d dumped (%f%% loss) buffer at (%d/%d)    ",
					   framesread,
					   frameswritten,
					   framesdumped,
					   100.0f * (float)(framesdumped)/(float)(framesread),
					   (firstfree > firstready ? firstfree : firstfree + BUFFER_SIZE) - firstready - 1,
					   BUFFER_SIZE
   					   );
			}
		}
		fflush(stdout);
	}

	theCamera.StopImageAcquisition();
	grabberdone = 1;
	return 0;
}

// writerThr
// writes the raw data to disk in the largest chunks possible.
// disk bandwidth is *always* the limiting factor

DWORD WINAPI writerThr(LPVOID pParams)
{
	unsigned int i,j,k;
	ULONG status;
	DWORD byteswritten;

	i = 0;

	//WaitForSingleObject(hGoEvent,INFINITE);

	while(1)
	{
		status = WaitForSingleObject(hReadyBlocksSem,100);
		if(status == WAIT_OBJECT_0)
		{
			i++;
			j = 1;
			k = 0;
			while(WaitForSingleObject(hReadyBlocksSem,0) == WAIT_OBJECT_0)
			{ i++; j++; }

			if(firstready + j >= BUFFER_SIZE)
			{
				k = BUFFER_SIZE - firstready - 1;
				j -= k;
				if(!WriteFile(houtfile,buffers[(firstready + 1) % BUFFER_SIZE],k * DATA_SIZE, &byteswritten, NULL))
					fprintf(stderr,"\nWriterThread: error writing data (frames %d-%d)\n",i-j,i);
				if(byteswritten != k * DATA_SIZE)
					fprintf(stderr,"\nWriterThread: only wrote %d of %d bytes\n",i-j,i);

			}

			if(!WriteFile(houtfile,buffers[(firstready + k + 1) % BUFFER_SIZE],j * DATA_SIZE, &byteswritten, NULL))
				fprintf(stderr,"\nWriterThread: error writing data (frames %d-%d)\n",i-j,i);
			if(byteswritten != j * DATA_SIZE)
				fprintf(stderr,"\nWriterThread: only wrote %d of %d bytes\n",i-j,i);

			frameswritten = i;
			firstready = (i-1) % BUFFER_SIZE;
		} else {
			/* must be empty, see if I should leave */
			if(!keep_recording)
				break;
		}
	}

	writerdone = 1;
	return 0;
}

// writes the contents of camrec-raw.dat to *tons* of individual .ppm files
// in the c:\frames directory

void WritePPMs()
{
	int i;
	HANDLE hinfile;
	FILE *outfile;
	unsigned char *outbuf;
	unsigned char *inbuf;
	char buf[256];
	DWORD bytesread;

	inbuf = buffers[0];
	outbuf = buffers[1];

	hinfile = CreateFile("c:/capture/camrec-raw.dat",
						  GENERIC_READ,
						  0,
						  NULL,
						  OPEN_EXISTING,
						  FILE_FLAG_SEQUENTIAL_SCAN,
						  NULL);

	if(hinfile == INVALID_HANDLE_VALUE)
	{
		printf("Couldn't open input file\n");
		CloseHandle(hReadyBlocksSem);
		return;
	}

	for(i=0; i<frameswritten; i++)
	{
		if(!ReadFile(hinfile,inbuf,DATA_SIZE,&bytesread,NULL))
		{
			printf("\nWritePPMs: error reading frame %d\n",i);
			CloseHandle(hinfile);
			return;
		}

		if(bytesread != DATA_SIZE)
		{
			printf("\nWritePPMs: only read %d/%d bytes of frame %d\n",bytesread,DATA_SIZE,i);
			CloseHandle(hinfile);
			return;
		}

		YUV411toRGB(inbuf,outbuf,640,480);
        
		sprintf(buf,"c:\\capture\\frame%04d.ppm",i);
		printf("\rWriting frame %d/%d to %s",i+1,frameswritten,buf);
		fflush(stdout);
		if((outfile = fopen(buf,"wb")) == NULL)
		{
			printf("\nWritePPMs: error opening output file \"%s\" (%s)\n",buf,strerror(errno));
			CloseHandle(hinfile);
			return;
		}
		fprintf(outfile,"P6\n640\n480\n255\n");
		if(1 != fwrite(outbuf,640*480*3,1,outfile))
		{
			printf("\nWritePPMs: error writing to output file \"%s\" (%s)\n",buf,strerror(errno));
			CloseHandle(hinfile);
			return;
		}
		fclose(outfile);
	}
	CloseHandle(hinfile);
	printf("\nDeleting raw capture file...\n");
	DeleteFile("c:/capture/camrec-raw.dat");
	printf("\nDone\n");
}

// this conversion is straight out of the 1394camera source code

#define CLAMP_TO_UCHAR(a) (unsigned char)((a) < 0 ? 0 : ((a) > 255 ? 255 : (a)))

void YUV411toRGB(unsigned char *in, unsigned char *out, int w, int h)
{
	long Y, U, V, deltaG;
	unsigned char *srcptr, *srcend, *destptr;

	// data pattern: UYYVYY

	srcptr = in;
	srcend = srcptr + ((w * h * 3) >> 1);
	destptr = out;

	while(srcptr < srcend)
	{
		U = (*srcptr) - 128;
		V = (*(srcptr+3)) - 128;

		deltaG = (12727 * U + 33384 * V);
		deltaG += (deltaG > 0 ? 32768 : -32768);
		deltaG >>= 16;

		Y = *(srcptr + 1);
		*destptr++ = CLAMP_TO_UCHAR( Y + V );
		*destptr++ = CLAMP_TO_UCHAR( Y - deltaG );
		*destptr++ = CLAMP_TO_UCHAR( Y + U );

		Y = *(srcptr + 2);
		*destptr++ = CLAMP_TO_UCHAR( Y + V );
		*destptr++ = CLAMP_TO_UCHAR( Y - deltaG );
		*destptr++ = CLAMP_TO_UCHAR( Y + U );

		Y = *(srcptr + 4);
		*destptr++ = CLAMP_TO_UCHAR( Y + V );
		*destptr++ = CLAMP_TO_UCHAR( Y - deltaG );
		*destptr++ = CLAMP_TO_UCHAR( Y + U );

		Y = *(srcptr + 5);
		*destptr++ = CLAMP_TO_UCHAR( Y + V );
		*destptr++ = CLAMP_TO_UCHAR( Y - deltaG );
		*destptr++ = CLAMP_TO_UCHAR( Y + U );

		srcptr += 6;
	}
}