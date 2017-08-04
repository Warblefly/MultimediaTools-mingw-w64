// autoupdater.cpp : console app to install/remove the 1394 digital camera driver
// this is based loosely on the "InstDrv" plugin for the NullSoft Scriptable Install System
//  http://nsis.sourceforge.net/InstDrv_plug-in

#include <stdio.h>
#include <windows.h>
#include <newdev.h>
#include <winerror.h>
#include <conio.h>

#include "../1394camera/1394Camera.h"

void printUsage()
{
    printf("Usage: autoupdater.exe [/i | /u]\n");
    printf("  /i -> Install the CMU 1394 Camera Driver for all compatible devices\n");
    printf("  /u -> Remove all device instances using the CMU 1394 Camera Driver\n");
    printf("  no args: interactive mode (mostly for testing)");
}

int installCMUDriver();
int uninstallCMUDriver();
int setTestMode(bool active);

int main(int argc, char *argv[])
{
    if(argc == 1)
    {
        // interactive mode
        while(1)
        {
            printf("CMU 1394 Digitial Camera Driver: Automatic Driver Installer - Interactive Menu\n");
            printf("  i - Install the driver for all compatible devices\n");
            printf("  u - Delete all device instances presently using the CMU driver\n");
            printf("  T - enable test mode\n");
            printf("  t - disable test mode\n");
            printf("  q - quit\n\nEnter your selection: ");
            char cc = _getch();
            printf("\n\n");
            switch(cc)
            {
                case 'i': installCMUDriver(); break;
                case 'u': uninstallCMUDriver(); break;
				case 'T': setTestMode(true); break;
				case 't': setTestMode(false); break;
                case 'q': printf("Exiting...\n"); return 0;
                default: printf("Unrecognized Command '%c'\n",cc); break;
            }
            printf("\n\n");
        }
    }
    else if(argc == 2)
    {
        if(!strncmp(argv[1],"/i",3))
        {
            return installCMUDriver();
        }
        else if(!strncmp(argv[1],"/u",3))
        {
            return uninstallCMUDriver();
        }
        else if(!strncmp(argv[1],"/teston",8))
        {
            return setTestMode(true);
        }
        else if(!strncmp(argv[1],"/testoff",9))
        {
            return setTestMode(false);
        }
        else
        {
            printf("Unrecognized Argument: '%s'\n",argv[1]);
            // fall through to common print and bail...
        }
    }
    else
    {
        printf("Too Many Arguments: %d",argc);
       // fall through to common print and bail...
    }

    printUsage();
    return -1;
}

int installCMUDriver()
{
	LPCSTR compatibleIDList[3] = {
		"1394\\A02D&100",
		"1394\\A02D&101",
		"1394\\A02D&102"
	};

    HKEY hKey = OpenCameraSettingsKey("",0,KEY_READ);
    if(hKey != NULL)
    {
        char installPath[4096];
        DWORD dwFoo = 0,dwType = 0, dwSize = 4096;
        DWORD dwRet = RegQueryValueEx(hKey,"InstallPath",0,&dwType,(LPBYTE)installPath,&dwSize);
	    if(dwRet != ERROR_SUCCESS)
        {
            printf("Failed to load install path from registry!");
            return -1;
        }

        printf("Install path is:\n  '%s' (%d bytes long)\n",installPath,dwSize);
        strncpy(&(installPath[dwSize-1]),"\\Driver\\1394Camera.inf",4096 - dwSize);

	    BOOL rebootRequired = FALSE;
	    for(int ii = 0; ii < 3; ++ii)
	    {
		    BOOL reboot = FALSE;
    	    printf("\nUpdating Driver For CompatibleID '%s'\n  -> '%s'...\n",compatibleIDList[ii],installPath);
		    if(!UpdateDriverForPlugAndPlayDevices(NULL,compatibleIDList[ii],installPath,INSTALLFLAG_FORCE,&reboot))
		    {
                printf(" -> Failed to Update Driver! - %08x (%d)\n",GetLastError(),GetLastError() & 0x0000FFFF);
            } else {
                printf(" -> Success!\n");
            }
		    rebootRequired |= reboot;
	    }

	    if(rebootRequired)
	    {
		    printf("... technically speaking, you must now reboot!\n");
	    }
	    return 0;

    } else {
        printf("Failed to load camera registry key!");
        return -1;
    }
}

int uninstallCMUDriver()
{
    GUID guid = t1394CmdrGetGUID();
    HDEVINFO hDI = SetupDiGetClassDevs(&guid,NULL,NULL,DIGCF_DEVICEINTERFACE);
    if(hDI != INVALID_HANDLE_VALUE)
    {
        SP_DEVINFO_DATA devInfoData;
        int index = 0;
        devInfoData.cbSize = sizeof(SP_DEVINFO_DATA);
        while(SetupDiEnumDeviceInfo(hDI,index,&devInfoData))
        {
            printf(" - Device %d:\n",index);
            if(index == 0)
            {
                // look for OEM inf files
                if(SetupDiBuildDriverInfoList(hDI,&devInfoData,SPDIT_COMPATDRIVER))
                {
                    SP_DRVINFO_DATA drvInfoData;
                    drvInfoData.cbSize = sizeof(SP_DRVINFO_DATA);
                    int driverIndex = 0;
                    while(SetupDiEnumDriverInfo(hDI,&devInfoData,SPDIT_COMPATDRIVER,driverIndex++,&drvInfoData))
                    {
                        SP_DRVINFO_DETAIL_DATA drvInfoDetail;
                        drvInfoDetail.cbSize = sizeof(SP_DRVINFO_DETAIL_DATA);
                        BOOL ret = SetupDiGetDriverInfoDetail(hDI,&devInfoData,&drvInfoData,&drvInfoDetail,drvInfoDetail.cbSize,NULL);
                        if(ret || GetLastError() == ERROR_INSUFFICIENT_BUFFER)
                        {
                            printf("    - has OEM inf file '%s'\n",drvInfoDetail.InfFileName);
                            if(!DeleteFile(drvInfoDetail.InfFileName))
                            {
                                printf("      - could not delete '%s' : %d",drvInfoDetail.InfFileName,GetLastError());
                            }
                            drvInfoDetail.InfFileName[lstrlen(drvInfoDetail.InfFileName) - 3] = 'p';
                            if(!DeleteFile(drvInfoDetail.InfFileName))
                            {
                                printf("      - could not delete '%s' : %d",drvInfoDetail.InfFileName,GetLastError());
                            }
                        } else {
                            printf("    - SetupDiGetDriverInfoDetail: %d\n",GetLastError());
                        }
                    }
                
                    if(GetLastError() != ERROR_NO_MORE_ITEMS)
                    {
                        printf("    - SetupDiEnumDriverInfo: %d\n",GetLastError());
                    }

                    SetupDiDestroyDriverInfoList(hDI,&devInfoData,SPDIT_COMPATDRIVER);
                } else {
                    printf("    - SetupDiEnumDriverInfo: %d\n",GetLastError());
                }
            } // else already nuked oem inf files

            if(SetupDiCallClassInstaller(DIF_REMOVE,hDI,&devInfoData))
            {
                printf("    - has been removed!\n");
            } else {
                printf("    - could not be removed: %d\n",GetLastError());
            }

            index++;
        }

		if(index == 0)
		{
			printf("No Devices Found!\n");
		}

        SetupDiDestroyDeviceInfoList(hDI);
    } else {
        printf("Failed to get class devs!\n");
    }
	return 0;
}

int setTestMode(bool active)
{
	if(active)
	{
		ShellExecute(NULL,"open","bcdedit.exe","/set TESTSIGNING ON",NULL,SW_SHOWDEFAULT);
	} else {
		ShellExecute(NULL,"open","bcdedit.exe","/set TESTSIGNING OFF",NULL,SW_SHOWDEFAULT);
	}
	return 0;
}
