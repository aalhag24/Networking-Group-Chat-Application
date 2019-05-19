/**
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */

#include <Timer.h>
#include "includes/CommandMsg.h"
#include "includes/packet.h"
#include "includes/socket.h"

configuration NodeC{
}
implementation {
    components MainC;
    components Node;
    components new AMReceiverC(AM_PACK) as GeneralReceive;

    Node -> MainC.Boot;

    Node.Receive -> GeneralReceive;

    components ActiveMessageC;
    Node.AMControl -> ActiveMessageC;

    components new SimpleSendC(AM_PACK);
    Node.Sender -> SimpleSendC;

    components CommandHandlerC;
    Node.CommandHandler -> CommandHandlerC;


/// THING I ADDED
	components new TimerMilliC() as periodicTimer;	//create a new timer with alias “myTimerC”
	Node.periodicTimer -> periodicTimer;

	// Flood - Unused
	//components FloodC;
	//Node.FSender -> FloodC.FSend;
	//Node.FReceiver -> FloodC.FReceive;

	// NeighborDiscovery - Unused
	components NeighborDiscoveryC;
	Node.NeighborDiscovery -> NeighborDiscoveryC.NeighborDiscovery;

	// Link State Routing
	components LinkStateRouteC;
	Node.Router -> LinkStateRouteC.LinkStateRoute;

	// Forward - Unused
	//components ForwardC;
	//Node.FdSender -> ForwardC.RouteSender;
	//Node.FdReceiver -> ForwardC.RouteReceiver;

	// Transport
	components TransportC;
	components new ListC(app_chat_t, MAX_NUM_OF_APPLICATIONS) as appList;
	Node.Transport -> TransportC.Transport;
	Node.appList -> appList;
}













