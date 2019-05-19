/*
Link State Routing Table
*/
#include "../../includes/am_types.h"

configuration LinkStateRouteC{
	provides {
		interface LinkStateRoute;
		//interface SimpleSend as RouteSender;
		//interface Receive as RouteReceiver;
	}
}
implementation {
	components LinkStateRouteP;
	components NeighborDiscoveryC;
	//components ForwardC;

	components new SimpleSendC(AM_ROUTING);
	components new AMReceiverC(AM_ROUTING);
	components new TimerMilliC() as RouteTimer;

	// Implamentation of Neighbor Discovery
	LinkStateRouteP.NeighborDiscovery -> NeighborDiscoveryC;
	//LinkStateRouteP.Forward -> ForwardC;
	LinkStateRoute = LinkStateRouteP.LinkStateRoute;

	LinkStateRouteP.RSender -> SimpleSendC;
	LinkStateRouteP.RReceiver -> AMReceiverC;
	LinkStateRouteP.RouteTimer -> RouteTimer;

	// Data storage
	//components new HashmapC(LinkState, 20) as Table;
	//LinkStateRouteP.Table -> Table;

	components new ListC(LinkState, 20) as NeighborList;
	LinkStateRouteP.LON -> NeighborList;
	components new ListC(uint8_t, 20) as ProcessedList;
	LinkStateRouteP.LOP -> ProcessedList;
}
