#ifndef _EMU48_PCH_H_
#define _EMU48_PCH_H_
/*
 *  pch.h
 *  emu48
 *
 *  Created by dwjung on 2009-01-11.
 *  Copyright 2009 Da Woon Jung. All rights reserved.
 *
 */

#import <sys/param.h>
#import <stdlib.h>

#ifdef NDEBUG
#define _ASSERT(a)
#else
#include <assert.h>
#define _ASSERT(a)   assert(a)
#endif

#if !defined VERIFY
#ifdef NDEBUG
#define VERIFY(f)			((void)(f))
#else
#define VERIFY(f)			_ASSERT(f)
#endif
#endif // _VERIFY

typedef size_t DWORD_PTR, *PDWORD_PTR;

#undef MIN
#undef MAX

#ifdef __BIG_ENDIAN__
#define _BIGENDIAN
#endif

#import "MacWinAPIPatch.h"

#endif
