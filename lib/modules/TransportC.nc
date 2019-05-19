#include "../../includes/Structures.h"
#include "../../includes/socket.h"
#include "../../includes/am_types.h"
#include "../../includes/socket.h"

configuration TransportC{
	provides {
		interface Transport;
	}
}
implementation {
	components TransportP;
	Transport = TransportP.Transport;

	// List of other components
	components ForwardC;

	// Sender and Reciever
	TransportP.FdSender -> ForwardC.RouteSender;
	TransportP.FdReceiver -> ForwardC.RouteReceiver;

	// List of Timers
	components new TimerMilliC() as TransportTimer;
	components new TimerMilliC() as QueueTimer;
	components new TimerMilliC() as WaitTimer;

	TransportP.TransportTimer -> TransportTimer;
	TransportP.QueueTimer -> QueueTimer;
	TransportP.WaitTimer -> WaitTimer;

	// List of Data	
	components new QueueC(pack, 64) as SendQueue;
	components new ListC(socket_t, MAX_NUM_OF_SOCKETS) as socketList;
	components new HashmapC(socket_store_t, MAX_NUM_OF_SOCKETS) as Map;	// NEEDS TO BE A POINTER

	TransportP.SendQueue -> SendQueue;
	TransportP.socketList -> socketList;
	TransportP.Map -> Map;

	components RandomC as Random;
	TransportP.Random -> Random;
}
