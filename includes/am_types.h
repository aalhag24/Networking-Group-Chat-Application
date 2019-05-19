#include "packet.h"
#include "CommandMsg.h"

#ifndef __AM_TYPES_H__
#define __AM_TYPES_H__
enum{
    AM_FLOODING=10,
	AM_NEIGHBORDISCOVERY=20,
	AM_FORWARD=30,
	AM_ROUTING=40,
	AM_TRANSPORT=50
};
#endif
