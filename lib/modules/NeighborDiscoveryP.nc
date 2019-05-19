#include "../../includes/packet.h"
#include "../../includes/channels.h"
#include "../../includes/protocol.h"
#include "../../includes/Structures.h"

const uint8_t SIZE = 255;
uint16_t NumElem = 15;
uint16_t sequence = 0;
char* MSG = "Neighbor Discovery";
uint16_t tempSize;

module NeighborDiscoveryP{
	uses {
		interface Receive as NDReceiver;
		interface SimpleSend as NDSender;
		interface Timer<TMilli> as NDTimer;

		interface List<pack> as LON;
		interface List<pack> as LOP;
	}

	provides { 
		interface NeighborDiscovery;
	}
}
implementation {
	pack sendPackage;

	// Prototypes - Took from Node.nc
	void makePack(pack *Package,uint16_t src,uint16_t dest,uint16_t TTL,uint16_t Protocol,uint16_t seq,uint8_t *payload,uint8_t length);
	bool compPack(pack *Package);
	void shovePack(pack Package);

// COMMAND VOID NEIGHBORDISCOVERY.START()
	command void NeighborDiscovery.Start(){
		//dbg(NEIGHBOR_CHANNEL, "Begining of the Neighbor Discovery Process\n");

		//makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, 20, PROTOCOL_PING, 0, "Neighbor Discovery", PACKET_MAX_PAYLOAD_SIZE);
		//call NDSender.send(sendPackage, sendPackage.dest);
		call NDTimer.startPeriodic(1000);
	}

// EVENT VOID NDTIMER.FIRED()
	event void NDTimer.fired(){
		//dbg(NEIGHBOR_CHANNEL, "Starting Neighbor Discovery Timer\n");
		makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, 20, PROTOCOL_ND, sequence, (uint8_t*)MSG, PACKET_MAX_PAYLOAD_SIZE);
		call NDSender.send(sendPackage, AM_BROADCAST_ADDR);
	}

// EVENT MESSAGE_T* NDRECEIVE.RECEIVE(MESSAGE_T* RAW_MSG, VOID* PAYLOAD, UINT8_T LENGTH)
	event message_t* NDReceiver.receive(message_t* raw_msg, void* payload, uint8_t length){
		uint16_t Size = call LON.size();
		pack* msg=(pack*) payload;
		
		//dbg(NEIGHBOR_CHANNEL, "Recieved packet from (%u) as (%u)\n", msg->src, TOS_NODE_ID);
		if(length==sizeof(pack)){
			if(NumElem == 0 && !call LON.isEmpty()){
				uint16_t j;
            	for(j = 0; j < Size; j++){
                	call LON.popfront();
            	}
            	NumElem = 15;
			}
			if(compPack(msg) || (msg->TTL == 0)){
				return raw_msg;
			}


			if(msg->TTL == 0){
				//dbg(FLOODING_CHANNEL,"TTL expired for packet seq:(%u) from (%u)\n", msg->seq, msg->src);
			}
			if(msg->protocol == PROTOCOL_ND){     
				uint16_t j;
				bool FOUND = FALSE;
				pack tmp;
				//AdjNeighbor TempNeigh;

				call NDSender.send(sendPackage, AM_BROADCAST_ADDR); 
				
				for(j = 0; j < Size; j++){
					tmp = call LON.get(j);
					if(tmp.src == msg->src){
						NumElem--;
						return raw_msg;
					}else{
						call NDSender.send(sendPackage, AM_BROADCAST_ADDR);
					}
				}
				call LON.pushback(*msg); 
				NumElem--;

				//call NeighborDiscovery.Print();
				return raw_msg;
			} else if(msg->dest != TOS_NODE_ID){ 
				//dbg(FLOODING_CHANNEL, "Node ID: %d\n", TOS_NODE_ID);

                makePack(&sendPackage,msg->src,msg->dest,msg->TTL-1,msg->protocol,msg->seq,(uint8_t*)msg->payload,sizeof(msg->payload));
                //dbg(FLOODING_CHANNEL, "Obtained package from %d going to %d, TTL: %d, Flooding...\n\n",msg->src,msg->dest,msg->TTL);

                shovePack(sendPackage);
                call NDSender.send(sendPackage, AM_BROADCAST_ADDR);
			} else if(msg->dest == TOS_NODE_ID){
				if(msg->protocol == PROTOCOL_PING){
					//dbg(FLOODING_CHANNEL, "Yes!!!! From %d! to %d!\n", msg->src, msg->dest);
					//dbg(FLOODING_CHANNEL, "Package at destination. Payload: %s\n", msg->payload);
		makePack(&sendPackage,TOS_NODE_ID,msg->src, MAX_TTL-1,PROTOCOL_PINGREPLY,sequence,(uint8_t*)msg->payload,sizeof(msg->payload));
					sequence++; 

					shovePack(sendPackage);
					call NDSender.send(sendPackage, AM_BROADCAST_ADDR);
					return raw_msg;
				} else if(msg->protocol == PROTOCOL_PINGREPLY){ 
					//uint8_t j;
					//pack tmp;
					//bool FOUND = FALSE;

					//dbg(FLOODING_CHANNEL, "Obtained ping reply from Node: (%d)!\n\n", msg->src);
					msg->TTL = 0;
                }
			} else if(msg->dest == AM_BROADCAST_ADDR){
				//dbg(NEIGHBOR_CHANNEL, "\t\tEnding the recieving dest (%u)\n", msg->dest);
				msg->dest = msg->src;
				msg->src = TOS_NODE_ID;
				msg->protocol = PROTOCOL_PINGREPLY;
				call NDSender.send(*msg, msg->dest);
			}

			//dbg(NEIGHBOR_CHANNEL, "\t\tEnding the recieving dest (%u)\n", msg->dest);
			return raw_msg;
		}
		//dbg(NEIGHBOR_CHANNEL, "Unknown Packet Type (%d)\n", length);
      	return raw_msg;
	}
	
// COMMAND VOID NEIGHBORDISCOVERY.PRINT()
	command void NeighborDiscovery.Print() {
		uint32_t Index; // Index must be uint32_t
		uint16_t Size;
		pack temp;

		Size = call LON.size();
		if(Size == 0) {
			//dbg(NEIGHBOR_CHANNEL, "No Neighbors in list\n");
		} 
		else {
			dbg(NEIGHBOR_CHANNEL, "Printing Neighbors for (%u)\n", TOS_NODE_ID);
			for(Index=0; Index < Size; Index++){
				temp = call LON.get(Index);
				if(temp.src != 0){
					//dbg(NEIGHBOR_CHANNEL, "\t\tNeighbor: (%u)\n", temp.src);
				}
			}
		}
	}


// COMMAND ADJNEIGHBOR *NEIGHBORDISCOVERY.GETLIST()
	command uint8_t* NeighborDiscovery.getList(){
		uint8_t i;
		uint8_t y = 0;
		uint8_t TempND[tempSize];
		pack Temp;

		//dbg(NEIGHBOR_CHANNEL, "NeighborDiscovery getList fired \n");
		for(i=0; i<tempSize; i++){
			Temp = call LON.get(i);
			if(Temp.src > 0){
				TempND[y] = Temp.src;
				y++;
			} 
		}
		return TempND;
	}

// COMMAND UINT16_T NEIGHBORDISCOVERY.GETSIZE()
	command uint8_t NeighborDiscovery.getSize(){
		uint16_t i;
		uint16_t y = 0;
		pack Temp;
		for(i=0; i<20; i++){
			Temp = call LON.get(i);
			if(Temp.src > 0){
				y++;
			} 
		}
		tempSize = y;
		return tempSize;
	}

	//Took from Node.nc
	void makePack(pack *Package,uint16_t src,uint16_t dest,uint16_t TTL,uint16_t protocol,uint16_t seq,uint8_t* payload,uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
   }

   bool compPack(pack *Pack){
		uint16_t j = 0;
		uint16_t size = call LOP.size();
		pack finder; 

		for(j = 0; j < size; j++){
			finder = call LOP.get(j);
			if(finder.src == Pack->src && finder.seq == Pack->seq && finder.dest == Pack->dest){
			   return TRUE; 
			}
		}
		return FALSE; 
	}

    void shovePack(pack Package) {
    	call LOP.pushback(Package);
	}
}
		























