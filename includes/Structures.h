#ifndef STRUCTURES_H
#define STRUCTURES_H

// Because a lot of files use this struct
// NOTE TO SELF - FOR TESTING PURPOSES ONLY

typedef struct AdjNeighbor{
	uint16_t ID;		// Identification
	uint8_t TTL;		// Time to Live
} AdjNeighbor;

typedef struct Data { 	// Old package that have been seen
	uint16_t src;
	uint16_t seq;
};

typedef struct LinkState {		// Information for Routing
	uint8_t ID;
	uint8_t Hop;
	uint8_t Cost;
} LinkState;

typedef struct RouteTable {
	nx_uint8_t DestCost[PACKET_MAX_PAYLOAD_SIZE];
} RouteTable;
#endif;
