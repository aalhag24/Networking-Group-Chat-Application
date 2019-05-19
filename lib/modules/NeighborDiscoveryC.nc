#include "../../includes/Structures.h"
#include "../../includes/am_types.h"

configuration NeighborDiscoveryC {
	provides interface NeighborDiscovery;
}
implementation {
	// Connect with the P module file
	components NeighborDiscoveryP;
	NeighborDiscovery = NeighborDiscoveryP.NeighborDiscovery;

	// Reciever and Sender
	components new AMReceiverC(AM_NEIGHBORDISCOVERY);
	components new SimpleSendC(AM_NEIGHBORDISCOVERY);
	components new TimerMilliC() as NDTimer;

	NeighborDiscoveryP.NDReceiver -> AMReceiverC;
	NeighborDiscoveryP.NDSender -> SimpleSendC;
	NeighborDiscoveryP.NDTimer -> NDTimer;

	// List of Data
	components new ListC(pack, 20) as NeighborList;
	components new ListC(pack, 20) as PackageList;

	NeighborDiscoveryP.LON -> NeighborList;
	NeighborDiscoveryP.LOP -> PackageList;
}
