#include "../../includes/channels.h"
#include "../../includes/packet.h"
#include "../../includes/protocol.h"

module LinkStateRouteP{
	uses{
		// Neighbor Discovery
		interface NeighborDiscovery;
		//Forwarder
		//interface Forward;

		// Sending System
		interface SimpleSend as RSender;
		interface Receive as RReceiver;
		interface Timer<TMilli> as RouteTimer;

		interface List<LinkState> as LON;
		interface List<uint8_t> as LOP;
		//interface List<LinkState> as RoutingTable;
		//interface Hashmap<LinkState> as Table;
	}
	provides {
		interface LinkStateRoute;
		//interface SimpleSend as RouteSender;
		//interface Receive as RouteReceiver;
	}
}

implementation {
	uint16_t SEQ = 0; // Need to incorporate this
	pack sendPackage;
	RouteTable RTable[PACKET_MAX_PAYLOAD_SIZE];

	// Prototype Function
	void makePack(pack *Package,uint16_t src,uint16_t dest,uint16_t TTL,uint16_t Protocol,uint16_t seq,uint8_t *payload,uint8_t length);
	bool contains(uint8_t ID);
	void replace(uint8_t ID, uint8_t newHop, uint8_t newCost);
	LinkState find(uint8_t ID);
	void sendInfo();
	void Sort();
	void Dijkstra();

// COMMAND VOID LINKSTATEROUTE.START()
	command void LinkStateRoute.Start(){
		uint8_t i,j;
		//dbg(ROUTING_CHANNEL, "Initializing Routing\n");
		call NeighborDiscovery.Start();

		for(i=0; i<PACKET_MAX_PAYLOAD_SIZE; i++){
			for(j=0; j<PACKET_MAX_PAYLOAD_SIZE; j++){
				RTable[i].DestCost[j] = 255;
			}
		}
		RTable[TOS_NODE_ID].DestCost[TOS_NODE_ID] = 0;	
		call RouteTimer.startPeriodic(10000);
	}

// COMMAND VOID ROUTETIMER.FIRED()
	event void RouteTimer.fired(){
		void* Tmp;
		uint16_t i;
		//uint16_t j;
		uint8_t NNID;
		uint8_t Size = 0;
		//bool FOUND = FALSE;
		nx_uint8_t TempNList[PACKET_MAX_PAYLOAD_SIZE];
		LinkState TempLS;	

		//dbg(ROUTING_CHANNEL, "Routing Timer Fired\n");
		Size = call NeighborDiscovery.getSize();
		Tmp = call NeighborDiscovery.getList();
		memcpy(TempNList, Tmp, sizeof(uint8_t)*Size);

		//dbg(ROUTING_CHANNEL, "\tNeighbor Size(%u) for NODE(%u)\n", Size, TOS_NODE_ID);
		for(i=0; i<Size; i++){
			NNID = TempNList[i];
			//dbg(ROUTING_CHANNEL, "\t\tNeigh(%u)\n", NNID);
			if(NNID != 0 && !contains(NNID)){
				TempLS.ID = NNID;
				TempLS.Hop = NNID;
				TempLS.Cost = 1;
				call LON.pushback(TempLS);
			}
		}

		for(i=0; i<PACKET_MAX_PAYLOAD_SIZE; i++){
			TempNList[i] = 255;
		}
		TempNList[TOS_NODE_ID] = 0;

		Size = call LON.size();
		for(i=0; i<Size; i++){
			TempLS = call LON.get(i);
			TempNList[TempLS.ID] = TempLS.Cost;
		}

		//call LinkStateRoute.PrintLinkState();

		// 2) Link-state flooding. To tell all nodes about all neighbors
		//makePack(Package,src,dest,TTL, protocol, seq,uint8_t* payload,len)
		makePack(&sendPackage,TOS_NODE_ID,AM_BROADCAST_ADDR,MAX_TTL,PROTOCOL_PING,SEQ,(uint8_t*)TempNList,sizeof(TempNList));
		call RSender.send(sendPackage, AM_BROADCAST_ADDR);

	}

// EVENT MESSAGE_T* FRECEIVE.RECEIVE(MESSAGE_T* RAW_MSG, VOID* PAYLOAD, UINT8_T LENGTH)
	event message_t* RReceiver.receive(message_t* raw_msg, void* payload, uint8_t length){
		uint8_t i;
		//uint8_t j;
		uint8_t NCost;
		uint8_t Size;
		LinkState TempLS;
		//bool CHANGED = FALSE;
		nx_uint8_t TempNList[PACKET_MAX_PAYLOAD_SIZE];
		pack *msg=(pack*)payload;	

		msg->TTL--;
		//dbg(ROUTING_CHANNEL, "TTL: (%u)\n", msg->TTL);
		memcpy(TempNList, msg->payload, length);

		if(msg->TTL != 0 && msg->src != TOS_NODE_ID){
			if(msg->protocol == PROTOCOL_PING || msg->protocol == PROTOCOL_ND){
				//dbg(ROUTING_CHANNEL, "Link State Neighbor Discovery\n");
				for(i=0; i<PACKET_MAX_PAYLOAD_SIZE; i++){
					RTable[msg->src].DestCost[i] = TempNList[i];;
				}
				makePack(&sendPackage,msg->src,AM_BROADCAST_ADDR,msg->TTL,PROTOCOL_ND,SEQ,(uint8_t*)TempNList,sizeof(TempNList));
				call RSender.send(sendPackage, AM_BROADCAST_ADDR);
			}
			if(msg->protocol == PROTOCOL_PING || msg->protocol == PROTOCOL_LINKSTATE){
				for(i=0; i<PACKET_MAX_PAYLOAD_SIZE; i++){
					NCost = TempNList[i];
					if(i != TOS_NODE_ID && NCost != 255){
						if(contains(i)){
							TempLS = find(i);
							if(TempLS.Cost > NCost + 1){
								replace(i, msg->src, NCost+1);
								//CHANGED = TRUE;
							}
						}
						else{
							TempLS.ID = i;
							TempLS.Hop = msg->src;
							TempLS.Cost = NCost + 1;
							call LON.pushback(TempLS);
							//CHANGED = TRUE;
						}
					}
				}

				for(i=0; i<PACKET_MAX_PAYLOAD_SIZE; i++){
					TempNList[i] = 255;
				}
				TempNList[TOS_NODE_ID] = 0;

				Size = call LON.size();
				for(i=0; i<Size; i++){
					TempLS = call LON.get(i);
					TempNList[TempLS.ID] = TempLS.Cost;
				}

			makePack(&sendPackage,TOS_NODE_ID,AM_BROADCAST_ADDR,msg->TTL,PROTOCOL_LINKSTATE,SEQ,(uint8_t*)TempNList,sizeof(TempNList));
				call RSender.send(sendPackage, AM_BROADCAST_ADDR);
			}
		}
		if (msg->TTL == 0) {
			//Dijkstra();
		}
		return raw_msg;
	}

// COMMAND VOID LINKSTATEROUTE.PRINTROUTINGTABLE()
	command void LinkStateRoute.PrintRoutingTable(){
		uint8_t i,j;
		dbg(ROUTING_CHANNEL, "Src\tDest\tCost - FOR NODE(%u)\n", TOS_NODE_ID);
		for(i=1;i<PACKET_MAX_PAYLOAD_SIZE;i++){
			for(j=1;j<PACKET_MAX_PAYLOAD_SIZE;j++){
				dbg(ROUTING_CHANNEL, "(%u)-(%u)\t(%u)\n", i,j,RTable[i].DestCost[j]);
			}
			dbg(ROUTING_CHANNEL, "\n");
		}
	}

// COMMAND VOID LINKSTATEROUTE.PRINTLINKSTATE()
	command void LinkStateRoute.PrintLinkState(){
		uint8_t i;
		LinkState TempLS;
		uint8_t Size = call LON.size();
		Sort();

		dbg(ROUTING_CHANNEL, "\tLink State Table for Node (%u) for (%u) Neighbors\n", TOS_NODE_ID, Size);
		dbg(ROUTING_CHANNEL, "\t\tDest\tNext Hop\tCost\n");
		for(i=0; i<Size; i++){
			TempLS = call LON.get(i);
			dbg(ROUTING_CHANNEL, "\t\t(%u)\t(%u)\t\t(%u)\n", TempLS.ID, TempLS.Hop, TempLS.Cost);
		}
		dbg(ROUTING_CHANNEL, "\n");
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

	
// VOID CONTAINS(UINT8_T ID)
	bool contains(uint8_t ID){
		uint8_t i;
		uint8_t Size = call LON.size();
		struct LinkState TempLS;

		//dbg(ROUTING_CHANNEL, "\tDoes it Contain (%u)\n", ID);
		if(!call LON.isEmpty()){
			for(i=0; i<Size; i++){
				TempLS = call LON.get(i);
				if(TempLS.ID == ID){
					//dbg(ROUTING_CHANNEL, "\t\tTRUE\n");
					return TRUE;
				}
			}
		}
		//dbg(ROUTING_CHANNEL, "\t\tFALSE\n");
		return FALSE;
	}

// VOID REPLACE(UINT8_T ID, UINT8_T MSGSRC, UINT8_T NEWCOST)
	void replace(uint8_t ID, uint8_t newHop, uint8_t newCost){
		uint8_t i;
		LinkState TempLS;
		uint8_t Size = call LON.size();

		for(i=0; i<Size; i++){
			TempLS = call LON.get(i);
			if(TempLS.ID == ID){
				call LON.popAt(i);
				TempLS.ID = ID;
				TempLS.Hop = newHop;
				TempLS.Cost = newCost;
				call LON.pushback(TempLS);
			}
		}
	}

// LINKSTATE FIND(UINT8_T ID)
	LinkState find(uint8_t ID){
		uint8_t i;
		LinkState TempLS;
		uint8_t Size = call LON.size();

		for(i=0; i<Size; i++){
			TempLS = call LON.get(i);
			if(TempLS.ID == ID){
				return TempLS;
			}
		}
		TempLS.ID = 0;
		return TempLS;
	}

// VOID SORT()
//https://en.wikipedia.org/wiki/Selection_sort
	void Sort(){
		uint8_t i,j,newj,min;
		uint8_t Size = call LON.size();
		LinkState II;
		LinkState JJ;

		for(i=0; i<Size-1; i++){
			newj = i;
			II = call LON.get(i);
			min = II.ID;
			for(j=i+1; j<Size; j++){
				JJ = call LON.get(j);
				if(min > JJ.ID){
					min = JJ.ID;
					newj = j;
				}
			}
			if(newj != i){
				call LON.swap(i,newj);
			}
		}
	}

// VOID DIJKSTRA()
	void Dijkstra(){
		uint8_t n,s,i,j,y,w,iMIN,Mindex;
		bool check;
		uint8_t N[PACKET_MAX_PAYLOAD_SIZE];
		uint8_t M[PACKET_MAX_PAYLOAD_SIZE];
		uint8_t C[PACKET_MAX_PAYLOAD_SIZE];
		uint8_t UC[PACKET_MAX_PAYLOAD_SIZE];
		s = TOS_NODE_ID;
		Mindex = 0;

	//Initailzation
		//N = {1, 2, ... , 18, 19}
		for(i=0; i<PACKET_MAX_PAYLOAD_SIZE; i++){
			N[i] = i;
			M[i] = 255;
		}
		//M = {s}
		M[0] = s;

		//For(n in N - {s})
		for(n=0; n<PACKET_MAX_PAYLOAD_SIZE; n++){
			if(n != s){
				//C(n) = L(s,n);
				C[n] = RTable[s].DestCost[n];
			}
		}
			
	// Find shortest path
		while(TRUE){
			//Unconsidered = N - M
			y=0;
			for(i=0;i<PACKET_MAX_PAYLOAD_SIZE;i++){
				check = FALSE;
				for(j=0;j<PACKET_MAX_PAYLOAD_SIZE;i++){
					if(N[i] == M[j]){
						check = TRUE;
					}
				}
				if(!check){
					UC[y] = N[i];
					y++;
				}			
			}
			if(y == 0){ break; }

			iMIN = C[UC[0]];
			w = 0;
			for(i=1; i<y; i++){
				if(C[UC[i]] < iMIN){
					iMIN = C[UC[i]];
					w = i;
				}
			}
			M[Mindex] = w;
			Mindex++;
			//M.pushback(w); // such that C(w) is the smallest in unconsidered
			for(n=0; n<y; n++){
				//C(n) = MIN(C(n), C(w) + L(w,n)) // below
				iMIN = C[n];
				for(i=0; i<PACKET_MAX_PAYLOAD_SIZE; i++){
					if(C[w] + RTable[w].DestCost[n] < C[n]){
						iMIN = C[w] + RTable[w].DestCost[n];
					}
				}
				C[n] = iMIN;
			}
		}

	}

///////////////// FORWARDING ///////////////////////
// COMMAND VOID LINKSTATEROUTE.GETNEXTHOP()
	command uint16_t LinkStateRoute.getNextHop(uint16_t dest){
		uint8_t i;
		LinkState TempLS;
		uint16_t val = 255;
		uint8_t Size = call LON.size();
		
		for(i=0; i<Size; i++){
			TempLS = call LON.get(i);
			if(TempLS.ID == dest){
				val = TempLS.Hop;
				break;
			}
		}
		return val;
	}
}	











