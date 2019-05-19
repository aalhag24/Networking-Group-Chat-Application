#include "../../includes/channels.h"
#include "../../includes/packet.h"
#include "../../includes/protocol.h"
#include "../../includes/socket.h"

#include <stdio.h>			// FOR SWITCH CASE
#include <time.h> 

#define RETRANSMIT 4000
#define SAFEDELAY 2000

#define QUEUETIME 4000 	
#define TRANSPORTTIME 700

/*enum{ MAX_NUM_OF_SOCKETS = 10, ROOT_SOCKET_ADDR = 255, ROOT_SOCKET_PORT = 255, SOCKET_BUFFER_SIZE = 128, };*/
// 

module TransportP{
	uses{
		//interface LinkStateRoute;
		interface SimpleSend as FdSender;
		interface Receive as FdReceiver;

		interface Timer<TMilli> as TransportTimer;		// Handles reading and writting functionality
		interface Timer<TMilli> as QueueTimer;			// Handles the processing of data received
		interface Timer<TMilli> as WaitTimer;			// Handles Resends

		interface List<socket_t> as socketList; 		// [socket_t]
		interface Hashmap<socket_store_t> as Map;		// [socket_t] to store [socket_store_t*] <- this may NOT need to be a pointer
		interface Queue<pack> as SendQueue;

		interface Random;
	}
	provides {
		interface Transport;
	}
}

implementation {
	pack sendPackage;
	uint16_t SEQ = 0;
	uint8_t WIN = 8;
	uint8_t TCPdata = 8;

	// Prototypes
	void makePack(pack *Pkg,uint16_t src,uint16_t dest,uint16_t TTL,uint16_t Protocol,uint16_t seq,uint8_t *payload,uint8_t length);
	void makeTCPpack(TCP_pack *Pkg,uint8_t src,uint8_t dest,uint8_t seq,uint8_t ACK,uint8_t Flag,uint8_t Window,uint8_t *payload,uint8_t length);
	bool Contains(socket_t key);

// EVENT VOID TRANSPORTTIMER.FIRED()
/*
	void startPeriodic(uint32_t dt);
	void startOneShot(uint32_t dt);	//Equivalent to startOneShotAt(getNow(),* dt)
	void stop();			//Cancel a timer.
	void fired();			//Signaled when the timer expires (one-shot) or repeats (periodic).
	bool isRunning();		//@return TRUE if the timer is still running.
	bool isOneShot();		//@return TRUE for one-shot timers, FALSE for periodic timers.
	void startPeriodicAt(uint32_t t0, uint32_t dt); //Set a periodic timer to repeat every dt time units. Replaces any current timer
	void startOneShotAt(uint32_t t0, uint32_t dt); //Set a single-short timer to time t0+dt.
	uint32_t getNow();	//Return the current time.
	uint32_t gett0();	//Return the time anchor for the previously started timer or the time of the previous event for periodic timers.
	uint32_t getdt();	//Return the delay or period for the previously started timer. 
*/
/* enum socket_state{ CLOSED, LISTEN, ESTABLISHED, SYN_SENT, SYN_RCVD, FIN_SENT, FIN_RCVD, }; */
	event void TransportTimer.fired(){
		uint16_t i, j, Size, Remaining, CurrentWindow, Send; uint8_t data[TCPdata];
		socket_store_t store; 
		pack msg;   TCP_pack sender;

		// Say that the Transport Timer has been fired
		//dbg(TRANSPORT_CHANNEL, "INSIDE TRANSPORT TIMER\n");

		Size = call socketList.size();
		for(i=0; i<Size; i++){
			store = call Map.get(call socketList.get(i));
			//if(TOS_NODE_ID == 1){ dbg(GENERAL_CHANNEL,"TRANSPORT TIMER: %u\n", call socketList.get(i)); }
			if(store.state == ESTABLISHED){
				/*if(store.Finished == TRUE && store.lastAck == store.lastWritten){
					store.state = FIN_SENT;

					Size = call SendQueue.size();
					for(j=0; j<Size; j++){ call SendQueue.dequeue(); }

					makeTCPpack(&sender,store.src,store.dest.port,store.lastSent,0/,5,0,(uint8_t*)&data,sizeof(uint8_t));
					makePack(&msg,TOS_NODE_ID,store.dest.addr,MAX_TTL,PROTOCOL_TCP,SEQ++,(uint8_t*)&sender,PACKET_MAX_PAYLOAD_SIZE);
					call QueueTimer.stop();
					call WaitTimer.startOneShot(RETRANSMIT);
					call FdSender.send(msg, store.dest.addr);
				}
				else{ */
					//dbg(TRANSPORT_CHANNEL,"TRANSPORT STATE: LS %u, LW %u\n", store.lastSent, store.lastWritten);
					if(store.lastSent == store.lastWritten){ continue; }

						// Remaining data that can be sent
					if(store.lastAck < store.lastWritten){ Remaining = store.lastWritten - store.lastAck; }
					else { Remaining = (SOCKET_BUFFER_SIZE - store.lastAck) + store.lastWritten; }

						// Current Window
					if(store.lastAck == store.lastSent) { CurrentWindow = 0; }
					else if(store.lastAck < store.lastSent) { CurrentWindow = store.lastSent - store.lastAck; } 
					else { CurrentWindow = (SOCKET_BUFFER_SIZE - store.lastAck) + store.lastSent; }

						// Calculate the remaining data to send
					if(store.lastSent > store.lastWritten && store.lastSent - store.lastWritten < TCPdata){ Send = store.lastSent - store.lastWritten; }
					else if(store.lastSent < store.lastWritten && store.lastWritten - store.lastSent < TCPdata) { Send = store.lastWritten - store.lastSent; }
					else { Send = TCPdata; }

						// Calculate How much more data to send
					if(Remaining>(store.effectiveWindow*TCPdata)-CurrentWindow){Remaining=(store.effectiveWindow*TCPdata)-CurrentWindow;}
					if(Remaining == 0){ continue; }

						// Send the data within the window
					memcpy(&data, &store.sendBuff[store.lastSent], Send*sizeof(uint8_t));
					makeTCPpack(&sender, store.src, store.dest.port, store.lastSent, Send/*A*/,8/*F*/,0/*W*/, (uint8_t*)&data, Send);
					makePack(&msg,TOS_NODE_ID,store.dest.addr,MAX_TTL,PROTOCOL_TCP,store.Seq,(uint8_t*)&sender, PACKET_MAX_PAYLOAD_SIZE);
dbg(TRANSPORT_CHANNEL,"\t\t(%u)-Sending %u data %u to %u through %u\n", TOS_NODE_ID, sender.seq, data[0], msg.dest, sender.dest_port); 
					dbg(TRANSPORT_CHANNEL,"\t\t(%u)-LA %u LW %hhu\n", TOS_NODE_ID, store.lastAck, store.lastWritten);
					store.Seq++;
					store.lastSent+=Send; if(store.lastSent > SOCKET_BUFFER_SIZE-1) { store.lastSent -= SOCKET_BUFFER_SIZE; }
					call SendQueue.enqueue(msg);
					call FdSender.send(msg, store.dest.addr);
				}
			//}
			call Map.remove(call socketList.get(i));
			call Map.insert(call socketList.get(i), store);
		}

		if(!call QueueTimer.isRunning()) { call QueueTimer.startPeriodic(QUEUETIME);  }		// Check Resend
	}

// EVENT VOID QUEUETIMER.FIRED()
	event void QueueTimer.fired(){
		uint8_t i, Size, Seq, key; 
		socket_store_t store;
		pack msg; TCP_pack* TCP; bool Sent = FALSE;

		//dbg(TRANSPORT_CHANNEL, "\t\tINSIDE QUEUE TIMER\n");

		//Size = call SendQueue.size();
		//for(i=0; i<Size; i++) { 		// Cant use for loop, crashes
		if(!call SendQueue.empty()) {
			msg = call SendQueue.dequeue();  TCP = (TCP_pack*)(msg.payload);  Seq = TCP->seq;
	
			if(call Map.contains((uint8_t)(((*TCP).dest_port)+((*TCP).src_port)+(msg.dest)))) {
				key = (uint8_t)(((*TCP).dest_port)+((*TCP).src_port)+(msg.dest));
			} else { key = (uint8_t)(TCP->src_port); }			
			//dbg(TRANSPORT_CHANNEL,"QT - Using Key %u - %u, %u, %u\n",key,(*TCP).dest_port,(*TCP).src_port,msg.dest);

			if(call Map.contains(key)){
				store = call Map.get(key);
				if(store.state == ESTABLISHED) {
					//dbg(TRANSPORT_CHANNEL,"\t\tQUEUE TIMER: Seq %u\n", Seq);
					dbg(TRANSPORT_CHANNEL,"\t\tQUEUE State: LA: %u, LS %u, LW %u\n", store.lastAck, store.lastSent, store.lastWritten);
					if(store.lastAck == store.lastWritten) { return; }
					if(store.lastSent > store.lastAck){
							/// LA /// Seq /// LS
						if(store.lastAck <= Seq && store.lastSent > Seq){
							dbg(TRANSPORT_CHANNEL,"\t\t1-Resending sequence %u\n", Seq); Sent = TRUE;
							call SendQueue.enqueue(msg);
							call FdSender.send(msg, store.dest.addr);
						} //else { call SendQueue.dequeue(); }
					} else {
							/// LS /// LA /// Seq
						if(store.lastAck <= Seq && store.lastSent < Seq){
							dbg(TRANSPORT_CHANNEL,"\t\t2-Resending sequence %u\n", Seq); Sent = TRUE;
							call SendQueue.enqueue(msg);
							call FdSender.send(msg, store.dest.addr);
						}	/// Seq /// LS /// LA
						else if(store.lastAck >= Seq && store.lastSent > Seq){
							dbg(TRANSPORT_CHANNEL,"\t\t3-Resending sequence %u\n", Seq); Sent = TRUE;
							call SendQueue.enqueue(msg);
							call FdSender.send(msg, store.dest.addr);
						} //else { call SendQueue.dequeue(); }
					}
				}
			}
		}
		if(!call QueueTimer.isRunning() && !call SendQueue.empty()) { call QueueTimer.startPeriodic(QUEUETIME);  }	// Check Resend
	}

// EVENT VOID WAITTIMER.FIRED()
	event void WaitTimer.fired(){	// I need this to be called with variable sock->state
		uint8_t i, ACK = 0, Flag = 1; 
		uint8_t data[TCPdata];
		pack msg;   TCP_pack sender;

		socket_store_t store; 
		uint8_t Size = call socketList.size();

		dbg(TRANSPORT_CHANNEL, "INSIDE WAIT TIMER\n");
		//Use a switch statement for the state - associated with the state
		for(i=0; i<Size; i++){
			store = call Map.get(call socketList.get(i));
			switch(store.state) {
				case LISTEN:		// DO NOTHING - ALL GOOD
					break;
				case SYN_SENT:		// Resend SYN packet
					dbg(TRANSPORT_CHANNEL, "CLIENT-Resending SYN_SENT\n");
					if(store.flag == 0){ Flag = 3; } else{ Flag = 1; }

					makeTCPpack(&sender, store.src, store.dest.port, 0/*SEQ*/, 0/*ACK*/, Flag, WIN, 0, 0);
					makePack(&msg,TOS_NODE_ID,store.dest.addr,MAX_TTL,PROTOCOL_TCP, store.Seq,(uint8_t*)&sender,PACKET_MAX_PAYLOAD_SIZE);
					call FdSender.send(msg, store.dest.addr);
					call WaitTimer.startOneShot(2*RETRANSMIT);
					store.RTT = call TransportTimer.getNow();	// Client Define RTT initial

					call Map.remove((uint32_t)call socketList.get(i));
					call Map.insert((uint32_t)call socketList.get(i), store);
					break;
				case SYN_RCVD:		// Resend SYN_ACK packet
					dbg(TRANSPORT_CHANNEL, "CLIENT-Resending SYN_RCVD\n");
					Flag = 2; SEQ = store.Seq;

					makeTCPpack(&sender, store.src, store.dest.port, 0/*Seq*/, store.lastRcvd/*ACK*/, Flag, WIN, 0, 0);
					makePack(&msg, TOS_NODE_ID, store.dest.addr, MAX_TTL,PROTOCOL_TCP, SEQ, (uint8_t*)&sender, PACKET_MAX_PAYLOAD_SIZE);
					call FdSender.send(msg, store.dest.addr);
					call WaitTimer.startOneShot(RETRANSMIT);
					break;
				case ESTABLISHED: 
					dbg(TRANSPORT_CHANNEL, "CLIENT-Resending DATA\n"); 
					Flag = 8; memcpy(&data, &store.sendBuff[store.lastSent], TCPdata);
					makeTCPpack(&sender, store.src, store.dest.port, store.lastSent,ACK,Flag,0/*W*/, (uint8_t*)&data, TCPdata);
					makePack(&msg, TOS_NODE_ID, store.dest.addr, MAX_TTL, PROTOCOL_TCP, SEQ,(uint8_t*)&sender, PACKET_MAX_PAYLOAD_SIZE);
					call FdSender.send(msg, store.dest.addr);
					call WaitTimer.startOneShot(RETRANSMIT);		// Check Resend
					break;
				case FIN_SENT:		// Resend FIN_SENT packet
					dbg(TRANSPORT_CHANNEL, "CLIENT-Resending FIN_SENT\n");
					Flag = 6;
					makeTCPpack(&sender, store.src, store.dest.port, store.lastAck, ACK, Flag, WIN, 0, 0);
					makePack(&msg, TOS_NODE_ID, store.dest.addr, MAX_TTL, PROTOCOL_TCP, SEQ, (uint8_t*)&sender, PACKET_MAX_PAYLOAD_SIZE);
					call FdSender.send(msg, store.dest.addr);
					call WaitTimer.startOneShot(RETRANSMIT);
					break;
				case FIN_RCVD:		// DO NOTHING - CLOSED
					break;
				case CLOSED:		// DO NOTHING - ALL GOOD
					break;
				default:			// NULL
					break;
			}
		}
	}

// EVEN MESSAGE_T* FDRECEIVER.RECEIVE(MESSAGE_T* RAW_MSG, VOID* PAYLOAD, UINT8_T LENGTH)
	event message_t* FdReceiver.receive(message_t* raw_msg, void* payload, uint8_t length){
		if(length==sizeof(pack)){
			pack*msg=(pack*) payload;
			if(msg->protocol == PROTOCOL_TCP && msg->dest == TOS_NODE_ID){	//Check if protocol = TCP and dest is NodeID
				call Transport.receive(msg);
				//call SendQueue.enqueue(msg);
			}
			return raw_msg;
		}
      	return raw_msg;
	}


///////////////   ERROR_T RECIEVE(PACK* PACKAGE)   ///////////////  
/**
* This will pass the packet so you can handle it internally. 
* @param
*    pack *package: the TCP packet that you are handling.
* @Side Client/Server 
* @return uint16_t - return SUCCESS if you are able to handle this packet or 
*			FAIL if there are errors.
*/
	command error_t Transport.receive(pack* package){
		uint8_t ACK, Flag, key;   uint32_t timeout;	uint8_t data[TCPdata];
		pack myMsg; pack* msg; TCP_pack sender; TCP_pack* TCP;  socket_store_t store; 
		msg = package;  TCP = (TCP_pack*)msg->payload; 	//Get the tcp_pack from the package->payload

		call WaitTimer.stop();
		if(call Map.contains((uint8_t)((TCP->dest_port)+(TCP->src_port)+(msg->src)))) {
			key = (uint8_t)((TCP->dest_port)+(TCP->src_port)+(msg->src));
		} else { key = (uint8_t)(TCP->dest_port); }
		//dbg(TRANSPORT_CHANNEL,"Using Key %u\n",key);
		store = call Map.get(key);

		switch(TCP->Flag) {		//Check the Flag - associated with the packets	
			case 1:		// Msg reaches Server
				dbg(TRANSPORT_CHANNEL, "1 SERVER-SYN RECEIVED-port %u, seq %u\n",TCP->dest_port, (*msg).seq);
				//if(store.state == LISTEN){		//Check if in LISTEN
					store.state = SYN_SENT; 	Flag = 3; 	ACK = (*msg).seq;
					store.Seq = call Random.rand16()%255;

					// Advertise Window
					if(WIN > (*TCP).Window) { WIN = (*TCP).Window; }
					store.effectiveWindow = WIN;
					
					makeTCPpack(&sender, (*TCP).dest_port, (*TCP).src_port, 0/*SEQ*/, ACK, Flag, WIN, 0, 0);
					makePack(&myMsg, TOS_NODE_ID, (*msg).src, MAX_TTL,PROTOCOL_TCP, store.Seq, (uint8_t*)&sender,PACKET_MAX_PAYLOAD_SIZE);
					call FdSender.send(myMsg, (*msg).src);
					//call WaitTimer.startOneShot(RETRANSMIT);		// Check Resend
					store.RTT = call TransportTimer.getNow();		// Server Define RTT initial

					store.src = TCP->dest_port;  store.dest.port = (*TCP).src_port;  store.dest.addr = (*msg).src;
					store.lastWritten=0;store.lastAck=0;store.lastSent=0;store.lastRead=0;store.lastRcvd=0; store.nextExpected=0;
					key = (uint8_t)((TCP->dest_port)+(TCP->src_port)+(msg->src));
					if(Contains(key) == FALSE){ call socketList.pushback(key); dbg(TRANSPORT_CHANNEL, "Inserting Socket %u\n",key);}
				//}
				break;
			case 2:		// Msg reaches Server
				dbg(TRANSPORT_CHANNEL,"2 SERVER-ACK RECEIVED-port %u, seq %u vs ACK %u\n",TCP->dest_port, store.Seq,(*TCP).ACK);
				if(store.Seq == (*TCP).ACK){	//Check if in SYN_SENT - Server
					ACK = (*msg).seq; Flag = 4;

					//signal Transport.ConnectionAccepted((socket_t)(*TCP).dest_port);
					signal Transport.ConnectionAccepted((socket_t)key);

					// DEFINE Server PORT HERE
					store.dest.port = (*TCP).src_port;
					store.dest.addr = (*msg).src;
					store.state = ESTABLISHED;
						
					makeTCPpack(&sender, (*TCP).dest_port, (*TCP).src_port, 0/*SEQ*/, ACK, Flag, WIN, 0, 0);
					makePack(&myMsg, TOS_NODE_ID, (*msg).src,MAX_TTL,PROTOCOL_TCP, 0/*SEQ*/,(uint8_t*)&sender,PACKET_MAX_PAYLOAD_SIZE);
					call FdSender.send(myMsg, (*msg).src);
					//call WaitTimer.startOneShot(RETRANSMIT);		// Check Resend
					store.RTT = 2*(call TransportTimer.getNow() - store.RTT) + SAFEDELAY; 	// Calculate RTT
					dbg(TRANSPORT_CHANNEL,"\t\tSERVER-Estimated RTT: %u\n",store.RTT);
				}
				break;
			case 3:		// Msg reaches Client
				dbg(TRANSPORT_CHANNEL,"3 CLIENT-SYN_ACK-port %u, SEQ %u vs ACK %u\n",TCP->dest_port, store.Seq, (*TCP).ACK);
				if(store.Seq == (*TCP).ACK){	//Check if in SYN_SENT - Client
					ACK = (*msg).seq; Flag = 2; 
					store.state = SYN_RCVD;
					store.Seq++; store.lastRcvd = ACK;

					// Advertise Window
					if(WIN > (*TCP).Window) { WIN = (*TCP).Window; }
					store.effectiveWindow = WIN;

					makeTCPpack(&sender, (*TCP).dest_port, (*TCP).src_port, 0/*SEQ*/, ACK, Flag, WIN, 0, 0);
					makePack(&myMsg, TOS_NODE_ID, (*msg).src,MAX_TTL,PROTOCOL_TCP, store.Seq,(uint8_t*)&sender,PACKET_MAX_PAYLOAD_SIZE);
					call FdSender.send(myMsg, (*msg).src);
					call WaitTimer.startOneShot(RETRANSMIT);		// Check Resend
					store.RTT = 2*(call TransportTimer.getNow() - store.RTT) + SAFEDELAY; 	// Calculate RTT
					dbg(TRANSPORT_CHANNEL,"\t\tCLIENT-Estimated RTT: %u\n",store.RTT);
				}
				break;
			case 4:		// Msg reaches Client
				dbg(TRANSPORT_CHANNEL, "4 CLIENT-port %u, SEQ %u vs ACK %u\n", TCP->dest_port, store.Seq, (*TCP).ACK);
				if(store.Seq == (*TCP).ACK){
					store.state = ESTABLISHED;
					signal Transport.ConnectionEstablished((socket_t)(*TCP).dest_port);
				}
				break;
			case 5: 	// FIN_SENT - Client
				dbg(TRANSPORT_CHANNEL,"CLIENT-FIN_SENT RECEIVED-port %u\n",TCP->dest_port);
				if(store.state == ESTABLISHED){	//Check if in ESTABLISHED - Client
					dbg(TRANSPORT_CHANNEL, "FIN_SENT RECEIVED %u\n", (uint32_t)(*TCP).dest_port);
					ACK = 0; Flag = 6;
					store.state = FIN_SENT;

					// Server tells client that it is finished sending data
					makeTCPpack(&sender, (*TCP).dest_port, (*TCP).src_port, 0/*SEQ*/, ACK, Flag, WIN, 0, 0);
					makePack(&myMsg, TOS_NODE_ID, (*msg).src,MAX_TTL,PROTOCOL_TCP,SEQ,(uint8_t*)&sender,PACKET_MAX_PAYLOAD_SIZE);
					call FdSender.send(myMsg, (*msg).src);
					call WaitTimer.startOneShot(RETRANSMIT);		// Check Resend
				}
				break;
			case 6:		// FIN_RCVD - Server
				dbg(TRANSPORT_CHANNEL,"SERVER-FIN_RCVD RECEIVED-port %u\n",TCP->dest_port);
				//if(store.state == ESTABLISHED){	//Check if in ESTABLISHED - Server
					ACK = 0; Flag = 7;
					store.state = CLOSED;

					// Client ACK and tells server it got the msg
					makeTCPpack(&sender, (*TCP).dest_port, (*TCP).src_port, 0/*SEQ*/, ACK, Flag, WIN, 0, 0);
					makePack(&myMsg, TOS_NODE_ID, (*msg).src,MAX_TTL,PROTOCOL_TCP,SEQ,(uint8_t*)&sender,PACKET_MAX_PAYLOAD_SIZE);
					call FdSender.send(myMsg, (*msg).src);
				//}
				break;
			case 7:		// CLOSE - Client
				dbg(GENERAL_CHANNEL,"CLIENT-FIN_RCVD RECEIVED-port %u\n",TCP->dest_port);
				dbg(GENERAL_CHANNEL,"FINISHED\n");
				if(store.state == FIN_SENT){	//Check if in FIN_SENT - Client
					store.state = CLOSED;
					call TransportTimer.stop();
				}
				break;
			case 8:		// SERVER - DATA ACK
				ACK = (*TCP).seq; 	Flag = 9; 
				dbg(TRANSPORT_CHANNEL,"\tSERVER-Receiving sequence %u vs nextExpected %u\n", ACK, store.nextExpected);
				SEQ = store.Seq;
				if(ACK == store.nextExpected) {	// Check if Msg already ACK and read
					memcpy(&store.rcvdBuff[store.nextExpected], (TCP->payload), (TCP->ACK)*sizeof(uint8_t));
					//dbg(TRANSPORT_CHANNEL,"\tSERVER-Received data %u\n", store.rcvdBuff[store.nextExpected]);	

					makeTCPpack(&sender, store.src, store.dest.port, (TCP->ACK)/*SEQ*/, ACK, Flag, 0/*WIN*/,0, 0);
					makePack(&myMsg,TOS_NODE_ID,store.dest.addr,MAX_TTL,PROTOCOL_TCP,SEQ++,(uint8_t*)&sender,PACKET_MAX_PAYLOAD_SIZE);

					store.nextExpected+=(TCP->ACK);if(store.nextExpected > SOCKET_BUFFER_SIZE-1){store.nextExpected-=SOCKET_BUFFER_SIZE;}
					store.lastRcvd = ACK;
					store.Seq++;

					dbg(TRANSPORT_CHANNEL,"\tRECEIVED State: LRe %u, LRv %u, NE %u\n",store.lastRead,store.lastRcvd, store.nextExpected);
					call FdSender.send(myMsg, store.dest.addr);
				} 
				else {// Resend ACK
					dbg(TRANSPORT_CHANNEL,"\tSERVER-RESENDING Ack %u\n", ACK);
					makeTCPpack(&sender, store.src, store.dest.port, (TCP->ACK)/*Seq*/, ACK, Flag, 0/*WIN*/, 0, 0);
					makePack(&myMsg,TOS_NODE_ID,store.dest.addr,MAX_TTL,PROTOCOL_TCP,SEQ++,(uint8_t*)&sender,PACKET_MAX_PAYLOAD_SIZE);
					call FdSender.send(myMsg, store.dest.addr);
				}
				// DROP ALL OTHER PACKETS
				break;
			case 9: // CLIENT - DATA SEND
				dbg(TRANSPORT_CHANNEL,"\t\tCLIENT-ACK of %u vs lastAck %u\n", (*TCP).ACK, store.lastAck);
				if((*TCP).ACK == store.lastAck){ // Check if Msg is Proper ACK
					store.lastAck+=(TCP->seq); if(store.lastAck > SOCKET_BUFFER_SIZE-1){ store.lastAck -= SOCKET_BUFFER_SIZE; }
					dbg(TRANSPORT_CHANNEL,"\t\tACK State: LW: %u, LS %u, LA %u\n",store.lastWritten,store.lastSent, store.lastAck);
				} 
				break;
			default:
				dbg(TRANSPORT_CHANNEL,"Msg sent with INVALID FLAG-port %u, flag %u\n",TCP->dest_port,TCP->Flag);
				break;
		}
		//dbg(TRANSPORT_CHANNEL, "Saving Key %u\n",key);
		if(call Map.contains((uint32_t)key)){  call Map.remove((uint32_t)key); }
		call Map.insert((uint32_t)key, store);
		return SUCCESS;
	}


/////////////// SOCKET_T SOCKET()   ///////////////
/**
* Get a socket if there is one available.
* @Side Client/Server
* @return
*    socket_t - return a socket file descriptor which is a number associated with a socket. 
*    	If you are unable to allocated a socket then return a NULL socket_t.
*/
	command socket_t Transport.socket(){
		uint8_t Size = call socketList.size();	//check if there is any socket in List
		if(Size < MAX_NUM_OF_SOCKETS && !call Map.contains(Size+1)){
			dbg(TRANSPORT_CHANNEL, "Socket Avialable at: %u\n", Size+1);
			return Size+1;		//change the way this gives ports
		}
		else{
			return 0;				//else-return a NULL socket_t
		}
	}


///////////////  ERROR_T BIND(SOCKET_T FD, SOCKET_ADDR_R *ADDR) ///////////////
/**
* Bind a socket with an address.
* @param
*    socket_t fd: file descriptor that is associated with the socket you are binding.
*    socket_addr_t *addr: the source port and source address that you are biding to the socket, fd.
* @Side Client/Server
* @return error_t - SUCCESS if you were able to bind this socket, 
*		    FAIL if you were unable to bind.
*/
	command error_t Transport.bind(socket_t fd, socket_addr_t *addr){
		uint8_t i;
		socket_store_t store;

		if(!call Map.contains((uint32_t)fd)){
			store.state = CLOSED;
			store.src = addr->port;

			store.lastWritten = 0; store.lastAck = 0; store.lastSent = 0;
			store.lastRead = 0; store.lastRcvd = 0; store.nextExpected = 0;
			store.sending = FALSE; store.Finished = FALSE;

			for(i=0; i<SOCKET_BUFFER_SIZE; i++){
				store.sendBuff[i] = 0;
				store.rcvdBuff[i] = 0;
			}

			call socketList.pushback(fd);
			call Map.insert((uint32_t)fd, store);

			dbg(TRANSPORT_CHANNEL, "Binding Complete at: %u with State %hhu\n", &store, store.state);
			return SUCCESS;
		}
		else{
			return FAIL;
		}
	}


///////////////   ERROR_T CONNECT(SOCKET_T FD, SOCKET_ADDR_T *ADDR)   ///////////////  
/**
* Attempts a connection to an address.
* @param
*    socket_t fd: file descriptor that is associated with the socket that you are attempting a connection with. 
* @param
*    socket_addr_t *addr: the destination address and port where you will atempt a connection.
* @side Client
* @return socket_t - returns SUCCESS if you are able to attempt a connection with the fd passed, 
*			else return FAIL.
*/
	command error_t Transport.connect(socket_t fd, socket_addr_t * dest){
		socket_store_t store = call Map.get((uint32_t)fd);
		if(store.state == CLOSED){
			pack msg;  TCP_pack sender;	uint8_t ACK, Flag; 
			ACK = 0; Flag = 1;	store.Seq = call Random.rand16()%255; // Flag = 1 - For starting connection

			//TCP_pack *Pkg,		src,		dest,	seq, ACK, Flag, Window, *payload, len
			makeTCPpack(&sender, store.src, dest->port, 0/*SEQ*/, 0/*ACK*/, Flag, WIN, 	0, 		  0);
			//	pack *Pkg,	src,		dest,		TTL,	Protocol,	 seq, 				*payload, 		length
			makePack(&msg,TOS_NODE_ID,(*dest).addr,MAX_TTL,PROTOCOL_TCP, store.Seq,(uint8_t*)&sender, PACKET_MAX_PAYLOAD_SIZE);
			call FdSender.send(msg, (*dest).addr);			// Use sender to send to dest->addr;
			call WaitTimer.startOneShot(20000);				// Check Resend

			store.dest.port = (*dest).port;
			store.dest.addr = (*dest).addr;

			store.flag = 1; // Set as Client
			store.state = SYN_SENT;
			store.RTT = call TransportTimer.getNow();	// Client Define RTT initial

			call Map.remove((uint32_t)fd);
			call Map.insert((uint32_t)fd, store);
			return SUCCESS;
		} 
		else{
			return FAIL;
		}
	}


///////////////  UINT16_T WRITE(SOCKET_T FD, UINT8_T *BUFF, UINT16_T BUFFLEN)   ///////////////  
/**
* Write to the socket from a buffer. 
*	This data will eventually be transmitted through your TCP implimentation.
* @param
*    socket_t fd: file descriptor that is associated with the socket that is attempting a write.
*    uint8_t *buff: the buffer data that you are going to wrte from.
*    uint16_t bufflen: The amount of data that you are trying to submit.
* @Side For your project, only client side. This could be both though.
* @return uint16_t - return the amount of data you are able to write from the pass buffer. 
*		This may be shorter then bufflen
*//*     uint8_t sendBuff[SOCKET_BUFFER_SIZE]; 	uint8_t lastWritten;	uint8_t lastAck;	uint8_t lastSent; */
	command uint16_t Transport.write(socket_t fd, uint8_t *buff, uint16_t bufflen){
		bool wrap;
		uint8_t i;
		uint16_t Remaining, Max_LastWritten, Write;
		socket_store_t store;

		if(!call Map.contains(fd)){		//Get the value from the hashmap[Map]
			dbg(TRANSPORT_CHANNEL,"WRITE: Socket does not EXIST\n");
			return 0;
		}
		else{
			store = call Map.get(fd);
			Max_LastWritten = SOCKET_BUFFER_SIZE - store.lastWritten;
		}

		//dbg(TRANSPORT_CHANNEL,"WRITE: Begining\n");
		if(store.lastAck == store.lastWritten){
			Remaining = SOCKET_BUFFER_SIZE;
			if(store.lastWritten > 0){ wrap == TRUE; } else { wrap = FALSE; }
		}
		else if(store.lastAck < store.lastWritten){		//Check within bounds of window using LastWritten and LastACKed
			Remaining = Max_LastWritten + store.lastAck;
			wrap = TRUE;
		}
		else {	// Else use till end of buff
			Remaining = store.lastAck - store.lastWritten;
			wrap = FALSE;
		}

		//dbg(GENERAL_CHANNEL,"\t\tWRITE: Bufflen %u \t\t Remaining %u\n", bufflen, Remaining);
		if(bufflen==0){
			store.Finished=TRUE;  //dbg(TRANSPORT_CHANNEL, "WRITE: DONE WRITING DATA \n");
			call Map.remove((uint32_t)fd); 
			call Map.insert((uint32_t)fd,store); 
			return 0;
		}//Nothing left
		if(Remaining == 0) {  dbg(TRANSPORT_CHANNEL, "WRITE: Send buffer NOT FULL\n"); return 0; } // Check If there is space to write
		if(bufflen < Remaining){ Write = bufflen; } else { Write = Remaining; } //Check if Remaining is within buffer length
		if(Write < Remaining){
			store.Finished=TRUE;  //dbg(TRANSPORT_CHANNEL, "WRITE: DONE WRITING DATA \n");
			call Map.remove((uint32_t)fd); 
			call Map.insert((uint32_t)fd,store); 
		}else {
			Write--;
		}

		dbg(TRANSPORT_CHANNEL,"\t\t\tWRITE: Writing %u with MLR %u\n", Write, Max_LastWritten);
		if(wrap){
			dbg(TRANSPORT_CHANNEL, "WRITE: WRAP == TRUE LA: %u vs LW: %u\n", store.lastAck, store.lastWritten);
			if(Write < Max_LastWritten){
				memcpy(&store.sendBuff[store.lastWritten], buff, Write*sizeof(uint8_t));
			} else {
				memcpy(&store.sendBuff[store.lastWritten], buff, Max_LastWritten*sizeof(uint8_t));
				memcpy(&store.sendBuff[0], (buff + Max_LastWritten*sizeof(uint8_t)), (Write - Max_LastWritten)*sizeof(uint8_t));
			}
		} else {
			dbg(TRANSPORT_CHANNEL, "WRITE: WRAP == FALSE LA: %u vs LW: %u\n", store.lastAck, store.lastWritten);
			memcpy(&store.sendBuff[store.lastWritten], buff, Write*sizeof(uint8_t));
		}

		store.lastWritten += Write; if(store.lastWritten > SOCKET_BUFFER_SIZE - 1){ store.lastWritten -= SOCKET_BUFFER_SIZE; }
		dbg(TRANSPORT_CHANNEL,"\t\tAFTER WRITE: LA %u, LW %u\n", store.lastAck, store.lastWritten);

		//Start the TIMERS
		if(Contains(fd) == FALSE){ call socketList.pushback(fd); dbg(TRANSPORT_CHANNEL,"Created New Socket %u\n",fd);}
		if(!call TransportTimer.isRunning()){ call TransportTimer.startPeriodic(TRANSPORTTIME); }
		if(!call QueueTimer.isRunning()){  call QueueTimer.startPeriodic(QUEUETIME);  }

		call Map.remove((uint32_t)fd);
		call Map.insert((uint32_t)fd, store);

		return Write;	// NOT Remaining
	}


///////////////    UINT16_T READ(SOCKET_T FD, UINT8_T *BUFF, UINT16_T BUFFLEN)  ///////////////  
/**
* Read from the socket and write this data to the buffer. This data is obtained from your TCP implimentation.
* @param
*    socket_t fd: file descriptor that is associated with the socket that is attempting a read.
*    uint8_t *buff: the buffer that is being written.
*    uint16_t bufflen: the amount of data that can be written to the buffer.
* @Side For your project, only server side. This could be both though.
* @return uint16_t - return the amount of data you are able to read from the pass buffer. 
*					This may be shorter then bufflen
*//*    uint8_t rcvdBuff[SOCKET_BUFFER_SIZE];		uint8_t lastRead;	uint8_t lastRcvd;	uint8_t nextExpected; */
	command uint16_t Transport.read(socket_t fd, uint8_t *buff, uint16_t bufflen){
		bool wrap;
		uint16_t i, DataRead, Max_LastRead;
		socket_store_t store;

		if(!call Map.contains(fd)){		//Get the value from the hashmap[Map]
			dbg(TRANSPORT_CHANNEL,"READ: Socket does not EXIST - %u\n", fd);
			return 0;
		}
		else{
			store = call Map.get(fd);
			Max_LastRead = SOCKET_BUFFER_SIZE-store.lastRead;
		}


		//dbg(TRANSPORT_CHANNEL,"READ: Beginning\n");
		if(store.nextExpected == store.lastRead){		//check if you read the last buff
			//dbg(TRANSPORT_CHANNEL,"READ: Nothing to Read\n");
			return 0;		// DONE
		}
		else if(store.nextExpected > store.lastRead){	//check if you need to read more
			DataRead = store.nextExpected - store.lastRead;	// Remainder to read
			wrap = FALSE;
		} 
		else {
			DataRead = Max_LastRead + store.nextExpected;
			wrap = TRUE;
		}
		if(DataRead > bufflen){  DataRead = bufflen;  }		// Just in case it goes out of boundsa
		if(DataRead == 0) { return 0; }

		dbg(TRANSPORT_CHANNEL,"Reading %u - LRcvd %u,  LRead %u, MLR %u\n", DataRead,store.nextExpected,store.lastRead,Max_LastRead);
		//Read the neccessary data
		if(wrap){
			memcpy(buff, (&store.rcvdBuff[store.lastRead]), (Max_LastRead)*sizeof(uint8_t));
			memcpy(buff + Max_LastRead*sizeof(uint8_t), &store.rcvdBuff[0], (DataRead-Max_LastRead)*sizeof(uint8_t));
			store.lastRead = DataRead-Max_LastRead;
		} else {		// wrap = FALSE
			memcpy(buff, (&store.rcvdBuff[store.lastRead]), DataRead*sizeof(uint8_t));
			store.lastRead += DataRead;
		} 

		// Check if within bounds
		if(store.lastRead > SOCKET_BUFFER_SIZE - 1){  store.lastRead-=SOCKET_BUFFER_SIZE;  }

		/*dbg(TRANSPORT_CHANNEL,"\t  Reading: %u, ", buff[0]);
		if(DataRead!=1){for(i=0; i<DataRead; i++){
			dbg_clear(TRANSPORT_CHANNEL,"%u, ", buff[i]);
		}}dbg_clear(TRANSPORT_CHANNEL,"\n"); */

		call Map.remove((uint32_t)fd);
		call Map.insert((uint32_t)fd, store);
		return DataRead;
	}


///////////////   ERROR_T LISTEN(SOCKET_T FD)    ///////////////  
/**
* Listen to the socket and wait for a connection.
* @param
*    socket_t fd: file descriptor that is associated with the socket that you are hard closing. 
* @side Server
* @return error_t - returns SUCCESS if you are able change the state to listen 
*					else FAIL.
*/
	command error_t Transport.listen(socket_t fd){
		if(call Map.contains(fd)){
			socket_store_t store = call Map.get(fd);
			if(store.state == CLOSED){
				store.state = LISTEN;	//Set to LISTEN
				store.flag = 0; 		//Set as Server
				dbg(TRANSPORT_CHANNEL, "Socket Listen port %u\n", fd);

				call Map.remove((uint32_t)fd);
				call Map.insert((uint32_t)fd, store);
				return SUCCESS;			//return SUCCESS
			}
		}
		return FAIL; 	//return FAIL
	}


///////////////   ERROR_T CLOSE(SOCKET_T FD)   ///////////////  
/**
* Closes the socket.
* @param
*    socket_t fd: file descriptor that is associated with the socket that you are closing. 
* @side Client/Server
* @return socket_t - returns SUCCESS if you are able to attempt a closure with the fd passed, 
*					else return FAIL.
*/
	command error_t Transport.close(socket_t fd){
		socket_store_t store = call Map.get(fd);
		if(store.state == FIN_RCVD){
			dbg(TRANSPORT_CHANNEL, "State Set to CLOSED, %u\n",fd);
			store.state = CLOSED;	//Set to CLOSED

			call Map.remove((uint32_t)fd);
			call Map.insert((uint32_t)fd, store);
			return SUCCESS;	
		}
		else {
			return FAIL; 	//return FAIL
		}
	}


///////////////  SOCKET_T ACCECPT(SOCKET_T FD)   ///////////////  
/**
* Checks to see if there are socket connections to connect to and if there is one, connect to it.
* @param
*    socket_t fd: file descriptor that is associated with the socket that is attempting an accept. remember, only do on listen. 
* @side Server
* @return socket_t - returns a new socket if the connection is accepted.
* 	This socket is a copy of the server socket but with a destination associated with the destination address and port.
*    	If not return a null socket.
*/
	command socket_t Transport.accept(socket_t fd){
		//NOT NECCESSARY
	}


///////////////  ERROR_T RELEASE(SOCKET_T FD)  ///////////////  
/**
* A hard close, which is not graceful. This portion is optional.
* @param
*    socket_t fd: file descriptor that is associated with the socket that you are hard closing. 
* @side Client/Server
* @return socket_t - returns SUCCESS if you are able to attempt a closure with the fd passed, 
*		else return FAIL.
*/
	command error_t Transport.release(socket_t fd){
		//OPTIONAL - NOT DOING IT
	}


//////////////////////////////    FUNCTIONS   //////////////////////////////
	//Took from Node.nc
	void makePack(pack *Pkg,uint16_t src,uint16_t dest,uint16_t TTL,uint16_t Protocol,uint16_t seq,uint8_t *payload,uint8_t length){
		Pkg->src = src;
		Pkg->dest = dest;
		Pkg->TTL = TTL;
		Pkg->seq = seq;
		Pkg->protocol = Protocol;
		memcpy(Pkg->payload, payload, length);
	}

/*typedef nx_struct TCP_pack{
	nx_uint8_t dest_port, src_port, seq, ACK, Flag, Window;
	nx_uint8_t payload[PACKET_MAX_PAYLOAD_SIZE];
}TCP_pack;*/
   void makeTCPpack(TCP_pack *Pkg,uint8_t src,uint8_t dest,uint8_t seq,uint8_t ACK,uint8_t Flag,uint8_t Win,uint8_t *payload,uint8_t len){
		uint8_t i; Pkg->src_port = src;
		Pkg->dest_port = dest;
		Pkg->seq = seq;
		Pkg->ACK = ACK;
		Pkg->Flag = Flag;
		Pkg->Window = Win;
		memcpy(Pkg->payload, payload, len);
	}

	bool Contains(socket_t key){
		socket_t check;
		uint8_t i, Size = call socketList.size();
		for(i=0; i<Size; i++){
			check = call socketList.get(i);
			if(check == key){
				return TRUE;
			}
		}
		return FALSE;
	}
}
