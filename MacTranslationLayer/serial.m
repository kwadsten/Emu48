//
//  serial.m
//  emu48
//
//  Created by Da Woon Jung on 2009-01-21
//  Copyright 2009 Da Woon Jung. All rights reserved.
//

#import "pch.h"
#import "EMU48.H"
#import "IO.H"

#define INTERRUPT ((void)(Chipset.SoftInt=TRUE,bInterrupt=TRUE))

// state of USRQ
#define NINT2ERBZ ((Chipset.IORam[IOC] & (SON | ERBZ)) == (SON | ERBZ) && (Chipset.IORam[RCS] & RBZ) != 0)
#define	NINT2ERBF ((Chipset.IORam[IOC] & (SON | ERBF)) == (SON | ERBF) && (Chipset.IORam[RCS] & RBF) != 0)
#define NINT2ETBE ((Chipset.IORam[IOC] & (SON | ETBE)) == (SON | ETBE) && (Chipset.IORam[TCS] & TBF) == 0)

#define NINT2USRQ (NINT2ERBZ || NINT2ERBF || NINT2ETBE)


BOOL CommOpen(LPTSTR strWirePort,LPTSTR strIrPort)
{
    return YES;
}

VOID CommClose(VOID)
{
}

VOID CommSetBaud(VOID)
{
}

BOOL UpdateUSRQ(VOID)						// USRQ handling
{
	BOOL bUSRQ = NINT2USRQ;
	IOBit(SRQ1,USRQ,bUSRQ);					// update USRQ bit
	return bUSRQ;
}

VOID CommTxBRK(VOID)
{
}
    
VOID CommTransmit(VOID)
{
	Chipset.IORam[TCS] &= (~TBF);			// clear transmit buffer
	if (UpdateUSRQ())						// update USRQ bit
		INTERRUPT;
}

VOID CommReceive(VOID)
{
    if (UpdateUSRQ())					// update USRQ bit
        INTERRUPT;
}

