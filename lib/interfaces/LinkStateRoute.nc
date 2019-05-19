#include "../../includes/Structures.h"

interface LinkStateRoute {
	command void Start();
	command void PrintRoutingTable();
	command void PrintLinkState();
	command uint16_t getNextHop(uint16_t dest);
}

