#include "../../includes/channels.h"
#include "../../includes/packet.h"
#include "../../includes/protocol.h"

module ForwardP{
	uses {
		interface LinkStateRoute as Router;

		interface SimpleSend as Sender;
		interface Receive as Receiver;
	}
	provides{
		interface SimpleSend as RouteSender;
		interface Receive as RouteReceiver;
	}
}
implementation {
// COMMAND ERROR_T ROUTESENDER.SEND(PACK MSG, UINT16_T DEST)
	command error_t RouteSender.send(pack msg, uint16_t dest){
		uint16_t NextHop;
		NextHop = call Router.getNextHop(dest);
		//dbg(ROUTING_CHANNEL, "\t\tNext Hop (%u)\n", dest);

		if(NextHop >= 255){
			dbg(ROUTING_CHANNEL, "CAN NOT FORWARD MESSAGE DUE TO LACK OF DESTINATION FOR: (%u) to (%u)\n", TOS_NODE_ID, dest);
			return FAIL;
		}
		else { 
			dbg(ROUTING_CHANNEL, "\tSending msg: Dest:(%u) using:(%u)\n", dest, NextHop);
			call Sender.send(msg, NextHop);
			return SUCCESS;
		}
	}

// EVENT MESSAGE_T* RECEIVER.receive(MESSAGE_T* RAW_MSG, VOID* payload, uint8_t len)
	event message_t* Receiver.receive(message_t* raw_msg, void* payload, uint8_t length){
		uint16_t tmp;
		uint16_t NextHop;
		pack *msg = (pack*)payload;

		// 4)Forwarding. 
		// To send packets using your routing table for the next-hops. 
		if(msg->dest == TOS_NODE_ID){
			if(msg->protocol == PROTOCOL_PING){
				tmp = msg->src;
				msg->src = msg->dest;
				msg->dest = tmp;
				msg->protocol = PROTOCOL_PINGREPLY;
				msg->TTL = MAX_TTL;

				NextHop = call Router.getNextHop(msg->dest);
				if(NextHop == 255){
					return raw_msg;
				}
				else {
					dbg(ROUTING_CHANNEL,"PING RECEIVED - Reply to Dest:(%u) using (%u)\n\n",msg->dest, NextHop);
					call RouteSender.send(*msg, NextHop);
				}
			}
			else if(msg->protocol == PROTOCOL_PINGREPLY){
				dbg(ROUTING_CHANNEL, "PING REPLY RECEIVED with message: (%u)\n\n", msg->seq);
			}
			else if(msg->protocol == PROTOCOL_TCP){
				dbg(ROUTING_CHANNEL, "TCP RECEIVED\n\n");
				signal RouteReceiver.receive(raw_msg, payload, length); 	//You have no idea how long it took to get this working
			}
			return raw_msg;
		}
		else if(msg->dest != TOS_NODE_ID){
			//dbg(ROUTING_CHANNEL, "\t\tJumping to (%u)\n", (*msg).dest);
			call RouteSender.send(*msg, (*msg).dest);
		}
		else if(msg->dest > 21){
			dbg(ROUTING_CHANNEL, "SENDING OUT OF BOUNDS\n");
		}
		return raw_msg;
	}
}
