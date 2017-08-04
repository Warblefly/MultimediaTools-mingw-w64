/*++
Copyright (c) 1998 Microsoft Corporation

Module Name:

    1394cmdr.c

Abstract:

Author:

    Peter Binder (pbinder) 4/13/98

Revision History:
Date     Who       What
-------- --------- ------------------------------------------------------------
4/13/98  pbinder   taken from original 1394Diag...
--*/

#define _1394CMDR_C
#include "pch.h"
#undef _1394CMDR_C

LONG t1394CmdrDebugLevel = TL_WARNING;

NTSTATUS
t1394Cmdr_GetConfigInfo(
    IN PDEVICE_OBJECT   DeviceObject,
    IN PIRP             Irp
    );


NTSTATUS
t1394Cmdr_Cleanup(
    IN PDEVICE_OBJECT   DeviceObject,
    IN PIRP             Irp
    );

VOID
t1394Cmdr_Unload(
	IN PDRIVER_OBJECT pDriverObject
	)
{
	PDEVICE_OBJECT pDeviceObject = pDriverObject->DeviceObject;
	while(pDeviceObject)
	{
		TRACE(TL_WARNING,("Unload: Warning: Device still exists at %p\n",pDeviceObject));
		pDeviceObject = pDeviceObject->NextDevice;
	}
	TRACE(TL_ALWAYS,("Driver Unloaded\n"));
}

#define SYSTRACENAME L"SysTraceLevel"
#define SYSTRACEPATH L"\\Registry\\Machine\\Software\\CMU\\1394Camera"
NTSTATUS
DriverEntry(
    IN PDRIVER_OBJECT   DriverObject,
    IN PUNICODE_STRING  RegistryPath
    )
{
	RTL_QUERY_REGISTRY_TABLE regtable[2];
	LONG TraceLevel = t1394CmdrDebugLevel;
	TRACE(TL_ALWAYS,(_TP("1394Cmdr Loading: Version = %s (%d-bit)\n"),CMDR_VERSIONSTRING,8 * sizeof(void *)));

	/* reading a registry value from here is a little... onerous */
	RtlZeroMemory(regtable,2*sizeof(RTL_QUERY_REGISTRY_TABLE));
	regtable[0].Flags = RTL_QUERY_REGISTRY_DIRECT;
	regtable[0].Name = SYSTRACENAME;
	regtable[0].DefaultType = REG_DWORD;
	regtable[0].EntryContext = &TraceLevel;

	RtlQueryRegistryValues(RTL_REGISTRY_ABSOLUTE,
												 SYSTRACEPATH,// ustrPath.Buffer,
												 regtable,
												 NULL,
												 NULL);

	TRACE(TL_ALWAYS,(_TP("TraceLevel from Registry: %d\n"),TraceLevel));
	t1394CmdrDebugLevel = TraceLevel;
	
	DriverObject->MajorFunction[IRP_MJ_CREATE]					= t1394Cmdr_Create;
	DriverObject->MajorFunction[IRP_MJ_CLOSE] 					= t1394Cmdr_Close;
	DriverObject->MajorFunction[IRP_MJ_CLEANUP] 				= t1394Cmdr_Cleanup;
	DriverObject->MajorFunction[IRP_MJ_PNP] 						= t1394Cmdr_Pnp;
	DriverObject->MajorFunction[IRP_MJ_POWER] 					= t1394Cmdr_Power;
	DriverObject->MajorFunction[IRP_MJ_DEVICE_CONTROL]	= t1394Cmdr_IoControl;
	DriverObject->MajorFunction[IRP_MJ_SYSTEM_CONTROL]	= t1394Cmdr_IoControl;
	DriverObject->DriverExtension->AddDevice						= t1394Cmdr_PnpAddDevice;
	DriverObject->DriverUnload													= t1394Cmdr_Unload;
	
	TRACE(TL_CHECK,(_TP("Driver Loaded\n")));
	return STATUS_SUCCESS;
} // DriverEntry

NTSTATUS
t1394Cmdr_Create(
    IN PDEVICE_OBJECT   DeviceObject,
    IN PIRP             Irp
    )
{
	NTSTATUS						ntStatus = STATUS_SUCCESS;
	PDEVICE_EXTENSION 	deviceExtension = (PDEVICE_EXTENSION)(DeviceObject->DeviceExtension);
	char *t;

	ENTER("t1394Cmdr_Create");
	if(deviceExtension->CSR_offset == 0xffffffff)
	{
		// we need to get config info
		if(STATUS_SUCCESS != t1394Cmdr_GetConfigInfo(DeviceObject,Irp))
		{
			TRACE(TL_ERROR,("Error getting configuration information\n"));
		} else {
			TRACE(TL_CHECK,("My offset is: 0x%08x\n",deviceExtension->CSR_offset));
			TRACE(TL_CHECK,("My specification ID is 0x%06x\n",deviceExtension->unit_spec_ID));
			if(deviceExtension->unit_spec_ID != 0x00A02D)
				TRACE(TL_ERROR,("WARNING! this does not appear to conform with the 1394 DCS\n"));
			switch(deviceExtension->unit_sw_version)
			{
			case 0x000100:
				t = "1.04";
				break;
			case 0x000101:
				t = "1.20";
				break;
			case 0x000102:
				t = "1.30";
				break;
			case 0x000103:
				t = "1.31";
				break;
			default:
				t = "unknown";
			}
			TRACE(TL_CHECK,("My software version is 0x%06x (%s)\n",
					deviceExtension->unit_sw_version, t));

			TRACE(TL_CHECK,("My name is: %s (len = %d)\n",
							&(deviceExtension->pModelLeaf->TL_Data),
						deviceExtension->ModelNameLength));

			TRACE(TL_CHECK,("My vendor is: %s (len = %d)\n",
							&(deviceExtension->pVendorLeaf->TL_Data),
						deviceExtension->VendorNameLength));

			TRACE(TL_CHECK,("Config rom at %p\n",
				deviceExtension->pConfigRom));

			TRACE(TL_CHECK,("   signature = %08x (should be 31333934)\n",
				bswap(deviceExtension->pConfigRom->CR_Signiture)));

			TRACE(TL_CHECK,("   node uniqueID = %08x%08x\n",
				deviceExtension->pConfigRom->CR_Node_UniqueID[0],
				deviceExtension->pConfigRom->CR_Node_UniqueID[1]));

		}
	}

		Irp->IoStatus.Status = STATUS_SUCCESS;
		IoCompleteRequest(Irp, IO_NO_INCREMENT);

		EXIT("t1394Cmdr_Create", ntStatus);
		return(ntStatus);
} // t1394Cmdr_Create

NTSTATUS
t1394Cmdr_Close(
    IN PDEVICE_OBJECT   DriverObject,
    IN PIRP             Irp
    )
{
    NTSTATUS    ntStatus = STATUS_SUCCESS;

    ENTER("t1394Cmdr_Close");

    Irp->IoStatus.Status = STATUS_SUCCESS;
    IoCompleteRequest(Irp, IO_NO_INCREMENT);

    EXIT("t1394Cmdr_Close", ntStatus);
    return(ntStatus);
} // t1394Cmdr_Close

void
t1394Cmdr_CancelIrp(
    IN PDEVICE_OBJECT   DeviceObject,
    IN PIRP             Irp
    )
{
    KIRQL               Irql;
    PBUS_RESET_IRP      BusResetIrp;
    PDEVICE_EXTENSION   deviceExtension;

    ENTER("t1394Cmdr_CancelIrp");

    deviceExtension = DeviceObject->DeviceExtension;

    KeAcquireSpinLock(&deviceExtension->ResetSpinLock, &Irql);

    BusResetIrp = (PBUS_RESET_IRP) deviceExtension->BusResetIrps.Flink;

    TRACE(TL_TRACE, ("Irp = 0x%x\n", Irp));

    while (BusResetIrp) {

        TRACE(TL_TRACE, ("Cancelling BusResetIrp->Irp = 0x%x\n", BusResetIrp->Irp));

        if (BusResetIrp->Irp == Irp) {

            RemoveEntryList(&BusResetIrp->BusResetIrpList);
            ExFreePool(BusResetIrp);
            break;
        }
        else if (BusResetIrp->BusResetIrpList.Flink == &deviceExtension->BusResetIrps) {
            break;
        }
        else
            BusResetIrp = (PBUS_RESET_IRP)BusResetIrp->BusResetIrpList.Flink;
    }

    KeReleaseSpinLock(&deviceExtension->ResetSpinLock, Irql);

    IoReleaseCancelSpinLock(Irp->CancelIrql);

    Irp->IoStatus.Status = STATUS_CANCELLED;
    IoCompleteRequest(Irp, IO_NO_INCREMENT);

    EXIT("t1394Cmdr_CancelIrp", STATUS_SUCCESS);
} // t1394Cmdr_CancelIrp

/////////////////////////////////////////////////////

NTSTATUS
t1394Cmdr_ReadRegister( 
    IN PDEVICE_OBJECT   DeviceObject,
    IN PIRP             Irp,
	IN ULONG			ulOffset,
	OUT PUCHAR			pData
    )
{
	IO_ADDRESS DestinationAddress;
	PDEVICE_EXTENSION deviceExtension = DeviceObject->DeviceExtension;
	NTSTATUS ntStatus = STATUS_SUCCESS;

	if(!pData)
		return STATUS_INSUFFICIENT_RESOURCES;

	pData[0] = pData[1] = pData[2] = pData[3] = 0;
	RtlZeroMemory(&DestinationAddress,sizeof(IO_ADDRESS));
	DestinationAddress.IA_Destination_Offset.Off_High = 0xffff;
	DestinationAddress.IA_Destination_Offset.Off_Low = ulOffset;
	ntStatus = t1394_AsyncRead(	DeviceObject,
								Irp,
								FALSE,  // raw mode
								TRUE,   // get generation
								DestinationAddress,
								4, // nNumberOfBytesToRead
								0, // nBlockSize (0 = default)
								0, // Flags
								0, // Generation (ignored if get generation is true),
								(PULONG) pData);
	if(!NT_SUCCESS(ntStatus))
		TRACE(TL_ERROR,("ReadRegister: error %08x on AsyncRead\n",ntStatus));
	return ntStatus;
}

/*
 * WriteRegister
 *
 * Writes a quadlet from pData into the camera registers at the (absolute) offset ulOffset
 */


NTSTATUS
t1394Cmdr_WriteRegister( 
    IN PDEVICE_OBJECT   DeviceObject,
    IN PIRP             Irp,
	IN ULONG			ulOffset,
	IN PUCHAR			pData
    )
{
  IO_ADDRESS DestinationAddress;
  PDEVICE_EXTENSION deviceExtension = DeviceObject->DeviceExtension;
  NTSTATUS ntStatus = STATUS_SUCCESS;

  if(!pData)
    return STATUS_INSUFFICIENT_RESOURCES;

  RtlZeroMemory(&DestinationAddress,sizeof(IO_ADDRESS));
  DestinationAddress.IA_Destination_Offset.Off_High = 0xffff;
  DestinationAddress.IA_Destination_Offset.Off_Low = ulOffset;
  ntStatus = t1394_AsyncWrite(DeviceObject,
			      Irp,
			      FALSE,  // raw mode
			      TRUE,   // get generation
			      DestinationAddress,
			      4, // nNumberOfBytesToWrite
			      0, // nBlockSize (0 = default)
			      0, // Flags
			      0, // Generation (ignored if get generation is true),
			      (PULONG)pData);
  if(!NT_SUCCESS(ntStatus))
    TRACE(TL_ERROR,("WriteRegister: error %08x on SubmitIrpSynch\n",ntStatus));
  return ntStatus;
}

/*
 * GetConfigInfo
 *
 * queries the camera to figure out CSR offset, vendor name and model name
 */

NTSTATUS
t1394Cmdr_GetConfigInfo(
    IN PDEVICE_OBJECT   DeviceObject,
    IN PIRP             Irp
    )
{
    NTSTATUS            ntStatus = STATUS_SUCCESS;
    PDEVICE_EXTENSION   deviceExtension = DeviceObject->DeviceExtension;
    PIRB                pIrb;
    PMDL                pMdl;

    PDEVICE_OBJECT      NextDeviceObject;
    PIRP                newIrp = NULL;
    BOOLEAN             allocNewIrp = FALSE;
    KEVENT              Event;
    IO_STATUS_BLOCK     ioStatus = Irp->IoStatus;
	ULONG foo;
	PULONG ulptr;


    //
    // get the location of the next device object in the stack
    //
    NextDeviceObject = deviceExtension->StackDeviceObject;

    //
    // If this is a UserMode request create a newIrp so that the request
    // will be issued from KernelMode
    //
    if (Irp->RequestorMode == UserMode) {

        newIrp = IoBuildDeviceIoControlRequest (IOCTL_1394_CLASS, NextDeviceObject, 
                            NULL, 0, NULL, 0, TRUE, &Event, &ioStatus);

        if (!newIrp) {
            TRACE(TL_ERROR, ("Failed to allocate newIrp!\n"));
            ntStatus = STATUS_INSUFFICIENT_RESOURCES;
            goto Exit_GetStuff;            
        }
        allocNewIrp = TRUE;
    }

    pIrb = ExAllocatePool(NonPagedPool, sizeof(IRB));

    if (!pIrb) {

        TRACE(TL_ERROR, ("Failed to allocate pIrb!\n"));

        ntStatus = STATUS_INSUFFICIENT_RESOURCES;
        goto Exit_GetStuff;
    } // if

    RtlZeroMemory (pIrb, sizeof (IRB));
    
    //
    // figure out how much configuration space we need by setting lengths to zero.
    //

    pIrb->FunctionNumber = REQUEST_GET_CONFIGURATION_INFO;
    pIrb->Flags = 0;
    pIrb->u.GetConfigurationInformation.UnitDirectoryBufferSize = 0;
    pIrb->u.GetConfigurationInformation.UnitDependentDirectoryBufferSize = 0;
    pIrb->u.GetConfigurationInformation.VendorLeafBufferSize = 0;
    pIrb->u.GetConfigurationInformation.ModelLeafBufferSize = 0;

    if (allocNewIrp) 
	{
        KeInitializeEvent (&Event, NotificationEvent, FALSE);
        ntStatus = t1394_SubmitIrpAsync (NextDeviceObject, newIrp, pIrb);

        if (ntStatus == STATUS_PENDING) 
		{
            KeWaitForSingleObject (&Event, Executive, KernelMode, FALSE, NULL); 
            ntStatus = ioStatus.Status;
        }
    } else {
        ntStatus = t1394_SubmitIrpSynch(NextDeviceObject, Irp, pIrb);
    }

    if (!NT_SUCCESS(ntStatus))
        goto Exit_GetStuff;

	//
    // Now go thru and allocate what we need to so we can get our info.
    //

    deviceExtension->pConfigRom = ExAllocatePool(NonPagedPool, sizeof(CONFIG_ROM));
    if (!deviceExtension->pConfigRom) {
        ntStatus = STATUS_INSUFFICIENT_RESOURCES;
        goto Exit_GetStuff;
    }


    deviceExtension->pUnitDirectory = ExAllocatePool(NonPagedPool, pIrb->u.GetConfigurationInformation.UnitDirectoryBufferSize);
    if (!deviceExtension->pUnitDirectory) {
        ntStatus = STATUS_INSUFFICIENT_RESOURCES;
        goto Exit_GetStuff;
    }


    if (pIrb->u.GetConfigurationInformation.UnitDependentDirectoryBufferSize) {
        deviceExtension->pUnitDependentDirectory = ExAllocatePool(NonPagedPool, pIrb->u.GetConfigurationInformation.UnitDependentDirectoryBufferSize);
        if (!deviceExtension->pUnitDependentDirectory) {
            ntStatus = STATUS_INSUFFICIENT_RESOURCES;
            goto Exit_GetStuff;
        }
    }


    if (pIrb->u.GetConfigurationInformation.VendorLeafBufferSize) {
        // From NonPaged pool since vendor name can be used in a func with DISPATCH level
        deviceExtension->pVendorLeaf = ExAllocatePool(NonPagedPool, pIrb->u.GetConfigurationInformation.VendorLeafBufferSize);
        if (!deviceExtension->pVendorLeaf) {
            ntStatus = STATUS_INSUFFICIENT_RESOURCES;
            goto Exit_GetStuff;
        }
    }

    if (pIrb->u.GetConfigurationInformation.ModelLeafBufferSize) {
        deviceExtension->pModelLeaf = ExAllocatePool(NonPagedPool, pIrb->u.GetConfigurationInformation.ModelLeafBufferSize);
        if (!deviceExtension->pModelLeaf) {
            ntStatus = STATUS_INSUFFICIENT_RESOURCES;
            goto Exit_GetStuff;
        }
    }

    //
    // Now resubmit the pIrb with the appropriate pointers inside
    //

	allocNewIrp = FALSE;
	newIrp = NULL;

    if (Irp->RequestorMode == UserMode) {

        newIrp = IoBuildDeviceIoControlRequest (IOCTL_1394_CLASS, NextDeviceObject, 
                            NULL, 0, NULL, 0, TRUE, &Event, &ioStatus);

        if (!newIrp) {
            TRACE(TL_ERROR, ("Failed to allocate newIrp!\n"));
            ntStatus = STATUS_INSUFFICIENT_RESOURCES;
            goto Exit_GetStuff;            
        }
        allocNewIrp = TRUE;
    }

    pIrb->FunctionNumber = REQUEST_GET_CONFIGURATION_INFO;
    pIrb->Flags = 0;
    pIrb->u.GetConfigurationInformation.ConfigRom = deviceExtension->pConfigRom;
    pIrb->u.GetConfigurationInformation.UnitDirectory = deviceExtension->pUnitDirectory;
    pIrb->u.GetConfigurationInformation.UnitDependentDirectory = deviceExtension->pUnitDependentDirectory;
    pIrb->u.GetConfigurationInformation.VendorLeaf = deviceExtension->pVendorLeaf;
    pIrb->u.GetConfigurationInformation.ModelLeaf = deviceExtension->pModelLeaf;

    if (allocNewIrp) 
	{
        KeInitializeEvent (&Event, NotificationEvent, FALSE);
        ntStatus = t1394_SubmitIrpAsync (NextDeviceObject, newIrp, pIrb);

        if (ntStatus == STATUS_PENDING) 
		{
            KeWaitForSingleObject (&Event, Executive, KernelMode, FALSE, NULL); 
            ntStatus = ioStatus.Status;
        }
    } else {
        ntStatus = t1394_SubmitIrpSynch(NextDeviceObject, Irp, pIrb);
    }

    if (!NT_SUCCESS(ntStatus))
        goto Exit_GetStuff;

	// now move all the important info into the device extension

	if(deviceExtension->pVendorLeaf && deviceExtension->pVendorLeaf->TL_Length >= 1)
		deviceExtension->VendorNameLength = (USHORT) strlen(&(deviceExtension->pVendorLeaf->TL_Data));

	if(deviceExtension->pModelLeaf && deviceExtension->pModelLeaf->TL_Length >= 1)
		deviceExtension->ModelNameLength = (USHORT) strlen(&(deviceExtension->pModelLeaf->TL_Data));

	if(pIrb->u.GetConfigurationInformation.UnitDirectoryBufferSize < 16)
	{
		DbgPrint("GetConfigInfo: UnitDirectory size (%d) isn't correct, should be >= 16\n",
				pIrb->u.GetConfigurationInformation.UnitDirectoryBufferSize);
		ntStatus = STATUS_UNSUCCESSFUL;
		goto Exit_GetStuff;
	}

	if(pIrb->u.GetConfigurationInformation.UnitDependentDirectoryBufferSize < 16)
	{
		DbgPrint("GetConfigInfo: UnitDependentDirectory size (%d) isn't correct, should be >= 16\n",
				pIrb->u.GetConfigurationInformation.UnitDependentDirectoryBufferSize);
		ntStatus = STATUS_UNSUCCESSFUL;
		goto Exit_GetStuff;
	}

	ulptr = (PULONG) (deviceExtension->pUnitDirectory);
	foo = bswap(ulptr[1]) & 0x00ffffff;
	deviceExtension->unit_spec_ID = foo;

	foo = bswap(ulptr[2]) & 0x00ffffff;
	deviceExtension->unit_sw_version = foo;

	ulptr = (PULONG) (deviceExtension->pUnitDependentDirectory);
	foo = 0xf0000000 + 4 * (bswap(ulptr[1]) & 0x00ffffff);
	deviceExtension->CSR_offset = foo;

    return STATUS_SUCCESS;

///////////////////
// Exit_GetStuff //
///////////////////

Exit_GetStuff:

    if (allocNewIrp) 
        Irp->IoStatus = ioStatus;

	if(pIrb)
		ExFreePool(pIrb);

	if(!NT_SUCCESS(ntStatus))
	{
		// clean up our mess
		if(deviceExtension->pConfigRom) {
			ExFreePool(deviceExtension->pConfigRom);
			deviceExtension->pConfigRom = NULL;
		}

		if(deviceExtension->pUnitDirectory) {
			ExFreePool(deviceExtension->pUnitDirectory);
			deviceExtension->pUnitDirectory = NULL;
		}

		if(deviceExtension->pUnitDependentDirectory) {
			ExFreePool(deviceExtension->pUnitDependentDirectory);
			deviceExtension->pUnitDependentDirectory = NULL;
		}

		if(deviceExtension->pVendorLeaf) {
			ExFreePool(deviceExtension->pVendorLeaf);
			deviceExtension->pVendorLeaf = NULL;
		}

		if(deviceExtension->pModelLeaf) {
			ExFreePool(deviceExtension->pModelLeaf);
			deviceExtension->pModelLeaf = NULL;
		}
	}

    return ntStatus;
}


NTSTATUS
t1394Cmdr_Cleanup(
    IN PDEVICE_OBJECT   DeviceObject,
    IN PIRP             Irp
    )
{
    NTSTATUS    ntStatus = STATUS_SUCCESS;
	PDEVICE_EXTENSION deviceExtension = DeviceObject->DeviceExtension;
	PIO_STACK_LOCATION pISO = IoGetCurrentIrpStackLocation(Irp);

    ENTER("t1394CMDR_Cleanup");
	if(deviceExtension->bListening && pISO && deviceExtension->pfoListenObject == pISO->FileObject)
	{
		TRACE(TL_TRACE,("t1394CMDR_Cleanup on matching FileObject (%p) While Listening!!!\n",pISO->FileObject));
		// this is where we would clean up
		//deviceExtension->bListening = 0;
		//deviceExtension->pfoListenObject = NULL;
	}
    Irp->IoStatus.Status = STATUS_SUCCESS;
    IoCompleteRequest(Irp, IO_NO_INCREMENT);

    EXIT("t1394CMDR_Cleanup", ntStatus);
    return(ntStatus);
} // t1394Cmdr_Close
