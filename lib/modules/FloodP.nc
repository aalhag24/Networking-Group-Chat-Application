// This is the Module for the Flood Configuration file
#include "../../includes/packet.h"
#include "../../includes/channels.h"
#include "../../includes/protocol.h"

#include "../../includes/Structures.h"

module FloodP {
	uses {
		interface Receive as Reciever;
		interface SimpleSend as Sender;
		interface List<pack> as Storage;
	}
	provides {
		interface SimpleSend as FSend; 
		interface Receive as FReceive; 
	}
}
implementation {
	pack sendPackage;
	uint16_t sequence = 0;
	uint16_t NumElem = 0;
	const uint8_t SIZE = 64;
	
//Prototypes
	void makePack(pack *Pkg,uint16_t src,uint16_t dest,uint16_t TTL,uint16_t Protocol,uint16_t seq, uint8_t *payload, uint8_t length);
	bool Contains(pack *Pkg);
	void pushPack(pack Pkg);

// COMMAND ERROR_R FSEND.SEND(PACK MSG, UINT16_T DEST)
	command error_t FSend.send(pack msg, uint16_t dest) {
		makePack(&sendPackage,TOS_NODE_ID,dest,MAX_TTL,PROTOCOL_PING,0,(uint8_t*)msg.payload, PACKET_MAX_PAYLOAD_SIZE);
		dbg(FLOODING_CHANNEL, "Fsend from: (%u)\n", msg.src);
		call Sender.send(sendPackage, AM_BROADCAST_ADDR);
	}

// EVENT MESSAGE_T* RECIEVER.RECEIVE(MESSAGE_T *RAW_MSG, VOID*PAYLOAD, UINT8_T LEN)
	event message_t* Reciever.receive(message_t *raw_msg, void*payload, uint8_t len){
		if(len==sizeof(pack)){
			pack* msg=(pack*) payload;

			if(Contains(msg) || (msg->TTL == 0)){
           		return raw_msg; 	// DROP THA PACKAGE BY DOING NOTHING
         	}

			if(msg->dest != TOS_NODE_ID){ 
				//dbg(FLOODING_CHANNEL, "Node ID:%d\n", TOS_NODE_ID);
                makePack(&sendPackage,msg->src,msg->dest,msg->TTL-1,msg->protocol,msg->seq,(uint8_t*)msg->payload,sizeof(msg->payload));
                dbg(FLOODING_CHANNEL,"Flooding from %d to %d, TTL:%d \n",TOS_NODE_ID, msg->dest, msg->TTL);

                pushPack(sendPackage);		                //PUT PACKET INTO LIST AND FLODD AGAIN
                call Sender.send(sendPackage, AM_BROADCAST_ADDR);
			}
			else if(msg->dest == TOS_NODE_ID){
				if(msg->protocol == PROTOCOL_PING){
					dbg(FLOODING_CHANNEL, "Ping From %d! to %d!\n", msg->src, msg->dest);
					dbg(FLOODING_CHANNEL, "MSG Delivered: %s!\n\n", msg->payload);

					makePack(&sendPackage,TOS_NODE_ID,msg->src,MAX_TTL,PROTOCOL_PINGREPLY,0,(uint8_t*)msg->payload,sizeof(msg->payload));
					sequence++; 
					pushPack(sendPackage);
					call Sender.send(sendPackage, AM_BROADCAST_ADDR);
					return raw_msg;
				}
				else if(msg->protocol == PROTOCOL_PINGREPLY){ 
					dbg(FLOODING_CHANNEL, "FINISHED Ping reply from Node: %d!\n", msg->src);
					dbg(FLOODING_CHANNEL, "MSG Delivered: %s!\n\n", msg->payload);
                    msg->TTL = 0;
				}
			}
			return raw_msg;
		}
		dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
		return raw_msg;
	}


/// PROTOTYPE FUNCTION IMPLEMENTATION
// VOID MAKEPACK
	void makePack(pack *Pkg,uint16_t src,uint16_t dest,uint16_t TTL,uint16_t protocol,uint16_t seq, uint8_t* payload,uint8_t length){
      Pkg->src = src;
      Pkg->dest = dest;
      Pkg->TTL = TTL;
      Pkg->seq = seq;
      Pkg->protocol = protocol;
      memcpy(Pkg->payload, payload, length);
   }

// BOOL CONTAINS(PACK *PKG)
	bool Contains(pack *Pkg) {
		uint16_t i;
		uint16_t size = call Storage.size();
		pack tmp;

		for (i=0; i<size; i++) {
			tmp = call Storage.get(i);
			if((tmp.src == Pkg->src) && (tmp.dest == Pkg->dest) && (tmp.seq == Pkg->seq)) {
				return TRUE;
			}
		}
		return FALSE;
	}

// VOID PUSHPACK(PACK PKG)
	void pushPack(pack Pkg) {
		//if (call Storage.isFull()) {
			//call Storage.popfront();
		//}
		call Storage.pushback(Pkg);
	}
}


















