/*++

Copyright (c) 1998	Microsoft Corporation

Module Name: 

		ioctl.c

Abstract


Author:

		Peter Binder (pbinder) 4/13/98

Revision History:
Date		 Who			 What
-------- --------- ------------------------------------------------------------
4/13/98  pbinder	 taken from 1394diag/ohcidiag
--*/

#include "pch.h"

NTSTATUS
t1394Cmdr_IoControl(
		IN PDEVICE_OBJECT 	DeviceObject,
		IN PIRP 						Irp
		)
{
	NTSTATUS								ntStatus = STATUS_SUCCESS;
	PIO_STACK_LOCATION			IrpSp;
	PDEVICE_EXTENSION 			deviceExtension;
	PVOID 									ioBuffer;
	ULONG 									inputBufferLength;
	ULONG 									outputBufferLength;
	ULONG 									ioControlCode;
		
	ENTER("t1394Cmdr_IoControl");

	// Get a pointer to the current location in the Irp. This is where
	// the function codes and parameters are located.
	IrpSp = IoGetCurrentIrpStackLocation(Irp);

	// Get a pointer to the device extension
	deviceExtension = DeviceObject->DeviceExtension;

	// Get the pointer to the input/output buffer and it's length
	ioBuffer					 = Irp->AssociatedIrp.SystemBuffer;
	inputBufferLength  = IrpSp->Parameters.DeviceIoControl.InputBufferLength;
	outputBufferLength = IrpSp->Parameters.DeviceIoControl.OutputBufferLength;

	// make sure our device isn't in shutdown mode...
	if (deviceExtension->bShutdown) {

		Irp->IoStatus.Status = STATUS_NO_SUCH_DEVICE;
		IoCompleteRequest(Irp, IO_NO_INCREMENT);
		ntStatus = STATUS_NO_SUCH_DEVICE;
		return(ntStatus);
	}

	TRACE(TL_TRACE, ("Irp = %p\n", Irp));
	switch (IrpSp->MajorFunction) 
  {
#define IOCTL_CASE_PRINT(code) case code: TRACE(TL_TRACE,(#code));

		case IRP_MJ_DEVICE_CONTROL:
	TRACE(TL_TRACE, ("t1394Cmdr_IoControl: IRP_MJ_DEVICE_CONTROL\n"));

	ioControlCode = IrpSp->Parameters.DeviceIoControl.IoControlCode;

	switch (ioControlCode) {
		/*
			case IOCTL_ALLOCATE_ADDRESS_RANGE:
			{
			PALLOCATE_ADDRESS_RANGE 		AllocateAddressRange;

			TRACE(TL_TRACE, ("IOCTL_ALLOCATE_ADDRESS_RANGE\n"));

			if ((inputBufferLength < sizeof(ALLOCATE_ADDRESS_RANGE)) ||
			(outputBufferLength < sizeof(ALLOCATE_ADDRESS_RANGE))) {

			ntStatus = STATUS_BUFFER_TOO_SMALL;
			}
			else {

			AllocateAddressRange = (PALLOCATE_ADDRESS_RANGE)ioBuffer;

			ntStatus = t1394_AllocateAddressRange( DeviceObject,
			Irp,
			AllocateAddressRange->fulAllocateFlags,
			AllocateAddressRange->fulFlags,
			AllocateAddressRange->nLength,
			AllocateAddressRange->MaxSegmentSize,
			AllocateAddressRange->fulAccessType,
			AllocateAddressRange->fulNotificationOptions,
			&AllocateAddressRange->Required1394Offset,
			&AllocateAddressRange->hAddressRange,
			(PULONG)&AllocateAddressRange->Data
			);

			if (NT_SUCCESS(ntStatus))
			Irp->IoStatus.Information = outputBufferLength;
			}
			}
			break; // IOCTL_ALLOCATE_ADDRESS_RANGE

			case IOCTL_FREE_ADDRESS_RANGE:
			TRACE(TL_TRACE, ("IOCTL_FREE_ADDRESS_RANGE\n"));

			if (inputBufferLength < sizeof(HANDLE)) {

			ntStatus = STATUS_BUFFER_TOO_SMALL;
			}
			else {

			ntStatus = t1394_FreeAddressRange( DeviceObject,
			Irp,
			*(PHANDLE)ioBuffer
			);
			}
			break; // IOCTL_FREE_ADDRESS_RANGE

			case IOCTL_ASYNC_READ:
			{
			PASYNC_READ 		AsyncRead;

			TRACE(TL_TRACE, ("IOCTL_ASYNC_READ\n"));

			if (inputBufferLength < sizeof(ASYNC_READ)) {

			ntStatus = STATUS_BUFFER_TOO_SMALL;
			}
			else {

			AsyncRead = (PASYNC_READ)ioBuffer;

			if ((outputBufferLength < sizeof(ASYNC_READ)) || 
			(outputBufferLength-sizeof(ASYNC_READ) < AsyncRead->nNumberOfBytesToRead)) {

			ntStatus = STATUS_BUFFER_TOO_SMALL;
			}
			else {

			ntStatus = t1394_AsyncRead( DeviceObject,
			Irp,
			AsyncRead->bRawMode,
			AsyncRead->bGetGeneration,
			AsyncRead->DestinationAddress,
			AsyncRead->nNumberOfBytesToRead,
			AsyncRead->nBlockSize,
			AsyncRead->fulFlags,
			AsyncRead->ulGeneration,
			(PULONG)&AsyncRead->Data
			);

			if (NT_SUCCESS(ntStatus))
			Irp->IoStatus.Information = outputBufferLength;
			}
			}
			}
			break; // IOCTL_ASYNC_READ

			case IOCTL_ASYNC_WRITE:
			{
			PASYNC_WRITE		AsyncWrite;

			TRACE(TL_TRACE, ("IOCTL_ASYNC_WRITE\n"));

			if (inputBufferLength < sizeof(ASYNC_WRITE)) {

			ntStatus = STATUS_BUFFER_TOO_SMALL;
			}
			else {

			AsyncWrite = (PASYNC_WRITE)ioBuffer;

			if (inputBufferLength-sizeof(ASYNC_WRITE) < AsyncWrite->nNumberOfBytesToWrite) {

			ntStatus = STATUS_BUFFER_TOO_SMALL;
			}
			else {

			ntStatus = t1394_AsyncWrite( DeviceObject,
			Irp,
			AsyncWrite->bRawMode,
			AsyncWrite->bGetGeneration,
			AsyncWrite->DestinationAddress,
			AsyncWrite->nNumberOfBytesToWrite,
			AsyncWrite->nBlockSize,
			AsyncWrite->fulFlags,
			AsyncWrite->ulGeneration,
			(PULONG)&AsyncWrite->Data
			);
			}
			}
			}
			break; // IOCTL_ASYNC_WRITE

			case IOCTL_ASYNC_LOCK:
			{
			PASYNC_LOCK 		AsyncLock;

			TRACE(TL_TRACE, ("IOCTL_ASYNC_LOCK\n"));

			if ((inputBufferLength < sizeof(ASYNC_LOCK)) ||
			(outputBufferLength < sizeof(ASYNC_LOCK))) {

			ntStatus = STATUS_BUFFER_TOO_SMALL;
			}
			else {

			AsyncLock = (PASYNC_LOCK)ioBuffer;

			ntStatus = t1394_AsyncLock( DeviceObject,
			Irp,
			AsyncLock->bRawMode,
			AsyncLock->bGetGeneration,
			AsyncLock->DestinationAddress,
			AsyncLock->nNumberOfArgBytes,
			AsyncLock->nNumberOfDataBytes,
			AsyncLock->fulTransactionType,
			AsyncLock->fulFlags,
			AsyncLock->Arguments,
			AsyncLock->DataValues,
			AsyncLock->ulGeneration,
			(PVOID)&AsyncLock->Buffer
			);

			if (NT_SUCCESS(ntStatus))
			Irp->IoStatus.Information = outputBufferLength;
			}
			}
			break; // IOCTL_ASYNC_LOCK

			case IOCTL_ASYNC_STREAM:
			{
			PASYNC_STREAM 	AsyncStream;

			TRACE(TL_TRACE, ("IOCTL_ASYNC_STREAM\n"));

			if (inputBufferLength < sizeof(ASYNC_STREAM)) {

			ntStatus = STATUS_BUFFER_TOO_SMALL;
			}
			else {

			AsyncStream = (PASYNC_STREAM)ioBuffer;

			if (outputBufferLength < sizeof(ASYNC_STREAM)+AsyncStream->nNumberOfBytesToStream) {

			ntStatus = STATUS_BUFFER_TOO_SMALL;
			}
			else {

			ntStatus = t1394_AsyncStream( DeviceObject,
			Irp,
			AsyncStream->nNumberOfBytesToStream,
			AsyncStream->fulFlags,
			AsyncStream->ulTag,
			AsyncStream->nChannel,
			AsyncStream->ulSynch,
			(UCHAR)AsyncStream->nSpeed,
			(PULONG)&AsyncStream->Data
			);

			if (NT_SUCCESS(ntStatus))
			Irp->IoStatus.Information = outputBufferLength;
			}
			}
			}
			break; // IOCTL_ASYNC_STREAM
		*/
/* deprecated RESOURCE IOCTLS
	case IOCTL_ISOCH_ALLOCATE_BANDWIDTH:
		{
			PISOCH_ALLOCATE_BANDWIDTH 	IsochAllocateBandwidth;

			TRACE(TL_TRACE, ("IOCTL_ISOCH_ALLOCATE_BANDWIDTH\n"));

			if ((inputBufferLength < sizeof(ISOCH_ALLOCATE_BANDWIDTH)) ||
		(outputBufferLength < sizeof(ISOCH_ALLOCATE_BANDWIDTH))) {

	ntStatus = STATUS_BUFFER_TOO_SMALL;
			}
			else {

	IsochAllocateBandwidth = (PISOCH_ALLOCATE_BANDWIDTH)ioBuffer;

	ntStatus = t1394_IsochAllocateBandwidth( DeviceObject,
						 Irp,
						 IsochAllocateBandwidth->nMaxBytesPerFrameRequested,
						 IsochAllocateBandwidth->fulSpeed,
						 &IsochAllocateBandwidth->hBandwidth,
						 &IsochAllocateBandwidth->BytesPerFrameAvailable,
						 &IsochAllocateBandwidth->SpeedSelected
						 );

	if (NT_SUCCESS(ntStatus))
		Irp->IoStatus.Information = outputBufferLength;
			}
		}
		break; // IOCTL_ISOCH_ALLOCATE_BANDWIDTH

	case IOCTL_ISOCH_ALLOCATE_CHANNEL:
		{
			PISOCH_ALLOCATE_CHANNEL 		IsochAllocateChannel;

			TRACE(TL_TRACE, ("IOCTL_ISOCH_ALLOCATE_CHANNEL\n"));

			if ((inputBufferLength < sizeof(ISOCH_ALLOCATE_CHANNEL)) ||
		(outputBufferLength < sizeof(ISOCH_ALLOCATE_CHANNEL))) {

	ntStatus = STATUS_BUFFER_TOO_SMALL;
			}
			else {

	IsochAllocateChannel = (PISOCH_ALLOCATE_CHANNEL)ioBuffer;

	ntStatus = t1394_IsochAllocateChannel( DeviceObject,
								 Irp,
								 IsochAllocateChannel->nRequestedChannel,
								 &IsochAllocateChannel->Channel,
								 &IsochAllocateChannel->ChannelsAvailable
								 );

	if (NT_SUCCESS(ntStatus))
		Irp->IoStatus.Information = outputBufferLength;
			}
		}
		break; // IOCTL_ISOCH_ALLOCATE_CHANNEL

	case IOCTL_ISOCH_ALLOCATE_RESOURCES:
		{
			PISOCH_ALLOCATE_RESOURCES 	IsochAllocateResources;

			TRACE(TL_TRACE, ("IOCTL_ISOCH_ALLOCATE_RESOURCES\n"));

			if ((inputBufferLength < sizeof(ISOCH_ALLOCATE_RESOURCES)) ||
		(outputBufferLength < sizeof(ISOCH_ALLOCATE_RESOURCES))) {

	ntStatus = STATUS_BUFFER_TOO_SMALL;
			}
			else {

	IsochAllocateResources = (PISOCH_ALLOCATE_RESOURCES)ioBuffer;

	ntStatus = t1394_IsochAllocateResources( DeviceObject,
						 Irp,
						 IsochAllocateResources->fulSpeed,
						 IsochAllocateResources->fulFlags,
						 IsochAllocateResources->nChannel,
						 IsochAllocateResources->nMaxBytesPerFrame,
						 IsochAllocateResources->nNumberOfBuffers,
						 IsochAllocateResources->nMaxBufferSize,
						 IsochAllocateResources->nQuadletsToStrip,
						 &IsochAllocateResources->hResource
						 );

	if (NT_SUCCESS(ntStatus))
		Irp->IoStatus.Information = outputBufferLength;
			}
		}
		break; // IOCTL_ISOCH_ALLOCATE_RESOURCES

  case IOCTL_ISOCH_ATTACH_BUFFERS:
	case IOCTL_ISOCH_DETACH_BUFFERS:
    TRACE(TL_ERROR,("Old-Style [Attach,Detach]Buffers is Deprecated, use IOCTL_ATTACH_BUFFER\n"));
    ntStatus = STATUS_NOT_IMPLEMENTED;
    break;
	case IOCTL_ISOCH_FREE_BANDWIDTH:
		{
			TRACE(TL_TRACE, ("IOCTL_ISOCH_FREE_BANDWIDTH\n"));

			if (inputBufferLength < sizeof(HANDLE)) {

	ntStatus = STATUS_BUFFER_TOO_SMALL;
			}
			else {

	ntStatus = t1394_IsochFreeBandwidth( DeviceObject,
							 Irp,
							 *(PHANDLE)ioBuffer
							 );
			}
		}
		break; // IOCTL_ISOCH_FREE_BANDWIDTH
	
	case IOCTL_ISOCH_FREE_CHANNEL:
		{
			TRACE(TL_TRACE, ("IOCTL_ISOCH_FREE_CHANNEL\n"));

			if (inputBufferLength < sizeof(ULONG)) {

	ntStatus = STATUS_BUFFER_TOO_SMALL;
			}
			else {

	ntStatus = t1394_IsochFreeChannel( DeviceObject,
						 Irp,
						 *(PULONG)ioBuffer
						 );
			}
		}
		break; // IOCTL_ISOCH_FREE_CHANNEL
	
	case IOCTL_ISOCH_FREE_RESOURCES:
		{
			TRACE(TL_TRACE, ("IOCTL_ISOCH_FREE_RESOURCES\n"));

			if (inputBufferLength < sizeof(HANDLE)) {

	ntStatus = STATUS_BUFFER_TOO_SMALL;
			}
			else {

	ntStatus = t1394_IsochFreeResources( DeviceObject,
							 Irp,
							 *(PHANDLE)ioBuffer
							 );
			}
		}
		break; // IOCTL_ISOCH_FREE_RESOURCES
  */
	case IOCTL_ISOCH_LISTEN:
	{
    TRACE(TL_TRACE, ("IOCTL_ISOCH_LISTEN\n"));
    ntStatus = t1394_IsochListen( DeviceObject,Irp);
	}
	break; // IOCTL_ISOCH_LISTEN

	case IOCTL_ISOCH_QUERY_CURRENT_CYCLE_TIME:
		{
			TRACE(TL_TRACE, ("IOCTL_ISOCH_QUERY_CURRENT_CYCLE_TIME\n"));

			if (outputBufferLength < sizeof(CYCLE_TIME)) {

	ntStatus = STATUS_BUFFER_TOO_SMALL;
			}
			else {

	ntStatus = t1394_IsochQueryCurrentCycleTime( DeviceObject,
								 Irp,
								 (PCYCLE_TIME)ioBuffer
								 );

	if (NT_SUCCESS(ntStatus))
		Irp->IoStatus.Information = outputBufferLength;
			}
		}
		break; // IOCTL_ISOCH_QUERY_CURRENT_CYCLE_TIME

	case IOCTL_ISOCH_QUERY_RESOURCES:
		{
			PISOCH_QUERY_RESOURCES			IsochQueryResources;

			TRACE(TL_TRACE, ("IOCTL_ISOCH_QUERY_RESOURCES\n"));

			if ((inputBufferLength < sizeof(ISOCH_QUERY_RESOURCES)) ||
		(outputBufferLength < sizeof(ISOCH_QUERY_RESOURCES))) {

	ntStatus = STATUS_BUFFER_TOO_SMALL;
			}
			else {

	IsochQueryResources = (PISOCH_QUERY_RESOURCES)ioBuffer;

	ntStatus = t1394_IsochQueryResources( DeviceObject,
								Irp,
								IsochQueryResources->fulSpeed,
								&IsochQueryResources->BytesPerFrameAvailable,
								&IsochQueryResources->ChannelsAvailable
								);

	if (NT_SUCCESS(ntStatus))
		Irp->IoStatus.Information = outputBufferLength;
			}
		}
		break; // IOCTL_ISOCH_QUERY_RESOURCES
/*
	case IOCTL_ISOCH_SET_CHANNEL_BANDWIDTH:
		{
			PISOCH_SET_CHANNEL_BANDWIDTH		IsochSetChannelBandwidth;

			TRACE(TL_TRACE, ("IOCTL_ISOCH_SET_CHANNEL_BANDWIDTH\n"));

			if (inputBufferLength < sizeof(ISOCH_SET_CHANNEL_BANDWIDTH)) {

	ntStatus = STATUS_BUFFER_TOO_SMALL;
			}
			else {

	IsochSetChannelBandwidth = (PISOCH_SET_CHANNEL_BANDWIDTH)ioBuffer;

	ntStatus = t1394_IsochSetChannelBandwidth( DeviceObject,
							 Irp,
							 IsochSetChannelBandwidth->hBandwidth,
							 IsochSetChannelBandwidth->nMaxBytesPerFrame
							 );
			}
		}
		break; // IOCTL_ISOCH_SET_CHANNEL_BANDWIDTH

	case IOCTL_ISOCH_MODIFY_STREAM_PROPERTIES:
		{
			PISOCH_MODIFY_STREAM_PROPERTIES 		IsochModifyStreamProperties;

			TRACE(TL_TRACE, ("IOCTL_ISOCH_MODIFY_STREAM_PROPERTIES\n"));

			if (inputBufferLength < sizeof (ISOCH_MODIFY_STREAM_PROPERTIES)) {

	ntStatus = STATUS_BUFFER_TOO_SMALL;
			}
			else {

	IsochModifyStreamProperties = (PISOCH_MODIFY_STREAM_PROPERTIES)ioBuffer;

	ntStatus = t1394_IsochModifyStreamProperties( DeviceObject,
									Irp, 
									IsochModifyStreamProperties->hResource,
									IsochModifyStreamProperties->ChannelMask,
									IsochModifyStreamProperties->fulSpeed
									);
			}
		}
		break; // IOCTL_ISOCH_MODIFY_STREAM_PROPERTIES
*/
	case IOCTL_ISOCH_STOP:
	  ntStatus = t1394_IsochStop(DeviceObject,Irp);
		break; // IOCTL_ISOCH_STOP
/*
	case IOCTL_ISOCH_TALK:
		{
			PISOCH_TALK 		IsochTalk;

			TRACE(TL_TRACE, ("IOCTL_ISOCH_TALK\n"));

			if (inputBufferLength < sizeof(ISOCH_TALK)) {

	ntStatus = STATUS_BUFFER_TOO_SMALL;
			}
			else {

	IsochTalk = (PISOCH_TALK)ioBuffer;

	ntStatus = t1394_IsochTalk( DeviceObject,
						Irp,
						IsochTalk->hResource,
						IsochTalk->fulFlags,
						IsochTalk->StartTime
						);
			}
		}
		break; // IOCTL_ISOCH_TALK
*/
	case IOCTL_GET_LOCAL_HOST_INFORMATION:
		{
			PGET_LOCAL_HOST_INFORMATION 		GetLocalHostInformation;

			TRACE(TL_TRACE, ("IOCTL_GET_LOCAL_HOST_INFORMATION\n"));

			if ((inputBufferLength < sizeof(GET_LOCAL_HOST_INFORMATION)) ||
		(outputBufferLength < sizeof(GET_LOCAL_HOST_INFORMATION))) {

	ntStatus = STATUS_BUFFER_TOO_SMALL;
			}
			else {

	GetLocalHostInformation = (PGET_LOCAL_HOST_INFORMATION)ioBuffer;

	ntStatus = t1394_GetLocalHostInformation( DeviceObject,
							Irp,
							GetLocalHostInformation->nLevel,
							&GetLocalHostInformation->Status,
							(PVOID)GetLocalHostInformation->Information
							);

	if (NT_SUCCESS(ntStatus))
		Irp->IoStatus.Information = outputBufferLength;
			}
		}
		break; // IOCTL_GET_LOCAL_HOST_INFORMATION
/*
	case IOCTL_GET_1394_ADDRESS_FROM_DEVICE_OBJECT:
		{
			PGET_1394_ADDRESS 	Get1394Address;

			TRACE(TL_TRACE, ("IOCTL_GET_1394_ADDRESS_FROM_DEVICE_OBJECT\n"));

			if ((inputBufferLength < sizeof(GET_1394_ADDRESS)) ||
		(outputBufferLength < sizeof(GET_1394_ADDRESS))) {

	ntStatus = STATUS_BUFFER_TOO_SMALL;
			}
			else {

	Get1394Address = (PGET_1394_ADDRESS)ioBuffer;

	ntStatus = t1394_Get1394AddressFromDeviceObject( DeviceObject,
							 Irp,
							 Get1394Address->fulFlags,
							 &Get1394Address->NodeAddress
							 );

	if (NT_SUCCESS(ntStatus))
		Irp->IoStatus.Information = outputBufferLength;
			}
		}
		break; // IOCTL_GET_1394_ADDRESS_FROM_DEVICE_OBJECT

	case IOCTL_CONTROL:
		TRACE(TL_TRACE, ("IOCTL_CONTROL\n"));

		ntStatus = t1394_Control( DeviceObject,
						Irp
						);

		break; // IOCTL_CONTROL

	case IOCTL_GET_MAX_SPEED_BETWEEN_DEVICES:
		{
			PGET_MAX_SPEED_BETWEEN_DEVICES	MaxSpeedBetweenDevices;

			TRACE(TL_TRACE, ("IOCTL_GET_MAX_SPEED_BETWEEN_DEVICES\n"));

			if ((inputBufferLength < sizeof(GET_MAX_SPEED_BETWEEN_DEVICES)) ||
		(outputBufferLength < sizeof(GET_MAX_SPEED_BETWEEN_DEVICES))) {

	ntStatus = STATUS_BUFFER_TOO_SMALL;
			}
			else {

	MaxSpeedBetweenDevices = (PGET_MAX_SPEED_BETWEEN_DEVICES)ioBuffer;

	ntStatus = t1394_GetMaxSpeedBetweenDevices( DeviceObject,
								Irp,
								MaxSpeedBetweenDevices->fulFlags,
								MaxSpeedBetweenDevices->ulNumberOfDestinations,
								(PDEVICE_OBJECT *)&MaxSpeedBetweenDevices->hDestinationDeviceObjects[0],
								&MaxSpeedBetweenDevices->fulSpeed
								);

	if (NT_SUCCESS(ntStatus))
		Irp->IoStatus.Information = outputBufferLength;
			}
		} 									 
		break; // IOCTL_GET_MAX_SPEED_BETWEEN_DEVICES

	case IOCTL_SET_DEVICE_XMIT_PROPERTIES:
		{
			PDEVICE_XMIT_PROPERTIES 		DeviceXmitProperties;

			TRACE(TL_TRACE, ("IOCTL_SET_DEVICE_XMIT_PROPERTIES\n"));

			if (inputBufferLength < sizeof(DEVICE_XMIT_PROPERTIES)) {

	ntStatus = STATUS_BUFFER_TOO_SMALL;
			}
			else {

	DeviceXmitProperties = (PDEVICE_XMIT_PROPERTIES)ioBuffer;

	ntStatus = t1394_SetDeviceXmitProperties( DeviceObject,
							Irp,
							DeviceXmitProperties->fulSpeed,
							DeviceXmitProperties->fulPriority
							);
			}
		}
		break; // IOCTL_SET_DEVICE_XMIT_PROPERTIES
*/
	case IOCTL_GET_CONFIGURATION_INFORMATION:
		TRACE(TL_TRACE, ("IOCTL_GET_CONFIGURATION_INFORMATION\n"));

		ntStatus = t1394_GetConfigurationInformation( DeviceObject,
							Irp
							);

		break; // IOCTL_GET_CONFIGURATION_INFORMATION

	case IOCTL_BUS_RESET:
		{
			TRACE(TL_TRACE, ("IOCTL_BUS_RESET\n"));

			if (inputBufferLength < sizeof(ULONG)) {

	ntStatus = STATUS_BUFFER_TOO_SMALL;
			}
			else {

	ntStatus = t1394_BusReset( DeviceObject,
					 Irp,
					 *((PULONG)ioBuffer)
					 );
			}
		}
		break; // IOCTL_BUS_RESET

	case IOCTL_GET_GENERATION_COUNT:
		{
			TRACE(TL_TRACE, ("IOCTL_GET_GENERATION_COUNT\n"));

			if (outputBufferLength < sizeof(ULONG)) {

	ntStatus = STATUS_BUFFER_TOO_SMALL;
			}
			else {

	ntStatus = t1394_GetGenerationCount( DeviceObject,
							 Irp,
							 (PULONG)ioBuffer
							 );

	if (NT_SUCCESS(ntStatus))
		Irp->IoStatus.Information = outputBufferLength;
			}
		}
		break; // IOCTL_GET_GENERATION_COUNT

	case IOCTL_SEND_PHY_CONFIGURATION_PACKET:
		{
			TRACE(TL_TRACE, ("IOCTL_SEND_PHY_CONFIGURATION_PACKET\n"));

			if (inputBufferLength < sizeof(PHY_CONFIGURATION_PACKET)) {

	ntStatus = STATUS_BUFFER_TOO_SMALL;
			}
			else {

	ntStatus = t1394_SendPhyConfigurationPacket( DeviceObject,
								 Irp,
								 *(PPHY_CONFIGURATION_PACKET)ioBuffer
								 );
			}
		}
		break; // IOCTL_SEND_PHY_CONFIGURATION_PACKET

	case IOCTL_BUS_RESET_NOTIFICATION:
		{
			TRACE(TL_TRACE, ("IOCTL_BUS_RESET_NOTIFICATION\n"));

			if (inputBufferLength < sizeof(ULONG)) {

	ntStatus = STATUS_BUFFER_TOO_SMALL;
			}
			else {

	ntStatus = t1394_BusResetNotification( DeviceObject,
								 Irp,
								 *((PULONG)ioBuffer)
								 );
			}
		}
		break; // IOCTL_BUS_RESET_NOTIFICATION
/*
	case IOCTL_SET_LOCAL_HOST_INFORMATION:
		{
			PSET_LOCAL_HOST_INFORMATION 		SetLocalHostInformation;

			TRACE(TL_TRACE, ("IOCTL_SET_LOCAL_HOST_INFORMATION\n"));

			if (inputBufferLength < sizeof(SET_LOCAL_HOST_INFORMATION)) {

	ntStatus = STATUS_BUFFER_TOO_SMALL;
			}
			else {

	SetLocalHostInformation = (PSET_LOCAL_HOST_INFORMATION)ioBuffer;

	if (inputBufferLength < (sizeof(SET_LOCAL_HOST_INFORMATION) +
				 SetLocalHostInformation->ulBufferSize)) {

		ntStatus = STATUS_BUFFER_TOO_SMALL;
	}
	else {

		ntStatus = t1394_SetLocalHostProperties( DeviceObject,
							 Irp,
							 SetLocalHostInformation->nLevel,
							 (PVOID)&SetLocalHostInformation->Information
							 );

		if (NT_SUCCESS(ntStatus))
			Irp->IoStatus.Information = outputBufferLength;
	}
			}
		}
		break; // IOCTL_SET_LOCAL_HOST_INFORMATION
		*/
		/*
			case IOCTL_SET_ADDRESS_DATA:
			{
			PSET_ADDRESS_DATA 	SetAddressData;

			TRACE(TL_TRACE, ("IOCTL_SET_ADDRESS_DATA\n"));

			if (inputBufferLength < sizeof(SET_ADDRESS_DATA)) {

			ntStatus = STATUS_BUFFER_TOO_SMALL;
			}
			else {

			SetAddressData = (PSET_ADDRESS_DATA)ioBuffer;

			if (inputBufferLength < (sizeof(SET_ADDRESS_DATA)+SetAddressData->nLength)) {

			ntStatus = STATUS_BUFFER_TOO_SMALL;
			}
			else {

			ntStatus = t1394_SetAddressData( DeviceObject,
			Irp,
			SetAddressData->hAddressRange,
			SetAddressData->nLength,
			SetAddressData->ulOffset,
			(PVOID)&SetAddressData->Data
			);
			}
			}
			}
			break; // IOCTL_SET_ADDRESS_DATA

			case IOCTL_GET_ADDRESS_DATA:
			{
			PGET_ADDRESS_DATA 	GetAddressData;

			TRACE(TL_TRACE, ("IOCTL_GET_ADDRESS_DATA\n"));

			if (inputBufferLength < sizeof(GET_ADDRESS_DATA)) {

			ntStatus = STATUS_BUFFER_TOO_SMALL;
			}
			else {

			GetAddressData = (PGET_ADDRESS_DATA)ioBuffer;

			if (inputBufferLength < (sizeof(GET_ADDRESS_DATA)+GetAddressData->nLength)) {

			ntStatus = STATUS_BUFFER_TOO_SMALL;
			}
			else {

			ntStatus = t1394_GetAddressData( DeviceObject,
			Irp,
			GetAddressData->hAddressRange,
			GetAddressData->nLength,
			GetAddressData->ulOffset,
			(PVOID)&GetAddressData->Data
			);
																
			if (NT_SUCCESS(ntStatus))
			Irp->IoStatus.Information = outputBufferLength;
			}
			}
			}
			break; // IOCTL_GET_ADDRESS_DATA
		*/
	case IOCTL_BUS_RESET_NOTIFY: {

		PBUS_RESET_IRP	BusResetIrp;
		KIRQL 					Irql;
										
		TRACE(TL_TRACE, ("IOCTL_BUS_RESET_NOTIFY\n"));

		BusResetIrp = ExAllocatePool(NonPagedPool, sizeof(BUS_RESET_IRP));

		if (BusResetIrp) {

			// mark it pending
			IoMarkIrpPending(Irp);
			ntStatus = Irp->IoStatus.Status = STATUS_PENDING;
			BusResetIrp->Irp = Irp;

			TRACE(TL_TRACE, ("Adding BusResetIrp->Irp = %p\n", BusResetIrp->Irp));

			// add the irp to the list...
			KeAcquireSpinLock(&deviceExtension->ResetSpinLock, &Irql);

			InsertHeadList(&deviceExtension->BusResetIrps, &BusResetIrp->BusResetIrpList);

			// set the cancel routine for the irp
			IoSetCancelRoutine(Irp, t1394Cmdr_CancelIrp);

			if (Irp->Cancel && IoSetCancelRoutine(Irp, t1394Cmdr_CancelIrp)) {

	RemoveEntryList(&BusResetIrp->BusResetIrpList);
	ntStatus = STATUS_CANCELLED;
			}

			KeReleaseSpinLock(&deviceExtension->ResetSpinLock, Irql);

			// goto _exit on success so we don't complete the irp
			if (ntStatus == STATUS_PENDING)
	goto _exit;
		}
		else
			ntStatus = STATUS_INSUFFICIENT_RESOURCES;
	}
		break; // IOCTL_BUS_RESET_NOTIFY

	case IOCTL_GET_CMDR_VERSION:
		{
			PVERSION_DATA 	Version;

			TRACE(TL_TRACE, ("IOCTL_GET_DIAG_VERSION\n"));

			if ((inputBufferLength < sizeof(VERSION_DATA)) &&
		(outputBufferLength < sizeof(VERSION_DATA))) {

	ntStatus = STATUS_BUFFER_TOO_SMALL;
			}
			else {

	Version = (PVERSION_DATA)ioBuffer;
	Version->usMajor = CMDR_MAJORVERSION;
	Version->usMinor = CMDR_MINORVERSION;
	Version->usRevision = CMDR_REVISION;
	Version->usBuild = CMDR_BUILD;

	Irp->IoStatus.Information = outputBufferLength; 													
			}
		}
		break; // IOCTL_GET_CMDR_VERSION

		//////////////////////////////
		// these added for 1394cmdr //
		//////////////////////////////
	case IOCTL_SET_CMDR_TRACELEVEL:
		if(inputBufferLength < sizeof(LONG))
		{
			ntStatus = STATUS_BUFFER_TOO_SMALL;
		} else {
			TRACE(TL_CHECK,("Trace Level set from %ld to %ld",t1394CmdrDebugLevel,*((PLONG)ioBuffer)));
			t1394CmdrDebugLevel = *((PLONG)ioBuffer);
		}
		break;
	case IOCTL_GET_CMDR_TRACELEVEL:
		if(outputBufferLength < sizeof(LONG))
		{
			ntStatus = STATUS_BUFFER_TOO_SMALL;
		} else {
			*((PLONG)ioBuffer) = t1394CmdrDebugLevel;
			Irp->IoStatus.Information = sizeof(LONG);
			
		}
		break;
	case IOCTL_READ_REGISTER:
		{
      if(outputBufferLength < sizeof(REGISTER_IOBUF) ||
	       inputBufferLength < sizeof(REGISTER_IOBUF))
			{
	      ntStatus = STATUS_BUFFER_TOO_SMALL;
			} else {
	      // an address with a leading 0xF will be interpreted
	      // as an absolute offset in register space

	      // otherwise, it will be added to the CSR offset
	      PREGISTER_IOBUF regbuf = (PREGISTER_IOBUF)ioBuffer;
	      ULONG offset = regbuf->ulOffset;

	      if(!(offset & 0xF0000000))
		      offset += deviceExtension->CSR_offset;

	      ntStatus = t1394Cmdr_ReadRegister(DeviceObject,
						      Irp,
						      offset,
						      regbuf->data
						      );
	      if (NT_SUCCESS(ntStatus))
		      Irp->IoStatus.Information = outputBufferLength;
			}
		} break;
	case IOCTL_WRITE_REGISTER:
		{
			if(outputBufferLength < sizeof(REGISTER_IOBUF) ||
	       inputBufferLength < sizeof(REGISTER_IOBUF))
			{
	      ntStatus = STATUS_BUFFER_TOO_SMALL;
			} else {
	      // an address with a leading 0xF will be interpreted
	      // as an absolute offset in register space

	      // otherwise, it will be added to the CSR offset
	      PREGISTER_IOBUF regbuf = (PREGISTER_IOBUF) ioBuffer;
	      ULONG offset = regbuf->ulOffset;

	      if(!(offset & 0xF0000000))
		      offset += deviceExtension->CSR_offset;

	      ntStatus = t1394Cmdr_WriteRegister(DeviceObject,
						       Irp,
						       offset,
						       regbuf->data
						       );
			}
		} break;
	case IOCTL_GET_MODEL_NAME:
		if(outputBufferLength < (unsigned long)(deviceExtension->ModelNameLength))
		{
			ntStatus = STATUS_BUFFER_TOO_SMALL;
		} else {
			RtlCopyMemory(ioBuffer,&(deviceExtension->pModelLeaf->TL_Data),deviceExtension->ModelNameLength);
			ntStatus = STATUS_SUCCESS;
			Irp->IoStatus.Information = deviceExtension->ModelNameLength;
		}
		break;
	case IOCTL_GET_VENDOR_NAME:
		if(outputBufferLength < (unsigned long)(deviceExtension->VendorNameLength))
		{
			ntStatus = STATUS_BUFFER_TOO_SMALL;
		} else {
			RtlCopyMemory(ioBuffer,&(deviceExtension->pVendorLeaf->TL_Data),deviceExtension->VendorNameLength);
			ntStatus = STATUS_SUCCESS;
			Irp->IoStatus.Information = deviceExtension->VendorNameLength;
		}
		break;
	case IOCTL_GET_CAMERA_SPECIFICATION:
	
		if(outputBufferLength < sizeof(CAMERA_SPECIFICATION))
		{
			ntStatus = STATUS_BUFFER_TOO_SMALL;
		} else {
			PCAMERA_SPECIFICATION pSpec = (PCAMERA_SPECIFICATION)(ioBuffer);
			pSpec->ulSpecification = deviceExtension->unit_spec_ID;
			pSpec->ulVersion = deviceExtension->unit_sw_version;
			Irp->IoStatus.Information = sizeof(CAMERA_SPECIFICATION);
		}
		break;

	case IOCTL_GET_CAMERA_UNIQUE_ID:
		if(outputBufferLength < sizeof(LARGE_INTEGER))
		{
			ntStatus = STATUS_BUFFER_TOO_SMALL;
		} else {
			PLARGE_INTEGER pID = (PLARGE_INTEGER)(ioBuffer);
			pID->HighPart = deviceExtension->pConfigRom->CR_Node_UniqueID[0];
			pID->LowPart = deviceExtension->pConfigRom->CR_Node_UniqueID[1];
			Irp->IoStatus.Information = sizeof(LARGE_INTEGER);
		}
		break;
	case IOCTL_ISOCH_SETUP_STREAM:
		TRACE(TL_TRACE,("IOCTL_ISOCH_SETUP_STREAM\n"));
		if (inputBufferLength < sizeof(ISOCH_STREAM_PARAMS) ||
	      outputBufferLength < sizeof(ISOCH_STREAM_PARAMS) )
		{
			ntStatus = STATUS_BUFFER_TOO_SMALL;
		} else {
			ntStatus = t1394_IsochSetupStream(DeviceObject,
					Irp,
					(PISOCH_STREAM_PARAMS)ioBuffer);
			if (NT_SUCCESS(ntStatus))
        Irp->IoStatus.Information = outputBufferLength;
		}
		break;
	case IOCTL_ISOCH_TEAR_DOWN_STREAM:
		TRACE(TL_TRACE,("IOCTL_ISOCH_TEAR_DOWN_STREAM\n"));
		ntStatus = t1394_IsochTearDownStream(DeviceObject,Irp);
		break;
	case IOCTL_ATTACH_BUFFER:
		// Input Argument: ISOCH_BUFFER_PARAMS
		// Output Argument: The actual buffer as MDL
		if(ioBuffer != NULL && inputBufferLength < sizeof(ISOCH_BUFFER_PARAMS))
		{
			ntStatus = STATUS_BUFFER_TOO_SMALL;
		} else {
            PISOCH_BUFFER_PARAMS pParams = (PISOCH_BUFFER_PARAMS)(ioBuffer);
            // Buffer is good, resources are good, call the function
            // Maybe all this needs to be pushed into t1394Cmdr_IsochAttachBuffer
            ntStatus = t1394Cmdr_IsochAttachBuffer( 
					         DeviceObject,
					         Irp,
                             pParams,
					         Irp->MdlAddress
					         );
        }
		break;

  case IOCTL_GET_MAX_ISOCH_SPEED:
		{
      PULONG pMaxSpeedOutput = (PULONG)(ioBuffer);
      if((inputBufferLength < sizeof(ULONG)) ||
		     (outputBufferLength < sizeof(ULONG)))
      {
	      ntStatus = STATUS_BUFFER_TOO_SMALL;
      } else {
          ULONG hostSpeed = 0, mySpeed = 0, meToHostSpeed = 0;

         // must determine MaxSpeed
          ntStatus = t1394_GetMaxSpeedBetweenDevices( DeviceObject,
								Irp,
								0,
                0,
                &DeviceObject,
                &mySpeed);
          TRACE(TL_CHECK,(_TP("GetMaxSpeedBetweenDevices(0,ME,NULL) Says: %x : %08x"),ntStatus,mySpeed));

                    // must determine MaxSpeed
          ntStatus = t1394_GetMaxSpeedBetweenDevices( DeviceObject,
								Irp,
								USE_LOCAL_NODE,
                0,
                &DeviceObject,
                &hostSpeed);
          TRACE(TL_CHECK,(_TP("GetMaxSpeedBetweenDevices(1,HOST,NULL) Says: %x : %08x"),ntStatus,hostSpeed));

          // must determine MaxSpeed
          ntStatus = t1394_GetMaxSpeedBetweenDevices( DeviceObject,
								Irp,
								USE_LOCAL_NODE,
                1,
                &DeviceObject,
                &meToHostSpeed);
          TRACE(TL_CHECK,(_TP("GetMaxSpeedBetweenDevices(1,HOST,ME) Says: %x : %08x"),ntStatus,meToHostSpeed));

          // for some reason, in some conditions, meToHostSpeed isn't what is expected... maybe fresh initialization of
          // the bus starts everything up in 100 mbps mode.   For now, place the policy that was previously in the DLL
          // here: min of hostSpeed and mySpeed

          deviceExtension->MaxSpeed = (hostSpeed < mySpeed ? hostSpeed : mySpeed);
          TRACE(TL_CHECK,(_TP("  -> Using speed %x"),deviceExtension->MaxSpeed));
      } // buffer length check

	    if (NT_SUCCESS(ntStatus))
      {
          TRACE(TL_TRACE,("1394CMDR: GET_MAX_ISOCH_SPEED: %x -> (ioBuffer @ %p)!",deviceExtension->MaxSpeed, ioBuffer));
          *(PULONG)(ioBuffer) = deviceExtension->MaxSpeed;
      		Irp->IoStatus.Information = sizeof(ULONG);
      } else {
          TRACE(TL_ERROR, ("1394CMDR: Error on t1394GetMaxSpeedBetweenDevices: %x",ntStatus));
      }

    } break;
	default:
		TRACE(TL_ERROR, ("Invalid ioControlCode = 0x%x\n", ioControlCode));
		ntStatus = STATUS_INVALID_PARAMETER;
		break; // default
	} // switch

	break; // IRP_MJ_DEVICE_CONTROL

 default:
	 TRACE(TL_TRACE, ("Unknown IrpSp->MajorFunction = 0x%x\n", IrpSp->MajorFunction));

	 // submit this to the driver below us
	 ntStatus = t1394_SubmitIrpAsync (deviceExtension->StackDeviceObject, Irp, NULL);
	 return (ntStatus);
	 break;

} // switch

		// only complete if the device is there
	if (ntStatus != STATUS_NO_SUCH_DEVICE && ntStatus != STATUS_PENDING) {
		
		Irp->IoStatus.Status = ntStatus;
		IoCompleteRequest(Irp, IO_NO_INCREMENT);
	}

 _exit:

	EXIT("t1394Cmdr_IoControl", ntStatus);
	return(ntStatus);
} // t1394Cmdr_IoControl


