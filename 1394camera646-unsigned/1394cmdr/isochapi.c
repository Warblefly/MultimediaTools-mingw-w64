/*++

Copyright (c) 1998  Microsoft Corporation

Module Name:

    isochapi.c

Abstract


Author:

    Peter Binder (pbinder) 7/26/97

Revision History:
Date     Who       What
-------- --------- ------------------------------------------------------------
7/26/97  pbinder   birth
4/14/98  pbinder   taken from 1394diag
--*/

#include "pch.h"

/**\brief Utility to compute actual bandwidth cap as a function of speed
 * \param ulSpeed Bus Speed (e.g. SPEED_FLAGS_400)
 * \return Actual bytes of available bandwidth
 */
void t1394_GetBusLimitsForSpeed(IN ULONG ulSpeed, OUT PULONG pulMaxPacketSize, OUT PULONG pulMaxBandwidth)
{
  ULONG ulSpeedMultiplier = 0;

  switch( ulSpeed )
  {
  case SPEED_FLAGS_100:
    ulSpeedMultiplier = 1;
    break;
  case SPEED_FLAGS_200:
    ulSpeedMultiplier = 2;
    break;
  case SPEED_FLAGS_400:
    ulSpeedMultiplier = 4;
    break;
  case SPEED_FLAGS_800:
    ulSpeedMultiplier = 8;
    break;
  case SPEED_FLAGS_1600:
    ulSpeedMultiplier = 16;
    break;
  case SPEED_FLAGS_3200:
    ulSpeedMultiplier = 32;
    break;
  default:
    ulSpeedMultiplier = 4;
  }

  if(pulMaxPacketSize != NULL)
  {
    // This is straight from the 1394 bus spec: max isoch packet is 1K per 100mbps
    *pulMaxPacketSize = ulSpeedMultiplier * 1024;
  }

  if(pulMaxBandwidth != NULL)
  {
    // 4915 is the actual number of bytes in the isoch window at S400
    // /4 is to normalize for S400
    *pulMaxBandwidth  = (ulSpeedMultiplier * 4915) / 4;
  }
}

NTSTATUS t1394_IsochSetupStream(
    IN PDEVICE_OBJECT   DeviceObject,
    IN PIRP             Irp,
    IN OUT PISOCH_STREAM_PARAMS pStreamParams
    )
{
  NTSTATUS ntStatus = STATUS_UNSUCCESSFUL;
  PDEVICE_EXTENSION   deviceExtension = DeviceObject->DeviceExtension;
  PCAMERA_STATE cameraState = &(deviceExtension->CameraState);
  UCHAR ucData[4];

  // pick apart actual bytes per frame and the flags
  ULONG nMaxBytesPerFrame = pStreamParams->nMaxBytesPerFrame & BYTES_PER_FRAME_DATA_MASK;
  const ULONG BytesPerFrameFlags = pStreamParams->nMaxBytesPerFrame & BYTES_PER_FRAME_FLAG_MASK;
  
  ENTER("t1394_IsochSetupStream");

  /* if already busy, punt and let the user clean things up with RESET_STATE */
  if(cameraState->hIsochResource != NULL ||
     cameraState->IsochChannel != -1 ||
     cameraState->hIsochBandwidth != NULL ||
     cameraState->hAltIsochBandwidth != NULL)
  {
    TRACE(TL_ERROR,("SetupStream: resources already allocated, use TEARDOWN_STREAM first\n"));
    goto _exit;
  }

  if(pStreamParams->nChannel == -1)
  {
    // channel == -1 implies we have to allocate a bunch of junk

    /* order of operations: bandwidth, channel, "resources" */

    // In the following code we allocate bandwidth twice to get past the maximum packet size
    // limit for devices that use less than the full bandwidth, but with packet sizes larger
    // than the packet size limit.
    ULONG ulMaxPacketSize, ulMaxBandwidth;
    ULONG altMaxBytesPerFrame;

    // grab the limits for this speed
    t1394_GetBusLimitsForSpeed(pStreamParams->fulSpeed,&ulMaxPacketSize,&ulMaxBandwidth);

    // test for packet splitting
    // if necessary, alloc hAltIsochBandwidth here and modify nMaxBytesPerFrame for the standard alloc below
    if((BytesPerFrameFlags & BYTES_PER_FRAME_ALLOW_PGR_DUAL_PACKET) != 0)
    {
      TRACE(TL_ALWAYS,("SetupStream: Allowing PGR Dual-Packet Support\n"));
    }

    if((BytesPerFrameFlags & BYTES_PER_FRAME_ALLOW_PGR_DUAL_PACKET) &&
       nMaxBytesPerFrame > ulMaxPacketSize &&
       nMaxBytesPerFrame <= ulMaxBandwidth)
    {
      TRACE(TL_CHECK,("Attempting Split Bandwidth Allocation for PGR Dual-Packet support:\n"));

      // allocate half the bandwidth here
      altMaxBytesPerFrame = nMaxBytesPerFrame / 2; // is /2 always valid here?
      TRACE(TL_CHECK,("  - orgMaxBytesPerFrame = %d\n",nMaxBytesPerFrame));
      TRACE(TL_CHECK,("  - altMaxBytesPerFrame = %d\n",altMaxBytesPerFrame));

      // allocate the complement in the normal allocation step below, retain as the actual bpf value
      nMaxBytesPerFrame -= altMaxBytesPerFrame;
      TRACE(TL_CHECK,("  -   nMaxBytesPerFrame = %d\n",nMaxBytesPerFrame));

      // allocate alt
      ntStatus = t1394_IsochAllocateBandwidth(DeviceObject,
                                              Irp,
                                              altMaxBytesPerFrame,
                                              pStreamParams->fulSpeed,
                                              &(cameraState->hAltIsochBandwidth),
                                              &(cameraState->IsochBytesPerFrameAvailable),
                                              &(cameraState->IsochSpeedSelected));

      if(!NT_SUCCESS(ntStatus))
        goto _exit;

    } // fall through for normal allocation

    // allocate nominal bandwidth
    ntStatus = t1394_IsochAllocateBandwidth(DeviceObject,
                                            Irp,
                                            nMaxBytesPerFrame,
                                            pStreamParams->fulSpeed,
                                            &(cameraState->hIsochBandwidth),
                                            &(cameraState->IsochBytesPerFrameAvailable),
                                            &(cameraState->IsochSpeedSelected));

    if(!NT_SUCCESS(ntStatus))
      goto _exit;

    // store the (potentially modified) nMaxBytesPerFrame in cameraState
    cameraState->IsochMaxBytesPerFrame = nMaxBytesPerFrame;
    cameraState->IsochMaxBufferSize = pStreamParams->nMaxBufferSize;

    // allocate a channel
    ntStatus = t1394_IsochAllocateChannel(DeviceObject,
                                          Irp,
                                          pStreamParams->nChannel,
                                          &(cameraState->IsochChannel),
                                          &(cameraState->IsochChannelsAvailable));

    if(!NT_SUCCESS(ntStatus))
      goto _exit;

    pStreamParams->nChannel = cameraState->IsochChannel;
  } else {
    TRACE(TL_CHECK,("SetupStream: Skipping channel,bw allocation, using supplied channel %d\n",pStreamParams->nChannel));
    // for good measure
    cameraState->IsochChannel = -1;
    cameraState->hIsochBandwidth = NULL;
    cameraState->hAltIsochBandwidth = NULL;
  }

  // when allocating resources, we only specify a nMaxBytesPerFrame
  // equal to the previously determined nMaxBytesPerFrame ( bandwidth ).
  ntStatus = t1394_IsochAllocateResources(DeviceObject,
                                          Irp,
                                          pStreamParams->fulSpeed,
                                          RESOURCE_USED_IN_LISTENING |
										  RESOURCE_STRIP_ADDITIONAL_QUADLETS,
                                          pStreamParams->nChannel,
                                          nMaxBytesPerFrame,
                                          pStreamParams->nNumberOfBuffers,
                                          pStreamParams->nMaxBufferSize,
                                          1,
                                          &(cameraState->hIsochResource));

  if(!NT_SUCCESS(ntStatus))
    goto _exit;

  pStreamParams->fulSpeed = cameraState->IsochSpeedSelected;
  pStreamParams->nChannel = cameraState->IsochChannel;
  ntStatus = STATUS_SUCCESS;

 _exit:
  if(!NT_SUCCESS(ntStatus))
  {
    /* clean up before we bail */
    t1394_IsochTearDownStream(DeviceObject,
                              Irp);
  } else {
    TRACE(TL_CHECK,("hIsochResource = %p\n",cameraState->hIsochResource));
    TRACE(TL_CHECK,("IsochChannel = %d\n",cameraState->IsochChannel));
    TRACE(TL_CHECK,("hIsochBandwidth = %p\n",cameraState->hIsochBandwidth));
    TRACE(TL_CHECK,("hAltIsochBandwidth = %p\n",cameraState->hAltIsochBandwidth));
  }

  EXIT("t1394_IsochSetupStream",ntStatus);
  return ntStatus;
}

/*
 * TearDownStream
 *
 * Clears out any Isoch Channel, Bandwidth, or Resources
 * Detaches and frees any DMA buffers
 * Tells the Camera to Stop streaming data
 */


NTSTATUS
t1394_IsochTearDownStream(
    IN PDEVICE_OBJECT   DeviceObject,
    IN PIRP             Irp
    )
{
  ULONG CSR_offset;
  PDEVICE_EXTENSION deviceExtension = DeviceObject->DeviceExtension;
  PCAMERA_STATE cameraState = &(deviceExtension->CameraState);
  NTSTATUS ntStatus = STATUS_UNSUCCESSFUL;
  UCHAR bytes[4];

  ENTER("t1394Cmdr_IsochTearDownStream");

  // send some isoch stop
  if(cameraState->hIsochResource != NULL)
  {
    ntStatus = t1394_IsochStop(DeviceObject, Irp);
    if (!NT_SUCCESS(ntStatus))
    {
      TRACE(TL_ERROR, ("Error on IsochStop = 0x%x\n", ntStatus));
      goto _exit;
    }
  }

  // deallocate any attached buffers
  while (TRUE) {
    KIRQL               Irql;

    KeAcquireSpinLock(&deviceExtension->IsochSpinLock, &Irql);

    if (!IsListEmpty(&deviceExtension->IsochDetachData)) {

      PISOCH_DETACH_DATA      IsochDetachData;

      IsochDetachData = (PISOCH_DETACH_DATA)RemoveHeadList(&deviceExtension->IsochDetachData);

      TRACE(TL_TRACE, ("Surprise Removal: IsochDetachData = %p\n", IsochDetachData));

      // clear the tag...
      //IsochDetachData->Tag = 0;

      KeReleaseSpinLock(&deviceExtension->IsochSpinLock, Irql);

      TRACE(TL_TRACE, ("Surprise Removal: IsochDetachData->Irp = %p\n", IsochDetachData->Irp));

      // need to save the ntStatus of the attach
      // we'll clean up in the same spot for success's and timeout's
      IsochDetachData->AttachStatus = STATUS_SUCCESS;

      // detach no matter what...
      IsochDetachData->bDetach = TRUE;

      t1394_IsochCleanup(IsochDetachData);
    } else {
      KeReleaseSpinLock(&deviceExtension->IsochSpinLock, Irql);
      break;
    }
  }


  if(cameraState->hIsochBandwidth != NULL)
  {
    TRACE(TL_CHECK,("Freeing Bandwidth[0]: %p\n",cameraState->hIsochBandwidth));
    ntStatus = t1394_IsochFreeBandwidth(DeviceObject,Irp,cameraState->hIsochBandwidth);
    if (!NT_SUCCESS(ntStatus))
    {
      TRACE(TL_ERROR, ("IsochFreeBandwidth Failed = 0x%x\n", ntStatus));
      goto _exit;
    }
    cameraState->hIsochBandwidth = NULL;
  }

  if(cameraState->hAltIsochBandwidth != NULL)
  {
    TRACE(TL_CHECK,("Freeing Bandwidth[1]: %p\n",cameraState->hAltIsochBandwidth));
    ntStatus = t1394_IsochFreeBandwidth(DeviceObject,Irp,cameraState->hAltIsochBandwidth);
    if (!NT_SUCCESS(ntStatus))
    {
      TRACE(TL_ERROR, ("IsochFreeBandwidth Failed = 0x%x\n", ntStatus));
      goto _exit;
    }
    cameraState->hAltIsochBandwidth = NULL;
  }

  if(cameraState->hIsochResource != NULL)
  {
    TRACE(TL_CHECK,("Freeing Resource: %p\n",cameraState->hIsochResource));
    ntStatus = t1394_IsochFreeResources(DeviceObject,Irp,cameraState->hIsochResource);
    if (!NT_SUCCESS(ntStatus))
    {
      TRACE(TL_ERROR, ("IsochFreeResources Failed = 0x%x\n", ntStatus));
      goto _exit;
    }
    cameraState->hIsochResource = NULL;
  }

  if(cameraState->IsochChannel != -1)
  {
    TRACE(TL_CHECK,("Freeing Channel: %8d\n",cameraState->IsochChannel));
    ntStatus = t1394_IsochFreeChannel(DeviceObject,Irp,cameraState->IsochChannel);
    if (!NT_SUCCESS(ntStatus))
    {
      TRACE(TL_ERROR, ("IsochFreeChannel Failed = 0x%x\n", ntStatus));
      goto _exit;
    }
    cameraState->IsochChannel = -1;
  }

  cameraState->IsochBytesPerFrameAvailable = 0;
  cameraState->IsochSpeedSelected = 0;

  ntStatus = STATUS_SUCCESS;

 _exit:

  if(!NT_SUCCESS(ntStatus))
    TRACE(TL_ERROR,("1394CMDR: Error %08x while Resetting Camera State\n",ntStatus));

  return ntStatus;
}


NTSTATUS
t1394_IsochAllocateBandwidth(
    IN PDEVICE_OBJECT   DeviceObject,
    IN PIRP             Irp,
    IN ULONG            nMaxBytesPerFrameRequested,
    IN ULONG            fulSpeed,
    OUT PHANDLE         phBandwidth,
    OUT PULONG          pBytesPerFrameAvailable,
    OUT PULONG          pSpeedSelected
    )
{
    NTSTATUS            ntStatus = STATUS_SUCCESS;
    PDEVICE_EXTENSION   deviceExtension = DeviceObject->DeviceExtension;
  PCAMERA_STATE    cameraState = &(deviceExtension->CameraState);
    PIRB                pIrb;

    PIRP                newIrp;
    BOOLEAN             allocNewIrp = FALSE;
    KEVENT              Event;
    IO_STATUS_BLOCK     ioStatus;

    ENTER("t1394_IsochAllocateBandwidth");

    TRACE(TL_TRACE, ("nMaxBytesPerFrameRequested = 0x%x\n", nMaxBytesPerFrameRequested));
    TRACE(TL_TRACE, ("fulSpeed = 0x%x\n", fulSpeed));

    //
    // If this is a UserMode request create a newIrp so that the request
    // will be issued from KernelMode
    //
    if (Irp->RequestorMode == UserMode) {

        newIrp = IoBuildDeviceIoControlRequest (IOCTL_1394_CLASS, deviceExtension->StackDeviceObject,
                            NULL, 0, NULL, 0, TRUE, &Event, &ioStatus);

        if (!newIrp) {

            TRACE(TL_ERROR, ("Failed to allocate newIrp!\n"));
            ntStatus = STATUS_INSUFFICIENT_RESOURCES;
            goto Exit_IsochAllocateBandwidth;
        }
        allocNewIrp = TRUE;
    }

    pIrb = ExAllocatePool(NonPagedPool, sizeof(IRB));

    if (!pIrb) {

        TRACE(TL_ERROR, ("Failed to allocate pIrb!\n"));
        ntStatus = STATUS_INSUFFICIENT_RESOURCES;
        goto Exit_IsochAllocateBandwidth;
    } // if

    RtlZeroMemory (pIrb, sizeof (IRB));
    pIrb->FunctionNumber = REQUEST_ISOCH_ALLOCATE_BANDWIDTH;
    pIrb->Flags = 0;
    pIrb->u.IsochAllocateBandwidth.nMaxBytesPerFrameRequested = nMaxBytesPerFrameRequested;
    pIrb->u.IsochAllocateBandwidth.fulSpeed = fulSpeed;

    //
    // If we allocated this irp, submit it asynchronously and wait for its
    // completion event to be signaled.  Otherwise submit it synchronously
    //
    if (allocNewIrp) {

        KeInitializeEvent (&Event, NotificationEvent, FALSE);
        ntStatus = t1394_SubmitIrpAsync (deviceExtension->StackDeviceObject, newIrp, pIrb);

        if (ntStatus == STATUS_PENDING) {
            KeWaitForSingleObject (&Event, Executive, KernelMode, FALSE, NULL);
            ntStatus = ioStatus.Status;
        }
    }
    else {
        ntStatus = t1394_SubmitIrpSynch(deviceExtension->StackDeviceObject, Irp, pIrb);
    }

    if (NT_SUCCESS(ntStatus)) {

        *phBandwidth = pIrb->u.IsochAllocateBandwidth.hBandwidth;
        *pBytesPerFrameAvailable = pIrb->u.IsochAllocateBandwidth.BytesPerFrameAvailable;
        *pSpeedSelected = pIrb->u.IsochAllocateBandwidth.SpeedSelected;

        TRACE(TL_TRACE, ("hBandwidth = %p\n", *phBandwidth));
        TRACE(TL_TRACE, ("BytesPerFrameAvailable = 0x%x\n", *pBytesPerFrameAvailable));
        TRACE(TL_TRACE, ("SpeedSelected = 0x%x\n", *pSpeedSelected));

        // lets see if we got the speed we wanted
        if (fulSpeed != pIrb->u.IsochAllocateBandwidth.SpeedSelected) {

            TRACE(TL_TRACE, ("Different bandwidth speed selected.\n"));
        }

        TRACE(TL_TRACE, ("SpeedSelected = 0x%x\n", *pSpeedSelected));
    }
    else {

        TRACE(TL_ERROR, ("SubmitIrpSync failed = 0x%x\n", ntStatus));
    }

    ExFreePool(pIrb);

Exit_IsochAllocateBandwidth:

    if (allocNewIrp)
        Irp->IoStatus = ioStatus;

    EXIT("t1394_IsochAllocateBandwidth", ntStatus);
    return(ntStatus);
} // t1394_IsochAllocateBandwidth

NTSTATUS
t1394_IsochAllocateChannel(
    IN PDEVICE_OBJECT   DeviceObject,
    IN PIRP             Irp,
    IN ULONG            nRequestedChannel,
    OUT PULONG          pChannel,
    OUT PLARGE_INTEGER  pChannelsAvailable
    )
{
    NTSTATUS            ntStatus = STATUS_SUCCESS;
    PDEVICE_EXTENSION   deviceExtension = DeviceObject->DeviceExtension;
    PCAMERA_STATE cameraState = &(deviceExtension->CameraState);
    PIRB                pIrb;

    PIRP                newIrp;
    BOOLEAN             allocNewIrp = FALSE;
    KEVENT              Event;
    IO_STATUS_BLOCK     ioStatus;

    ENTER("t1394_IsochAllocateChannel");

    TRACE(TL_TRACE, ("nRequestedChannel = 0x%x\n", nRequestedChannel));

    //
    // If this is a UserMode request create a newIrp so that the request
    // will be issued from KernelMode
    //
    if (Irp->RequestorMode == UserMode) {

        newIrp = IoBuildDeviceIoControlRequest (IOCTL_1394_CLASS, deviceExtension->StackDeviceObject,
                            NULL, 0, NULL, 0, TRUE, &Event, &ioStatus);

        if (!newIrp) {

            TRACE(TL_ERROR, ("Failed to allocate newIrp!\n"));
            ntStatus = STATUS_INSUFFICIENT_RESOURCES;
            goto Exit_IsochAllocateChannel;
        }
        allocNewIrp = TRUE;
    }

    pIrb = ExAllocatePool(NonPagedPool, sizeof(IRB));

    if (!pIrb) {

        TRACE(TL_ERROR, ("Failed to allocate pIrb!\n"));
        ntStatus = STATUS_INSUFFICIENT_RESOURCES;
        goto Exit_IsochAllocateChannel;
    } // if

    RtlZeroMemory (pIrb, sizeof (IRB));
    pIrb->FunctionNumber = REQUEST_ISOCH_ALLOCATE_CHANNEL;
    pIrb->Flags = 0;
    pIrb->u.IsochAllocateChannel.nRequestedChannel = nRequestedChannel;

    //
    // If we allocated this irp, submit it asynchronously and wait for its
    // completion event to be signaled.  Otherwise submit it synchronously
    //
    if (allocNewIrp) {

        KeInitializeEvent (&Event, NotificationEvent, FALSE);
        ntStatus = t1394_SubmitIrpAsync (deviceExtension->StackDeviceObject, newIrp, pIrb);

        if (ntStatus == STATUS_PENDING) {
            KeWaitForSingleObject (&Event, Executive, KernelMode, FALSE, NULL);
            ntStatus = ioStatus.Status;
        }
    }
    else {
        ntStatus = t1394_SubmitIrpSynch(deviceExtension->StackDeviceObject, Irp, pIrb);
    }

    if (NT_SUCCESS(ntStatus)) {

        *pChannel = pIrb->u.IsochAllocateChannel.Channel;
        *pChannelsAvailable = pIrb->u.IsochAllocateChannel.ChannelsAvailable;

    cameraState->IsochChannel = *pChannel;
    cameraState->IsochChannelsAvailable = *pChannelsAvailable;
        TRACE(TL_TRACE, ("Channel = 0x%x\n", *pChannel));
        TRACE(TL_TRACE, ("ChannelsAvailable.LowPart = 0x%x\n", pChannelsAvailable->LowPart));
        TRACE(TL_TRACE, ("ChannelsAvailable.HighPart = 0x%x\n", pChannelsAvailable->HighPart));
    }
    else {

        TRACE(TL_ERROR, ("SubmitIrpSync failed = 0x%x\n", ntStatus));
    }

    ExFreePool(pIrb);

Exit_IsochAllocateChannel:

    if (allocNewIrp)
        Irp->IoStatus = ioStatus;

    EXIT("t1394_IsochAllocateChannel", ntStatus);
    return(ntStatus);
} // t1394_IsochAllocateChannel

NTSTATUS
t1394_IsochAllocateResources(
    IN PDEVICE_OBJECT   DeviceObject,
    IN PIRP             Irp,
    IN ULONG            fulSpeed,
    IN ULONG            fulFlags,
    IN ULONG            nChannel,
    IN ULONG            nMaxBytesPerFrame,
    IN ULONG            nNumberOfBuffers,
    IN ULONG            nMaxBufferSize,
    IN ULONG            nQuadletsToStrip,
    OUT PHANDLE         phResource
    )
{
    NTSTATUS            ntStatus = STATUS_SUCCESS;
    PDEVICE_EXTENSION   deviceExtension = DeviceObject->DeviceExtension;
    PCAMERA_STATE cameraState = &(deviceExtension->CameraState);
    PIRB                pIrb;

    PIRP                newIrp;
    BOOLEAN             allocNewIrp = FALSE;
    KEVENT              Event;
    IO_STATUS_BLOCK     ioStatus;

    ENTER("t1394_IsochAllocateResources");

    TRACE(TL_TRACE, ("fulSpeed = 0x%x\n", fulSpeed));
    TRACE(TL_TRACE, ("fulFlags = 0x%x\n", fulFlags));
    TRACE(TL_TRACE, ("nChannel = 0x%x\n", nChannel));
    TRACE(TL_TRACE, ("nMaxBytesPerFrame = 0x%x\n", nMaxBytesPerFrame));
    TRACE(TL_TRACE, ("nNumberOfBuffers = 0x%x\n", nNumberOfBuffers));
    TRACE(TL_TRACE, ("nMaxBufferSize = 0x%x\n", nMaxBufferSize));
    TRACE(TL_TRACE, ("nQuadletsToStrip = 0x%x\n", nQuadletsToStrip));

    //
    // If this is a UserMode request create a newIrp so that the request
    // will be issued from KernelMode
    //
    if (Irp->RequestorMode == UserMode) {

        newIrp = IoBuildDeviceIoControlRequest (IOCTL_1394_CLASS, deviceExtension->StackDeviceObject,
                            NULL, 0, NULL, 0, TRUE, &Event, &ioStatus);

        if (!newIrp) {

            TRACE(TL_ERROR, ("Failed to allocate newIrp!\n"));
            ntStatus = STATUS_INSUFFICIENT_RESOURCES;
            goto Exit_IsochAllocateResources;
        }
        allocNewIrp = TRUE;
    }

    pIrb = ExAllocatePool(NonPagedPool, sizeof(IRB));

    if (!pIrb) {

        TRACE(TL_ERROR, ("Failed to allocate pIrb!\n"));
        ntStatus = STATUS_INSUFFICIENT_RESOURCES;
        goto Exit_IsochAllocateResources;
    } // if

    RtlZeroMemory (pIrb, sizeof (IRB));
    pIrb->FunctionNumber = REQUEST_ISOCH_ALLOCATE_RESOURCES;
    pIrb->Flags = 0;
    pIrb->u.IsochAllocateResources.fulSpeed = fulSpeed;
    pIrb->u.IsochAllocateResources.fulFlags = fulFlags;
    pIrb->u.IsochAllocateResources.nChannel = nChannel;
    pIrb->u.IsochAllocateResources.nMaxBytesPerFrame = nMaxBytesPerFrame;
    pIrb->u.IsochAllocateResources.nNumberOfBuffers = nNumberOfBuffers;
    pIrb->u.IsochAllocateResources.nMaxBufferSize = nMaxBufferSize;
    pIrb->u.IsochAllocateResources.nQuadletsToStrip = nQuadletsToStrip;

    //
    // If we allocated this irp, submit it asynchronously and wait for its
    // completion event to be signaled.  Otherwise submit it synchronously
    //
    if (allocNewIrp) {

        KeInitializeEvent (&Event, NotificationEvent, FALSE);
        ntStatus = t1394_SubmitIrpAsync (deviceExtension->StackDeviceObject, newIrp, pIrb);

        if (ntStatus == STATUS_PENDING) {
            KeWaitForSingleObject (&Event, Executive, KernelMode, FALSE, NULL);
            ntStatus = ioStatus.Status;
        }
    }
    else {
        ntStatus = t1394_SubmitIrpSynch(deviceExtension->StackDeviceObject, Irp, pIrb);
    }

    if (NT_SUCCESS(ntStatus)) {

        PISOCH_RESOURCE_DATA    IsochResourceData;
        KIRQL                   Irql;

        *phResource = pIrb->u.IsochAllocateResources.hResource;
    cameraState->hIsochResource = *phResource;

        TRACE(TL_TRACE, ("hResource = %p\n", *phResource));

        // need to add to our list...
        IsochResourceData = ExAllocatePool(NonPagedPool, sizeof(ISOCH_RESOURCE_DATA));

        if (IsochResourceData) {

            IsochResourceData->hResource = pIrb->u.IsochAllocateResources.hResource;

            KeAcquireSpinLock(&deviceExtension->IsochResourceSpinLock, &Irql);
            InsertHeadList(&deviceExtension->IsochResourceData, &IsochResourceData->IsochResourceList);
            KeReleaseSpinLock(&deviceExtension->IsochResourceSpinLock, Irql);
        }
        else {

            TRACE(TL_WARNING, ("Failed to allocate IsochResourceData!\n"));
        }

    }
    else {

        TRACE(TL_ERROR, ("SubmitIrpSync failed = 0x%x\n", ntStatus));
    }

    ExFreePool(pIrb);

Exit_IsochAllocateResources:

    if (allocNewIrp)
        Irp->IoStatus = ioStatus;

    EXIT("t1394_IsochAllocateResources", ntStatus);
    return(ntStatus);
} // t1394_IsochAllocateResources

NTSTATUS
t1394_IsochFreeBandwidth(
    IN PDEVICE_OBJECT   DeviceObject,
    IN PIRP             Irp,
    IN HANDLE           hBandwidth
    )
{
    NTSTATUS            ntStatus = STATUS_SUCCESS;
    PDEVICE_EXTENSION   deviceExtension = DeviceObject->DeviceExtension;
  PCAMERA_STATE cameraState = &(deviceExtension->CameraState);
    PIRB                pIrb;

    PIRP                newIrp;
    BOOLEAN             allocNewIrp = FALSE;
    KEVENT              Event;
    IO_STATUS_BLOCK     ioStatus;

    ENTER("t1394_IsochFreeBandwidth");

    TRACE(TL_TRACE, ("hBandwidth = %p\n", hBandwidth));

    //
    // If this is a UserMode request create a newIrp so that the request
    // will be issued from KernelMode
    //
    if (Irp->RequestorMode == UserMode) {

        newIrp = IoBuildDeviceIoControlRequest (IOCTL_1394_CLASS, deviceExtension->StackDeviceObject,
                            NULL, 0, NULL, 0, TRUE, &Event, &ioStatus);

        if (!newIrp) {

            TRACE(TL_ERROR, ("Failed to allocate newIrp!\n"));
            ntStatus = STATUS_INSUFFICIENT_RESOURCES;
            goto Exit_IsochFreeBandwidth;
        }
        allocNewIrp = TRUE;
    }

    pIrb = ExAllocatePool(NonPagedPool, sizeof(IRB));

    if (!pIrb) {

        TRACE(TL_ERROR, ("Failed to allocate pIrb!\n"));
        ntStatus = STATUS_INSUFFICIENT_RESOURCES;
        goto Exit_IsochFreeBandwidth;
    } // if

    RtlZeroMemory (pIrb, sizeof (IRB));
    pIrb->FunctionNumber = REQUEST_ISOCH_FREE_BANDWIDTH;
    pIrb->Flags = 0;
    pIrb->u.IsochFreeBandwidth.hBandwidth = hBandwidth;

    //
    // If we allocated this irp, submit it asynchronously and wait for its
    // completion event to be signaled.  Otherwise submit it synchronously
    //
    if (allocNewIrp) {

        KeInitializeEvent (&Event, NotificationEvent, FALSE);
        ntStatus = t1394_SubmitIrpAsync (deviceExtension->StackDeviceObject, newIrp, pIrb);

        if (ntStatus == STATUS_PENDING) {
            KeWaitForSingleObject (&Event, Executive, KernelMode, FALSE, NULL);
            ntStatus = ioStatus.Status;
        }
    }
    else {
        ntStatus = t1394_SubmitIrpSynch(deviceExtension->StackDeviceObject, Irp, pIrb);
    }

    if (!NT_SUCCESS(ntStatus)) {

        TRACE(TL_ERROR, ("SubmitIrpSync failed = 0x%x\n", ntStatus));
    }

    ExFreePool(pIrb);

Exit_IsochFreeBandwidth:

    if (allocNewIrp)
        Irp->IoStatus = ioStatus;

    EXIT("t1394_IsochFreeBandwidth", ntStatus);
    return(ntStatus);
} // t1394_IsochFreeBandwidth

NTSTATUS
t1394_IsochFreeChannel(
    IN PDEVICE_OBJECT   DeviceObject,
    IN PIRP             Irp,
    IN ULONG            nChannel
    )
{
    NTSTATUS            ntStatus = STATUS_SUCCESS;
    PDEVICE_EXTENSION   deviceExtension = DeviceObject->DeviceExtension;
  PCAMERA_STATE cameraState = &(deviceExtension->CameraState);
    PIRB                pIrb;

    PIRP                newIrp;
    BOOLEAN             allocNewIrp = FALSE;
    KEVENT              Event;
    IO_STATUS_BLOCK     ioStatus;

    ENTER("t1394_IsochFreeChannel");

    TRACE(TL_TRACE, ("nChannel = 0x%x\n", nChannel));

    //
    // If this is a UserMode request create a newIrp so that the request
    // will be issued from KernelMode
    //
    if (Irp->RequestorMode == UserMode) {

        newIrp = IoBuildDeviceIoControlRequest (IOCTL_1394_CLASS, deviceExtension->StackDeviceObject,
                            NULL, 0, NULL, 0, TRUE, &Event, &ioStatus);

        if (!newIrp) {

            TRACE(TL_ERROR, ("Failed to allocate newIrp!\n"));
            ntStatus = STATUS_INSUFFICIENT_RESOURCES;
            goto Exit_IsochFreeChannel;
        }
        allocNewIrp = TRUE;
    }

    pIrb = ExAllocatePool(NonPagedPool, sizeof(IRB));

    if (!pIrb) {

        TRACE(TL_ERROR, ("Failed to allocate pIrb!\n"));
        ntStatus = STATUS_INSUFFICIENT_RESOURCES;
        goto Exit_IsochFreeChannel;
    } // if

    RtlZeroMemory (pIrb, sizeof (IRB));
    pIrb->FunctionNumber = REQUEST_ISOCH_FREE_CHANNEL;
    pIrb->Flags = 0;
    pIrb->u.IsochFreeChannel.nChannel = nChannel;

    //
    // If we allocated this irp, submit it asynchronously and wait for its
    // completion event to be signaled.  Otherwise submit it synchronously
    //
    if (allocNewIrp) {

        KeInitializeEvent (&Event, NotificationEvent, FALSE);
        ntStatus = t1394_SubmitIrpAsync (deviceExtension->StackDeviceObject, newIrp, pIrb);

        if (ntStatus == STATUS_PENDING) {
            KeWaitForSingleObject (&Event, Executive, KernelMode, FALSE, NULL);
            ntStatus = ioStatus.Status;
        }
    }
    else {
        ntStatus = t1394_SubmitIrpSynch(deviceExtension->StackDeviceObject, Irp, pIrb);
    }

    if (!NT_SUCCESS(ntStatus)) {

        TRACE(TL_ERROR, ("SubmitIrpSync failed = 0x%x\n", ntStatus));
    }

  cameraState->IsochChannel = -1;
  cameraState->IsochChannelsAvailable.QuadPart = 0;
    ExFreePool(pIrb);

Exit_IsochFreeChannel:

    if (allocNewIrp)
        Irp->IoStatus = ioStatus;

    EXIT("t1394_IsochFreeChannel", ntStatus);
    return(ntStatus);
} // t1394_IsochFreeChannel

NTSTATUS
t1394_IsochFreeResources(
    IN PDEVICE_OBJECT   DeviceObject,
    IN PIRP             Irp,
    IN HANDLE           hResource
    )
{
    NTSTATUS                ntStatus = STATUS_SUCCESS;
    PDEVICE_EXTENSION       deviceExtension = DeviceObject->DeviceExtension;
  PCAMERA_STATE cameraState = &(deviceExtension->CameraState);
    PIRB                    pIrb;
    PISOCH_RESOURCE_DATA    IsochResourceData;
    KIRQL                   Irql;

    PIRP                newIrp;
    BOOLEAN             allocNewIrp = FALSE;
    KEVENT              Event;
    IO_STATUS_BLOCK     ioStatus;

    ENTER("t1394_IsochFreeResources");

    TRACE(TL_TRACE, ("hResource = %p\n", hResource));

    //
    // If this is a UserMode request create a newIrp so that the request
    // will be issued from KernelMode
    //
    if (Irp->RequestorMode == UserMode) {

        newIrp = IoBuildDeviceIoControlRequest (IOCTL_1394_CLASS, deviceExtension->StackDeviceObject,
                            NULL, 0, NULL, 0, TRUE, &Event, &ioStatus);

        if (!newIrp) {

            TRACE(TL_ERROR, ("Failed to allocate newIrp!\n"));
            ntStatus = STATUS_INSUFFICIENT_RESOURCES;
            goto Exit_IsochFreeResources;
        }
        allocNewIrp = TRUE;
    }

    pIrb = ExAllocatePool(NonPagedPool, sizeof(IRB));

    if (!pIrb) {

        TRACE(TL_ERROR, ("Failed to allocate pIrb!\n"));
        ntStatus = STATUS_INSUFFICIENT_RESOURCES;
        goto Exit_IsochFreeResources;
    } // if

    // remove this one from our list...
    KeAcquireSpinLock(&deviceExtension->IsochResourceSpinLock, &Irql);

    IsochResourceData = (PISOCH_RESOURCE_DATA)deviceExtension->IsochResourceData.Flink;

    while (IsochResourceData) {

        TRACE(TL_TRACE, ("Removing hResource = %p\n", hResource));

        if (IsochResourceData->hResource == hResource) {

            RemoveEntryList(&IsochResourceData->IsochResourceList);
            ExFreePool(IsochResourceData);
            break;
        }
        else if (IsochResourceData->IsochResourceList.Flink == &deviceExtension->IsochResourceData) {
            break;
        }
        else
            IsochResourceData = (PISOCH_RESOURCE_DATA)IsochResourceData->IsochResourceList.Flink;
    }

    KeReleaseSpinLock(&deviceExtension->IsochResourceSpinLock, Irql);

    RtlZeroMemory (pIrb, sizeof (IRB));
    pIrb->FunctionNumber = REQUEST_ISOCH_FREE_RESOURCES;
    pIrb->Flags = 0;
    pIrb->u.IsochFreeResources.hResource = hResource;

    //
    // If we allocated this irp, submit it asynchronously and wait for its
    // completion event to be signaled.  Otherwise submit it synchronously
    //
    if (allocNewIrp) {

        KeInitializeEvent (&Event, NotificationEvent, FALSE);
        ntStatus = t1394_SubmitIrpAsync (deviceExtension->StackDeviceObject, newIrp, pIrb);

        if (ntStatus == STATUS_PENDING) {
            KeWaitForSingleObject (&Event, Executive, KernelMode, FALSE, NULL);
            ntStatus = ioStatus.Status;
        }
    }
    else {
        ntStatus = t1394_SubmitIrpSynch(deviceExtension->StackDeviceObject, Irp, pIrb);
    }

    if (!NT_SUCCESS(ntStatus)) {

        TRACE(TL_ERROR, ("SubmitIrpSync failed = 0x%x\n", ntStatus));
    }
  cameraState->hIsochResource = NULL;

    ExFreePool(pIrb);

Exit_IsochFreeResources:

    if (allocNewIrp)
        Irp->IoStatus = ioStatus;

    EXIT("t1394_IsochFreeResources", ntStatus);
    return(ntStatus);
} // t1394_IsochFreeResources

NTSTATUS
t1394_IsochListen(
    IN PDEVICE_OBJECT   DeviceObject,
    IN PIRP             Irp
    )
{
    NTSTATUS            ntStatus = STATUS_SUCCESS;
    PDEVICE_EXTENSION   deviceExtension = DeviceObject->DeviceExtension;
  PCAMERA_STATE cameraState = &(deviceExtension->CameraState);
    PIRB                pIrb;

    PIRP                newIrp;
    BOOLEAN             allocNewIrp = FALSE;
    KEVENT              Event;
    IO_STATUS_BLOCK     ioStatus;
    HANDLE           hResource;
    ULONG            fulFlags;
    CYCLE_TIME       StartTime;

    ENTER("t1394_IsochListen");
    hResource = cameraState->hIsochResource;
    fulFlags = 0;
    StartTime.CL_CycleCount = 0;
    StartTime.CL_CycleOffset = 0;
    StartTime.CL_SecondCount = 0;
    TRACE(TL_TRACE, ("hResource = %p\n", hResource));
    TRACE(TL_TRACE, ("fulFlags = 0x%x\n", fulFlags));
    TRACE(TL_TRACE, ("StartTime.CL_CycleOffset = 0x%x\n", StartTime.CL_CycleOffset));
    TRACE(TL_TRACE, ("StartTime.CL_CycleCount = 0x%x\n", StartTime.CL_CycleCount));
    TRACE(TL_TRACE, ("StartTime.CL_SecondCount = 0x%x\n", StartTime.CL_SecondCount));

    //
    // If this is a UserMode request create a newIrp so that the request
    // will be issued from KernelMode
    //
    if (Irp->RequestorMode == UserMode) {

        newIrp = IoBuildDeviceIoControlRequest (IOCTL_1394_CLASS, deviceExtension->StackDeviceObject,
                            NULL, 0, NULL, 0, TRUE, &Event, &ioStatus);

        if (!newIrp) {

            TRACE(TL_ERROR, ("Failed to allocate newIrp!\n"));
            ntStatus = STATUS_INSUFFICIENT_RESOURCES;
            goto Exit_IsochListen;
        }
        allocNewIrp = TRUE;
    }

    pIrb = ExAllocatePool(NonPagedPool, sizeof(IRB));

    if (!pIrb) {

        TRACE(TL_ERROR, ("Failed to allocate pIrb!\n"));
        ntStatus = STATUS_INSUFFICIENT_RESOURCES;
        goto Exit_IsochListen;
    } // if

    RtlZeroMemory (pIrb, sizeof (IRB));
    pIrb->FunctionNumber = REQUEST_ISOCH_LISTEN;
    pIrb->Flags = 0;
    pIrb->u.IsochListen.hResource = hResource;
    pIrb->u.IsochListen.fulFlags = fulFlags;
    pIrb->u.IsochListen.StartTime = StartTime;

    //
    // If we allocated this irp, submit it asynchronously and wait for its
    // completion event to be signaled.  Otherwise submit it synchronously
    //
    if (allocNewIrp) {

        KeInitializeEvent (&Event, NotificationEvent, FALSE);
        ntStatus = t1394_SubmitIrpAsync (deviceExtension->StackDeviceObject, newIrp, pIrb);

        if (ntStatus == STATUS_PENDING) {
            KeWaitForSingleObject (&Event, Executive, KernelMode, FALSE, NULL);
            ntStatus = ioStatus.Status;
        }
    }
    else {
        ntStatus = t1394_SubmitIrpSynch(deviceExtension->StackDeviceObject, Irp, pIrb);
    }

    if (!NT_SUCCESS(ntStatus)) {

        TRACE(TL_ERROR, ("SubmitIrpSync failed = 0x%x\n", ntStatus));
    }

    ExFreePool(pIrb);

Exit_IsochListen:

    if (allocNewIrp)
        Irp->IoStatus = ioStatus;

  if(NT_SUCCESS(ntStatus))
  {
    PIO_STACK_LOCATION pISO = IoGetCurrentIrpStackLocation(Irp);
    deviceExtension->bListening = 1;
    deviceExtension->pfoListenObject = pISO ? pISO->FileObject : NULL;
    DbgPrint("Listening from pfoListenObject %p\n",deviceExtension->pfoListenObject);
  }

    EXIT("t1394_IsochListen", ntStatus);
    return(ntStatus);
} // t1394_IsochListen

NTSTATUS
t1394_IsochQueryCurrentCycleTime(
    IN PDEVICE_OBJECT   DeviceObject,
    IN PIRP             Irp,
    OUT PCYCLE_TIME     pCurrentCycleTime
    )
{
    NTSTATUS            ntStatus = STATUS_SUCCESS;
    PDEVICE_EXTENSION   deviceExtension = DeviceObject->DeviceExtension;
    PIRB                pIrb;

    PIRP                newIrp;
    BOOLEAN             allocNewIrp = FALSE;
    KEVENT              Event;
    IO_STATUS_BLOCK     ioStatus;

    ENTER("t1394_IsochQueryCurrentCycleTime");

    //
    // If this is a UserMode request create a newIrp so that the request
    // will be issued from KernelMode
    //
    if (Irp->RequestorMode == UserMode) {

        newIrp = IoBuildDeviceIoControlRequest (IOCTL_1394_CLASS, deviceExtension->StackDeviceObject,
                            NULL, 0, NULL, 0, TRUE, &Event, &ioStatus);

        if (!newIrp) {

            TRACE(TL_ERROR, ("Failed to allocate newIrp!\n"));
            ntStatus = STATUS_INSUFFICIENT_RESOURCES;
            goto Exit_IsochQueryCurrentCycleTime;
        }
        allocNewIrp = TRUE;
    }

    pIrb = ExAllocatePool(NonPagedPool, sizeof(IRB));

    if (!pIrb) {

        TRACE(TL_ERROR, ("Failed to allocate pIrb!\n"));
        ntStatus = STATUS_INSUFFICIENT_RESOURCES;
        goto Exit_IsochQueryCurrentCycleTime;
    } // if

    RtlZeroMemory (pIrb, sizeof (IRB));
    pIrb->FunctionNumber = REQUEST_ISOCH_QUERY_CYCLE_TIME;
    pIrb->Flags = 0;

    //
    // If we allocated this irp, submit it asynchronously and wait for its
    // completion event to be signaled.  Otherwise submit it synchronously
    //
    if (allocNewIrp) {

        KeInitializeEvent (&Event, NotificationEvent, FALSE);
        ntStatus = t1394_SubmitIrpAsync (deviceExtension->StackDeviceObject, newIrp, pIrb);

        if (ntStatus == STATUS_PENDING) {
            KeWaitForSingleObject (&Event, Executive, KernelMode, FALSE, NULL);
            ntStatus = ioStatus.Status;
        }
    }
    else {
        ntStatus = t1394_SubmitIrpSynch(deviceExtension->StackDeviceObject, Irp, pIrb);
    }

    if (NT_SUCCESS(ntStatus)) {

        *pCurrentCycleTime = pIrb->u.IsochQueryCurrentCycleTime.CycleTime;

        TRACE(TL_TRACE, ("CurrentCycleTime.CL_CycleOffset = 0x%x\n", pCurrentCycleTime->CL_CycleOffset));
        TRACE(TL_TRACE, ("CurrentCycleTime.CL_CycleCount = 0x%x\n", pCurrentCycleTime->CL_CycleCount));
        TRACE(TL_TRACE, ("CurrentCycleTime.CL_SecondCount = 0x%x\n", pCurrentCycleTime->CL_SecondCount));
    }
    else {

        TRACE(TL_ERROR, ("SubmitIrpSync failed = 0x%x\n", ntStatus));
    }

    ExFreePool(pIrb);

Exit_IsochQueryCurrentCycleTime:

    if (allocNewIrp)
        Irp->IoStatus = ioStatus;

    EXIT("t1394_IsochQueryCurrentCycleTime", ntStatus);
    return(ntStatus);
} // t1394_IsochQueryCurrentCycleTime

NTSTATUS
t1394_IsochQueryResources(
    IN PDEVICE_OBJECT   DeviceObject,
    IN PIRP             Irp,
    IN ULONG            fulSpeed,
    OUT PULONG          pBytesPerFrameAvailable,
    OUT PLARGE_INTEGER  pChannelsAvailable
    )
{
    NTSTATUS            ntStatus = STATUS_SUCCESS;
    PDEVICE_EXTENSION   deviceExtension = DeviceObject->DeviceExtension;
    PIRB                pIrb;

    PIRP                newIrp;
    BOOLEAN             allocNewIrp = FALSE;
    KEVENT              Event;
    IO_STATUS_BLOCK     ioStatus;

    ENTER("t1394_IsochQueryResources");

    TRACE(TL_TRACE, ("fulSpeed = 0x%x\n", fulSpeed));

    //
    // If this is a UserMode request create a newIrp so that the request
    // will be issued from KernelMode
    //
    if (Irp->RequestorMode == UserMode) {

        newIrp = IoBuildDeviceIoControlRequest (IOCTL_1394_CLASS, deviceExtension->StackDeviceObject,
                            NULL, 0, NULL, 0, TRUE, &Event, &ioStatus);

        if (!newIrp) {

            TRACE(TL_ERROR, ("Failed to allocate newIrp!\n"));
            ntStatus = STATUS_INSUFFICIENT_RESOURCES;
            goto Exit_IsochQueryResources;
        }
        allocNewIrp = TRUE;
    }

    pIrb = ExAllocatePool(NonPagedPool, sizeof(IRB));

    if (!pIrb) {

        TRACE(TL_ERROR, ("Failed to allocate pIrb!\n"));
        ntStatus = STATUS_INSUFFICIENT_RESOURCES;
        goto Exit_IsochQueryResources;
    } // if

    RtlZeroMemory (pIrb, sizeof (IRB));
    pIrb->FunctionNumber = REQUEST_ISOCH_QUERY_RESOURCES;
    pIrb->Flags = 0;
    pIrb->u.IsochQueryResources.fulSpeed = fulSpeed;

    //
    // If we allocated this irp, submit it asynchronously and wait for its
    // completion event to be signaled.  Otherwise submit it synchronously
    //
    if (allocNewIrp) {

        KeInitializeEvent (&Event, NotificationEvent, FALSE);
        ntStatus = t1394_SubmitIrpAsync (deviceExtension->StackDeviceObject, newIrp, pIrb);

        if (ntStatus == STATUS_PENDING) {
            KeWaitForSingleObject (&Event, Executive, KernelMode, FALSE, NULL);
            ntStatus = ioStatus.Status;
        }
    }
    else {
        ntStatus = t1394_SubmitIrpSynch(deviceExtension->StackDeviceObject, Irp, pIrb);
    }

    if (NT_SUCCESS(ntStatus)) {

        *pBytesPerFrameAvailable = pIrb->u.IsochQueryResources.BytesPerFrameAvailable;
        *pChannelsAvailable = pIrb->u.IsochQueryResources.ChannelsAvailable;

        TRACE(TL_TRACE, ("BytesPerFrameAvailable = 0x%x\n", *pBytesPerFrameAvailable));
        TRACE(TL_TRACE, ("ChannelsAvailable.LowPart = 0x%x\n", pChannelsAvailable->LowPart));
        TRACE(TL_TRACE, ("ChannelsAvailable.HighPart = 0x%x\n", pChannelsAvailable->HighPart));
    }
    else {

        TRACE(TL_ERROR, ("SubmitIrpSync failed = 0x%x\n", ntStatus));
    }

    ExFreePool(pIrb);

Exit_IsochQueryResources:

    if (allocNewIrp)
        Irp->IoStatus = ioStatus;

    EXIT("t1394_IsochQueryResources", ntStatus);
    return(ntStatus);
} // t1394_IsochQueryResources

NTSTATUS
t1394_IsochSetChannelBandwidth(
    IN PDEVICE_OBJECT   DeviceObject,
    IN PIRP             Irp,
    IN HANDLE           hBandwidth,
    IN ULONG            nMaxBytesPerFrame
    )
{
    NTSTATUS            ntStatus = STATUS_SUCCESS;
    PDEVICE_EXTENSION   deviceExtension = DeviceObject->DeviceExtension;
    PIRB                pIrb;

    PIRP                newIrp;
    BOOLEAN             allocNewIrp = FALSE;
    KEVENT              Event;
    IO_STATUS_BLOCK     ioStatus;

    ENTER("t1394_IsochSetChannelBandwidth");

    TRACE(TL_TRACE, ("hBandwidth = %p\n", hBandwidth));
    TRACE(TL_TRACE, ("nMaxBytesPerFrame = 0x%x\n", nMaxBytesPerFrame));

    //
    // If this is a UserMode request create a newIrp so that the request
    // will be issued from KernelMode
    //
    if (Irp->RequestorMode == UserMode) {

        newIrp = IoBuildDeviceIoControlRequest (IOCTL_1394_CLASS, deviceExtension->StackDeviceObject,
                            NULL, 0, NULL, 0, TRUE, &Event, &ioStatus);

        if (!newIrp) {

            TRACE(TL_ERROR, ("Failed to allocate newIrp!\n"));
            ntStatus = STATUS_INSUFFICIENT_RESOURCES;
            goto Exit_IsochSetChannelBandwidth;
        }
        allocNewIrp = TRUE;
    }

    pIrb = ExAllocatePool(NonPagedPool, sizeof(IRB));

    if (!pIrb) {

        TRACE(TL_ERROR, ("Failed to allocate pIrb!\n"));
        ntStatus = STATUS_INSUFFICIENT_RESOURCES;
        goto Exit_IsochSetChannelBandwidth;
    } // if

    RtlZeroMemory (pIrb, sizeof (IRB));
    pIrb->FunctionNumber = REQUEST_ISOCH_SET_CHANNEL_BANDWIDTH;
    pIrb->Flags = 0;
    pIrb->u.IsochSetChannelBandwidth.hBandwidth = hBandwidth;
    pIrb->u.IsochSetChannelBandwidth.nMaxBytesPerFrame = nMaxBytesPerFrame;

    //
    // If we allocated this irp, submit it asynchronously and wait for its
    // completion event to be signaled.  Otherwise submit it synchronously
    //
    if (allocNewIrp) {

        KeInitializeEvent (&Event, NotificationEvent, FALSE);
        ntStatus = t1394_SubmitIrpAsync (deviceExtension->StackDeviceObject, newIrp, pIrb);

        if (ntStatus == STATUS_PENDING) {
            KeWaitForSingleObject (&Event, Executive, KernelMode, FALSE, NULL);
            ntStatus = ioStatus.Status;
        }
    }
    else {
        ntStatus = t1394_SubmitIrpSynch(deviceExtension->StackDeviceObject, Irp, pIrb);
    }

    if (!NT_SUCCESS(ntStatus)) {

        TRACE(TL_ERROR, ("SubmitIrpSync failed = 0x%x\n", ntStatus));
    }

    ExFreePool(pIrb);

Exit_IsochSetChannelBandwidth:

    if (allocNewIrp)
        Irp->IoStatus = ioStatus;

    EXIT("t1394_IsochSetChannelBandwidth",  ntStatus);
    return(ntStatus);
} // t1394_IsochSetChannelBandwidth


NTSTATUS
t1394_IsochModifyStreamProperties(
    IN PDEVICE_OBJECT       DeviceObject,
    IN PIRP                 Irp,
    IN HANDLE               hResource,
    IN ULARGE_INTEGER       ChannelMask,
    IN ULONG                fulSpeed
    )
{
    NTSTATUS            ntStatus = STATUS_SUCCESS;
    PDEVICE_EXTENSION   deviceExtension = DeviceObject->DeviceExtension;
    PIRB                pIrb;

    PIRP                newIrp;
    BOOLEAN             allocNewIrp = FALSE;
    KEVENT              Event;
    IO_STATUS_BLOCK     ioStatus;

    //
    // If this is a UserMode request create a newIrp so that the request
    // will be issued from KernelMode
    //
    if (Irp->RequestorMode == UserMode) {

        newIrp = IoBuildDeviceIoControlRequest (IOCTL_1394_CLASS, deviceExtension->StackDeviceObject,
                            NULL, 0, NULL, 0, TRUE, &Event, &ioStatus);

        if (!newIrp) {

            TRACE(TL_ERROR, ("Failed to allocate newIrp!\n"));
            ntStatus = STATUS_INSUFFICIENT_RESOURCES;
            goto Exit_IsochModifyStreamProperties;
        }
        allocNewIrp = TRUE;
    }

    pIrb = ExAllocatePool(NonPagedPool, sizeof(IRB));

    if (!pIrb) {

        TRACE(TL_ERROR, ("Failed to allocate pIrb!\n"));
        ntStatus = STATUS_INSUFFICIENT_RESOURCES;
        goto Exit_IsochModifyStreamProperties;
    } // if

    RtlZeroMemory (pIrb, sizeof (IRB));
    pIrb->FunctionNumber = REQUEST_ISOCH_MODIFY_STREAM_PROPERTIES;
    pIrb->Flags = 0;
    pIrb->u.IsochModifyStreamProperties.hResource       = hResource;
    pIrb->u.IsochModifyStreamProperties.ChannelMask     = ChannelMask;
    pIrb->u.IsochModifyStreamProperties.fulSpeed        = fulSpeed;

    //
    // If we allocated this irp, submit it asynchronously and wait for its
    // completion event to be signaled.  Otherwise submit it synchronously
    //
    if (allocNewIrp) {

        KeInitializeEvent (&Event, NotificationEvent, FALSE);
        ntStatus = t1394_SubmitIrpAsync (deviceExtension->StackDeviceObject, newIrp, pIrb);

        if (ntStatus == STATUS_PENDING) {
            KeWaitForSingleObject (&Event, Executive, KernelMode, FALSE, NULL);
            ntStatus = ioStatus.Status;
        }
    }
    else {
        ntStatus = t1394_SubmitIrpSynch(deviceExtension->StackDeviceObject, Irp, pIrb);
    }

    if (!NT_SUCCESS(ntStatus)) {

        TRACE(TL_ERROR, ("SubmitIrpSync failed = 0x%x\n", ntStatus));
    }

    ExFreePool(pIrb);

Exit_IsochModifyStreamProperties:

    if (allocNewIrp)
        Irp->IoStatus = ioStatus;

    EXIT("t1394_IsochModifyStreamProperties", ntStatus);
    return ntStatus;
}

NTSTATUS
t1394_IsochStop(
    IN PDEVICE_OBJECT   DeviceObject,
    IN PIRP             Irp
    )
{
    NTSTATUS            ntStatus = STATUS_SUCCESS;
    PDEVICE_EXTENSION   deviceExtension = DeviceObject->DeviceExtension;
    PIRB                pIrb;
  PCAMERA_STATE cameraState = &(deviceExtension->CameraState);
    PIRP                newIrp;
    BOOLEAN             allocNewIrp = FALSE;
    KEVENT              Event;
    IO_STATUS_BLOCK     ioStatus;
    HANDLE           hResource;
    ULONG            fulFlags;

    ENTER("t1394_IsochStop");

    hResource = cameraState->hIsochResource;
    fulFlags = 0;

    TRACE(TL_TRACE, ("hResource = %p\n", hResource));
    TRACE(TL_TRACE, ("fulFlags = 0x%x\n", fulFlags));

    //
    // If this is a UserMode request create a newIrp so that the request
    // will be issued from KernelMode
    //
    if (Irp->RequestorMode == UserMode) {

        newIrp = IoBuildDeviceIoControlRequest (IOCTL_1394_CLASS, deviceExtension->StackDeviceObject,
                            NULL, 0, NULL, 0, TRUE, &Event, &ioStatus);

        if (!newIrp) {

            TRACE(TL_ERROR, ("Failed to allocate newIrp!\n"));
            ntStatus = STATUS_INSUFFICIENT_RESOURCES;
            goto Exit_IsochStop;
        }
        allocNewIrp = TRUE;
    }

    pIrb = ExAllocatePool(NonPagedPool, sizeof(IRB));

    if (!pIrb) {

        TRACE(TL_ERROR, ("Failed to allocate pIrb!\n"));
        ntStatus = STATUS_INSUFFICIENT_RESOURCES;
        goto Exit_IsochStop;
    } // if

    RtlZeroMemory (pIrb, sizeof (IRB));
    pIrb->FunctionNumber = REQUEST_ISOCH_STOP;
    pIrb->Flags = 0;
    pIrb->u.IsochStop.hResource = hResource;
    pIrb->u.IsochStop.fulFlags = fulFlags;

    //
    // If we allocated this irp, submit it asynchronously and wait for its
    // completion event to be signaled.  Otherwise submit it synchronously
    //
    if (allocNewIrp) {

        KeInitializeEvent (&Event, NotificationEvent, FALSE);
        ntStatus = t1394_SubmitIrpAsync (deviceExtension->StackDeviceObject, newIrp, pIrb);

        if (ntStatus == STATUS_PENDING) {
            KeWaitForSingleObject (&Event, Executive, KernelMode, FALSE, NULL);
            ntStatus = ioStatus.Status;
        }
    }
    else {
        ntStatus = t1394_SubmitIrpSynch(deviceExtension->StackDeviceObject, Irp, pIrb);
    }

    if (!NT_SUCCESS(ntStatus)) {

        TRACE(TL_ERROR, ("SubmitIrpSync failed = 0x%x\n", ntStatus));
    }

    ExFreePool(pIrb);

Exit_IsochStop:

    if (allocNewIrp)
        Irp->IoStatus = ioStatus;

  if(NT_SUCCESS(ntStatus))
  {
    DbgPrint("Stop Listening: pfoListenObject = %p\n",deviceExtension->pfoListenObject);
    deviceExtension->bListening = 0;
    deviceExtension->pfoListenObject = NULL;
  }

    EXIT("t1394_IsochStop", ntStatus);
    return(ntStatus);
} // t1394_IsochStop

NTSTATUS
t1394_IsochTalk(
    IN PDEVICE_OBJECT   DeviceObject,
    IN PIRP             Irp,
    IN HANDLE           hResource,
    IN ULONG            fulFlags,
    CYCLE_TIME          StartTime
    )
{
    NTSTATUS            ntStatus = STATUS_SUCCESS;
    PDEVICE_EXTENSION   deviceExtension = DeviceObject->DeviceExtension;
    PIRB                pIrb;

    PIRP                newIrp;
    BOOLEAN             allocNewIrp = FALSE;
    KEVENT              Event;
    IO_STATUS_BLOCK     ioStatus;

    ENTER("t1394_IsochTalk");

    TRACE(TL_TRACE, ("hResource = %p\n", hResource));
    TRACE(TL_TRACE, ("fulFlags = 0x%x\n", fulFlags));
    TRACE(TL_TRACE, ("StartTime.CL_CycleOffset = 0x%x\n", StartTime.CL_CycleOffset));
    TRACE(TL_TRACE, ("StartTime.CL_CycleCount = 0x%x\n", StartTime.CL_CycleCount));
    TRACE(TL_TRACE, ("StartTime.CL_SecondCount = 0x%x\n", StartTime.CL_SecondCount));

    //
    // If this is a UserMode request create a newIrp so that the request
    // will be issued from KernelMode
    //
    if (Irp->RequestorMode == UserMode) {

        newIrp = IoBuildDeviceIoControlRequest (IOCTL_1394_CLASS, deviceExtension->StackDeviceObject,
                            NULL, 0, NULL, 0, TRUE, &Event, &ioStatus);

        if (!newIrp) {

            TRACE(TL_ERROR, ("Failed to allocate newIrp!\n"));
            ntStatus = STATUS_INSUFFICIENT_RESOURCES;
            goto Exit_IsochTalk;
        }
        allocNewIrp = TRUE;
    }

    pIrb = ExAllocatePool(NonPagedPool, sizeof(IRB));

    if (!pIrb) {

        TRACE(TL_ERROR, ("Failed to allocate pIrb!\n"));
        ntStatus = STATUS_INSUFFICIENT_RESOURCES;
        goto Exit_IsochTalk;
    } // if

    RtlZeroMemory (pIrb, sizeof (IRB));
    pIrb->FunctionNumber = REQUEST_ISOCH_TALK;
    pIrb->Flags = 0;
    pIrb->u.IsochTalk.hResource = hResource;
    pIrb->u.IsochTalk.fulFlags = fulFlags;
    pIrb->u.IsochTalk.StartTime = StartTime;

    //
    // If we allocated this irp, submit it asynchronously and wait for its
    // completion event to be signaled.  Otherwise submit it synchronously
    //
    if (allocNewIrp) {

        KeInitializeEvent (&Event, NotificationEvent, FALSE);
        ntStatus = t1394_SubmitIrpAsync (deviceExtension->StackDeviceObject, newIrp, pIrb);

        if (ntStatus == STATUS_PENDING) {
            KeWaitForSingleObject (&Event, Executive, KernelMode, FALSE, NULL);
            ntStatus = ioStatus.Status;
        }
    }
    else {
        ntStatus = t1394_SubmitIrpSynch(deviceExtension->StackDeviceObject, Irp, pIrb);
    }

    if (!NT_SUCCESS(ntStatus)) {

        TRACE(TL_ERROR, ("SubmitIrpSync failed = 0x%x\n", ntStatus));
    }

    ExFreePool(pIrb);

Exit_IsochTalk:

    if (allocNewIrp)
        Irp->IoStatus = ioStatus;

    EXIT("t1394_IsochTalk", ntStatus);
    return(ntStatus);
} // t1394_IsochTalk

void
t1394_IsochCallback(
    IN PDEVICE_EXTENSION    DeviceExtension,
    IN PISOCH_DETACH_DATA   IsochDetachData
    )
{
    KIRQL               Irql;

    ENTER("t1394_IsochCallback");

    if (!IsochDetachData)
    {
      TRACE(TL_ERROR,("IsochCallback with NULL DetachData"));
      return;
    }

    // make sure somebody else isn't already handling cleaning up for this request
    KeAcquireSpinLock(&DeviceExtension->IsochSpinLock, &Irql);
    if ((!DeviceExtension->bShutdown) && (t1394_IsOnList(&IsochDetachData->IsochDetachList, &DeviceExtension->IsochDetachData)))
    {

        RemoveEntryList(&IsochDetachData->IsochDetachList);

        TRACE(TL_TRACE, (_TP("IsochCallback: IsochDetachData = %p\n"), IsochDetachData));
        TRACE(TL_TRACE, (_TP("IsochCallback: IsochDetachData->Irp = %p\n"), IsochDetachData->Irp));
        TRACE(TL_TRACE, (_TP("IsochCallback: IsochDetachData->newIrp = %p\n"), IsochDetachData->newIrp));
        TRACE(TL_TRACE, (_TP("IsochCallback: IsochDetachData->descriptor = %p\n"), IsochDetachData->IsochDescriptor));

		if(IsochDetachData->IsochDescriptor != NULL)
		{
			TRACE(TL_CHECK,(_TP("IsochCallBack: IsochDescriptor.CycleTime is %08x\n"),*((ULONG *)(&IsochDetachData->IsochDescriptor->CycleTime))));
			/*
			 * Note to self: if I can ever figure out why CycleTime is Always set to zero, I can use
			 * this to add CycleTime to the end of the frame buffer
			 */
			/*
			if(pData = (unsigned char *) MmGetSystemAddressForMdl(IsochDetachData->IsochDescriptor->Mdl))
			{
				unsigned char *pData;
				pData[0] = pData[1] = pData[2] = pData[3] = 255;
			}
			*/
		}
        // need to save the status of the attach
        // we'll clean up in the same spot for success's and timeout's
        IsochDetachData->AttachStatus = IsochDetachData->Irp->IoStatus.Status;
        t1394_IsochCleanup(IsochDetachData);
    } else {
		TRACE(TL_WARNING, (_TP("IsochCallback: Entry %p not on List %p\n"),
			  &IsochDetachData->IsochDetachList, &DeviceExtension->IsochDetachData));
    }
    KeReleaseSpinLock(&DeviceExtension->IsochSpinLock, Irql);

    EXIT("t1394_IsochCallback", 0);
} // t1394_IsochCallback

void
t1394_IsochCleanup(
    IN PISOCH_DETACH_DATA   IsochDetachData
    )
{
  ULONG               i;
  PDEVICE_EXTENSION   DeviceExtension;

  ENTER("t1394_IsochCleanup");

  if (IsochDetachData == NULL)
  {
    TRACE(TL_ERROR,("IsochCleanup ERROR: NULL IsochDetachData\n"));
    goto _exit;
  }

  /* this whole notion of bDetach is a little utchy, but we'll keep it in case we
   * ever want to switch to circular buffer usage
   */
  if (IsochDetachData->bDetach) {
    PIRB                pIrb;
    NTSTATUS            ntStatus = STATUS_UNSUCCESSFUL;
    PIO_STACK_LOCATION  NextIrpStack;
    DeviceExtension = IsochDetachData->DeviceExtension;

    pIrb = ExAllocatePool(NonPagedPool, sizeof(IRB));
    if (!pIrb) {
      TRACE(TL_ERROR, ("Failed to allocate pIrb!\n"));
      TRACE(TL_WARNING, ("Can't detach buffer!\n"));
      ntStatus = STATUS_INSUFFICIENT_RESOURCES;
      goto _exit;
    }

    // save the irb in our detach data context
    IsochDetachData->DetachIrb = pIrb;

    RtlZeroMemory (pIrb, sizeof (IRB));
    pIrb->FunctionNumber = REQUEST_ISOCH_DETACH_BUFFERS;
    pIrb->Flags = 0;
    pIrb->u.IsochDetachBuffers.hResource = IsochDetachData->hResource;
    pIrb->u.IsochDetachBuffers.nNumberOfDescriptors = IsochDetachData->numIsochDescriptors;
    pIrb->u.IsochDetachBuffers.pIsochDescriptor = IsochDetachData->IsochDescriptor;

    NextIrpStack = IoGetNextIrpStackLocation(IsochDetachData->newIrp);
    NextIrpStack->MajorFunction = IRP_MJ_INTERNAL_DEVICE_CONTROL;
    NextIrpStack->Parameters.DeviceIoControl.IoControlCode = IOCTL_1394_CLASS;
    NextIrpStack->Parameters.Others.Argument1 = pIrb;

    IoSetCompletionRoutine( IsochDetachData->newIrp,
          t1394_IsochDetachCompletionRoutine,
          IsochDetachData,
          TRUE,
          TRUE,
          TRUE
          );

    IoCallDriver(DeviceExtension->StackDeviceObject, IsochDetachData->newIrp);
  } else {
    /* just call the completion routine directly to clean up the allocated
     * Stuff in IsochDetachData */
    t1394_IsochDetachCompletionRoutine(NULL,NULL,IsochDetachData);
  }
 _exit:
  EXIT("t1394_IsochCleanup", 0);
} // t1394_IsochCleanup

NTSTATUS
t1394_IsochDetachCompletionRoutine(
    IN PDEVICE_OBJECT       DeviceObject,
    IN PIRP                 Irp,
    IN PISOCH_DETACH_DATA   IsochDetachData
    )
{
    NTSTATUS        ntStatus;
    ULONG           i;

    ENTER("t1394_IsochDetachCompletionRoutine");
    TRACE(TL_CHECK,("DetachCompletion: DetachData at %p\n",IsochDetachData));
    if (!IsochDetachData)
    {
        // seems like we should do more here, but without IsochDetachData, we're toast
        TRACE(TL_WARNING, ("Invalid IsochDetachData\n"));
        goto _exit;
    }

    TRACE(TL_CHECK,("DetachCompletion: DetachIrb at %p\n",IsochDetachData->DetachIrb));
    TRACE(TL_CHECK,("DetachCompletion: AttachIrb at %p\n",IsochDetachData->AttachIrb));
    TRACE(TL_CHECK,("DetachCompletion: IsochDescriptor at %p\n",IsochDetachData->IsochDescriptor));
	TRACE(TL_CHECK,("DetachCompletion: IsochDescriptor->CycleTime = %u\n",IsochDetachData->IsochDescriptor->CycleTime));

    if (IsochDetachData->DetachIrb)
        ExFreePool(IsochDetachData->DetachIrb);

    if (IsochDetachData->AttachIrb)
        ExFreePool(IsochDetachData->AttachIrb);

    if (IsochDetachData->IsochDescriptor)
        ExFreePool(IsochDetachData->IsochDescriptor);

    IsochDetachData->Irp->IoStatus.Status = IsochDetachData->AttachStatus;

    // only set this if its a success...
    if (NT_SUCCESS(IsochDetachData->AttachStatus))
        IsochDetachData->Irp->IoStatus.Information = IsochDetachData->outputBufferLength;

    // Complete original Irp and free the one we allocated in
    // IsochAttachBuffers
    IoCompleteRequest(IsochDetachData->Irp, IO_NO_INCREMENT);

    IoFreeIrp (IsochDetachData->newIrp);

    // all done with IsochDetachData, lets deallocate it...
    ExFreePool(IsochDetachData);

_exit:
    ntStatus = STATUS_MORE_PROCESSING_REQUIRED;
    EXIT("t1394_IsochDetachCompletionRoutine", ntStatus);
    return ntStatus;
} // t1394_IsochDetachCompletionRoutine

NTSTATUS
t1394_IsochAttachCompletionRoutine(
    IN PDEVICE_OBJECT       DeviceObject,
    IN PIRP                 Irp,
    IN PISOCH_DETACH_DATA   IsochDetachData
    )
{
  PDEVICE_EXTENSION   DeviceExtension;
  NTSTATUS            ntStatus    = STATUS_SUCCESS;
  ULONG               i;
  KIRQL               Irql;

  ENTER("t1394_IsochAttachCompletionRoutine");

  if (!IsochDetachData)
  {
    TRACE(TL_ERROR,("AttachCompletionRoutine Called with NULL IsochDetachData?\n"));
    goto _exit;
  }

  if (!NT_SUCCESS(Irp->IoStatus.Status))
  {
    // make sure this irp is still on the device extension list, meaning no one else
    // has already handled this yet
    DeviceExtension = IsochDetachData->DeviceExtension;
    KeAcquireSpinLock(&DeviceExtension->IsochSpinLock, &Irql);
    if (t1394_IsOnList(&IsochDetachData->IsochDetachList, &DeviceExtension->IsochDetachData))
    {
      RemoveEntryList(&IsochDetachData->IsochDetachList);
      KeReleaseSpinLock(&DeviceExtension->IsochSpinLock, Irql);
    } else {
      // just bomb out here
      KeReleaseSpinLock(&DeviceExtension->IsochSpinLock, Irql);
      TRACE(TL_ERROR,("Unable to find IsochDetachData %p in DeviceExtension at %p\n",IsochDetachData,DeviceExtension));
      goto _exit;
    }
    TRACE(TL_ERROR, ("Isoch Attach Failed! = 0x%x\n", Irp->IoStatus.Status));
    ntStatus = Irp->IoStatus.Status;

    DeviceExtension = IsochDetachData->DeviceExtension;

    TRACE(TL_CHECK, ("IsochAttachCompletionRoutine: IsochDetachData = %p\n", IsochDetachData));
    TRACE(TL_CHECK, ("IsochAttachCompletionRoutine: IsochDetachData->Irp = %p\n", IsochDetachData->Irp));
    TRACE(TL_CHECK, ("IsochAttachCompletionRoutine: IsochDetachData->newIrp = %p\n", IsochDetachData->newIrp));
    TRACE(TL_CHECK, ("Now lets complete Irp.\n"));

    IsochDetachData->AttachStatus = Irp->IoStatus.Status;
    // IsochDetachCompletionRoutine will tear down IsochDetachData for us
    t1394_IsochDetachCompletionRoutine(DeviceObject,Irp,IsochDetachData);
  }

 _exit:

  EXIT("t1394_IsochAttachCompletionRoutine", ntStatus);
  return(STATUS_MORE_PROCESSING_REQUIRED);
} // t1394_IsochAttachCompletionRoutine

#define REQUEST_BUSY_RETRY_VALUE        (ULONG)(-100 * 100 * 100 * 100) //10 secs in units of 100nsecs

NTSTATUS
t1394Cmdr_IsochAttachBuffer(
          IN PDEVICE_OBJECT DeviceObject,
          IN PIRP Irp,
          IN PISOCH_BUFFER_PARAMS pBufferParams,
          OUT PMDL pMDL
          )
{
  NTSTATUS                    ntStatus = STATUS_SUCCESS;
  PDEVICE_EXTENSION           deviceExtension = DeviceObject->DeviceExtension;
  PCAMERA_STATE cameraState = &(deviceExtension->CameraState);
  CCHAR            StackSize;
  ULONG                       i;
  KIRQL                       Irql;
  PIO_STACK_LOCATION          NextIrpStack;
  /* this stuff gets allocated and must be freed on error */
  PIRP            newIrp = NULL;
  PIRB                        pIrb = NULL;
  PISOCH_DETACH_DATA          pIsochDetachData = NULL;
  PISOCH_DESCRIPTOR           pIsochDescriptor = NULL;

  /* some dummyproofing first... */
  if(deviceExtension->CameraState.hIsochResource == NULL)
  {
    TRACE(TL_ERROR, (_TP("AttachBuffer: you must use IOCTL_ISOCH_SETUP_STREAM first!\n")));
    ntStatus = STATUS_INSUFFICIENT_RESOURCES;
    goto _exit;
  }

  /* allocate our overhead */
  // Make us a new IRP so we can submit this asynchronously
  StackSize = deviceExtension->StackDeviceObject->StackSize + 1;

  if ((newIrp = IoAllocateIrp (StackSize, FALSE)) == NULL)
  {
    TRACE(TL_ERROR, (_TP("Failed to allocate newIrp!\n")));
    ntStatus = STATUS_INSUFFICIENT_RESOURCES;
    goto _exit;
  }

  // allocate the irb
  if((pIrb = ExAllocatePool(NonPagedPool, sizeof(IRB))) == NULL)
  {
    TRACE(TL_ERROR, (_TP("Failed to allocate pIrb!\n")));
    ntStatus = STATUS_INSUFFICIENT_RESOURCES;
    goto _exit;
  }

  // allocate isoch descriptor
  if((pIsochDescriptor = ExAllocatePool(NonPagedPool, sizeof(ISOCH_DESCRIPTOR))) == NULL)
  {
    TRACE(TL_ERROR, (_TP("Failed to allocate pIsochDescriptor!\n")));
    ntStatus = STATUS_INSUFFICIENT_RESOURCES;
    goto _exit;
  }

  // allocate detach data
  if((pIsochDetachData = ExAllocatePool(NonPagedPool, sizeof(ISOCH_DETACH_DATA))) == NULL)
  {
    TRACE(TL_ERROR, (_TP("Failed to allocate pIsochDetachData!\n")));
    ntStatus = STATUS_INSUFFICIENT_RESOURCES;
    goto _exit;
  }

  // now that the overhead has been allocated, start populating things

  // The isoch descriptor gets passed down to 1394bus to tell it where to put the data
  RtlZeroMemory (pIsochDescriptor,sizeof(ISOCH_DESCRIPTOR));

  // Point at the Userspace MDL
  pIsochDescriptor->Mdl = pMDL;
  pIsochDescriptor->ulLength = MmGetMdlByteCount(pIsochDescriptor->Mdl);

  // fill in elements of the Isochronoous Descriptor
  if(pBufferParams != NULL && (pBufferParams->ulFlags & ISOCH_BUFFER_SECONDARY))
  {
      // secondary buffers "sync" on SY==0
	  // note: the "fake" sync was not necessary pre-Win7, the new 1394 stack for Win7 seems to be more picky
	  // if I have to keep messing with this, I'm just going to export the flags directly to userspace...
      pIsochDescriptor->fulFlags = //DESCRIPTOR_SYNCH_ON_SY |
		                           //DESCRIPTOR_USE_SY_TAG_IN_FIRST |
		                           DESCRIPTOR_TIME_STAMP_ON_COMPLETION;
	  pIsochDescriptor->ulSynch = 0;
  } else {
	  // primary buffer syncs on first instance of SY==1
      pIsochDescriptor->fulFlags = DESCRIPTOR_SYNCH_ON_SY | 
								   DESCRIPTOR_TIME_STAMP_ON_COMPLETION;
	  pIsochDescriptor->ulSynch = 1;
  }
  pIsochDescriptor->nMaxBytesPerFrame = cameraState->IsochMaxBytesPerFrame;
  pIsochDescriptor->ulTag = 0;
  *(PULONG)(&pIsochDescriptor->CycleTime) = 0xdeadbeef;

  // fill in callback info
  pIsochDescriptor->Callback = t1394_IsochCallback;
  pIsochDescriptor->Context1 = deviceExtension;
  pIsochDescriptor->Context2 = pIsochDetachData;

  // The IRB is the actual argument to the 1394bus IOCTL
  RtlZeroMemory (pIrb, sizeof (IRB));
  pIrb->FunctionNumber = REQUEST_ISOCH_ATTACH_BUFFERS;
  pIrb->Flags = 0;
  pIrb->u.IsochAttachBuffers.hResource = cameraState->hIsochResource;
  pIrb->u.IsochAttachBuffers.nNumberOfDescriptors = 1;
  pIrb->u.IsochAttachBuffers.pIsochDescriptor = pIsochDescriptor;

  // IsochDetachData is used by Completion/Cancel/Timeout/Cleanup
  // We need to save hResource, numDescriptors and Irp to use when detaching.
  // this needs to be done before we submit the irp, since the isoch callback
  // can be called before the submitirpsynch call completes.
  RtlZeroMemory (pIsochDetachData, sizeof (ISOCH_DETACH_DATA));
  pIsochDetachData->AttachIrb = pIrb;
  pIsochDetachData->outputBufferLength = pIsochDescriptor->ulLength;
  pIsochDetachData->DeviceExtension = deviceExtension;
  pIsochDetachData->hResource = cameraState->hIsochResource;
  pIsochDetachData->numIsochDescriptors = 1;
  pIsochDetachData->IsochDescriptor = pIsochDescriptor;
  pIsochDetachData->Irp = Irp;
  pIsochDetachData->newIrp = newIrp;
  pIsochDetachData->bDetach = 1;

  // The IRP is for Internal IOCTL to 1394bus
  NextIrpStack = IoGetNextIrpStackLocation(newIrp);
  NextIrpStack->MajorFunction = IRP_MJ_INTERNAL_DEVICE_CONTROL;
  NextIrpStack->Parameters.DeviceIoControl.IoControlCode = IOCTL_1394_CLASS;
  NextIrpStack->Parameters.Others.Argument1 = pIrb;

  // Set our completion routine
  IoSetCompletionRoutine( newIrp,
        t1394_IsochAttachCompletionRoutine,
        pIsochDetachData,
        TRUE,
        TRUE,
        TRUE
        );

  // lets make sure the device is still around
  // if it isn't, we free the irb and return, our pnp
  // cleanup will take care of everything else
  if (!deviceExtension->bShutdown)
  {
    // now that the overhead is done with, grab the spinlock
    // push our detach data onto the device list
    KeAcquireSpinLock(&deviceExtension->IsochSpinLock, &Irql);
    InsertHeadList(&deviceExtension->IsochDetachData, &pIsochDetachData->IsochDetachList);
    KeReleaseSpinLock(&deviceExtension->IsochSpinLock, Irql);

    // The completion routine will take care of everything else, so mark our original irp pending
    IoMarkIrpPending(Irp);

    // Submit the newIrp directly to the driver below us
    ntStatus = IoCallDriver(deviceExtension->StackDeviceObject, newIrp);
    ntStatus = STATUS_PENDING;
  } else {
    // pnp/power mgmt beat us to it, so we skip the whole ordeal
    TRACE(TL_TRACE, (_TP("Not Attaching buffers while in Shutdown!\n")));
    ntStatus = STATUS_NO_SUCH_DEVICE;
  }

 _exit:
  if(!NT_SUCCESS(ntStatus))
  {
    // something failed

    if(pIsochDetachData)
      ExFreePool(pIsochDetachData);
    if(pIsochDescriptor)
      ExFreePool(pIsochDescriptor);
    if(pIrb)
      ExFreePool(pIrb);
    if(newIrp)
      IoFreeIrp(newIrp);
  }

  return(ntStatus);
} // t1394Cmdr_IsochAttachBuffer
