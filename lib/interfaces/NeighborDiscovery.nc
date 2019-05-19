#include "../../includes/Structures.h"
#include "../../includes/packet.h"

// pg 36 Tos programming web
// Copied from the SimpleSend.nc file
interface NeighborDiscovery {
	command void Start();
	command void Print();

	//command Hashmap<AdjNeighbor> getList();
	command uint8_t* getList();
	command uint8_t getSize();
}
