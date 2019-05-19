//Author: UCM ANDES Lab
//$Author: abeltran2 $
//$LastChangedBy: abeltran2 $

#ifndef PACKET_H
#define PACKET_H


#include "protocol.h"
#include "channels.h"

enum{
	PACKET_HEADER_LENGTH = 8,
	PACKET_MAX_PAYLOAD_SIZE = 28 - PACKET_HEADER_LENGTH,
	MAX_TTL = 24
};

enum{
	TCP_PACKET_HEADER_LENGTH = 6,
	TCP_PACKET_MAX_PAYLOAD_SIZE = PACKET_MAX_PAYLOAD_SIZE - TCP_PACKET_HEADER_LENGTH
};


typedef nx_struct pack{
	nx_uint16_t dest;
	nx_uint16_t src;
	nx_uint16_t seq;		//Sequence Number
	nx_uint8_t TTL;		//Time to Live
	nx_uint8_t protocol;
	nx_uint8_t payload[PACKET_MAX_PAYLOAD_SIZE];
}pack;


typedef nx_struct TCP_pack{
	nx_uint8_t dest_port;
	nx_uint8_t src_port;
	nx_uint8_t seq;		//Sequence Number
	nx_uint8_t ACK;
	nx_uint8_t Flag;
	nx_uint8_t Window;
	nx_uint8_t payload[TCP_PACKET_MAX_PAYLOAD_SIZE];
}TCP_pack;

/*
 * logPack
 * 	Sends packet information to the general channel.
 * @param:
 * 		pack *input = pack to be printed.
 */
void logPack(pack *input){
	dbg(GENERAL_CHANNEL, "Src: %hu Dest: %hu Seq: %hu TTL: %hhu Protocol:%hhu  Payload: %s\n",
	input->src, input->dest, input->seq, input->TTL, input->protocol, input->payload);
}

void logTCPPack(TCP_pack *input){
	dbg(GENERAL_CHANNEL, "Src: %hhu Dest: %hhu Seq: %hhu ACK:%hhu FLAG:%hhu Window:%hhu Payload: %s\n",
	input->src_port, input->dest_port, input->seq, input->ACK, input->Flag, input->Window, input->payload);
}

enum{
	AM_PACK=6
};

#endif
