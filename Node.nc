/*
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */
#include <Timer.h>
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"
#include "includes/socket.h"
#include "includes/app.h"

#define PTIME 10000

module Node{
	uses {
		interface Boot;

		interface SplitControl as AMControl;
		interface Receive;

		interface SimpleSend as Sender;

		interface CommandHandler;

/// THINGS I ADDED
		// Timers
		interface Timer<TMilli> as periodicTimer;

		// Flood
		//interface SimpleSend as FSender;
		//interface Receive as FReceiver;

		// Neighbor Discovery
		interface NeighborDiscovery;

		// Link State Router
		interface LinkStateRoute as Router;

		// Forward
		//interface SimpleSend as FdSender;
		//interface Receive as FdReceiver;

		// Transport
		interface Transport;
		interface List<app_chat_t> as appList;
	}
}

implementation{
	pack sendPackage;
	//uint16_t MaxRead = 10;
	//uint16_t Seq = 0;
	//uint8_t WBuffer[1024]; 	
	//uint8_t RBuffer[SOCKET_BUFFER_SIZE];

   // Prototypes
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);

// EVENT VOID BOOT.BOOTED()
   event void Boot.booted(){
      call AMControl.start();
      dbg(GENERAL_CHANNEL, "Booted\n");
   }

// EVENT VOID AMCONTROL.STARTDONE(ERROR_T ERR)
	event void AMControl.startDone(error_t err){
		if(err == SUCCESS){
			dbg(GENERAL_CHANNEL, "Radio On\n");
			call Router.Start(); 
		}else{
			//Retry until successful
			call AMControl.start();
      }
   }

// EVENT VOID AMCONTROL.STOPDONE(ERROR_T ERR)
   event void AMControl.stopDone(error_t err){}

// EVENT VOID PERIODICTIMER.FIRED()
	event void periodicTimer.fired(){
		uint16_t i,r,w, l,k,z, Size, Send;   bool check;
		app_chat_t Data, Temp; 
		uint8_t space = 32;
		char end[2] = "\r\n";
		char LUR[12] = "listUsrRply ";

		//dbg(GENERAL_CHANNEL, "Read Timer Fired\n"); // Use this for Read and Write
		Size = call appList.size();
		for(i=0; i<Size; i++){			// for all sockets added
			Data = call appList.front();
			if(Data.Ready == TRUE){
				if(Data.transfer > SOCKET_BUFFER_SIZE) { Send = SOCKET_BUFFER_SIZE; } else { Send = Data.transfer; }
				r = call Transport.read(Data.ID, &Data.RBuffer[Data.Saved], SOCKET_BUFFER_SIZE);
				w = call Transport.write(Data.ID, &Data.WBuffer[Data.transfered], Send);

				if(w != 0){
					Data.transfer -= w;
					Data.transfered += w;
				}
				if(r != 0){ Data.Saved += r; }

				/*if(Data.RBuffer[Data.Saved-1] == 10){  // Use this for Read and Write
					dbg(GENERAL_CHANNEL, "FINISHED READING DATA: ");
					for(l=0; l<Data.Saved; l++){
						dbg_clear(GENERAL_CHANNEL, "%u, ", Data.RBuffer[l]);
					}dbg_clear(GENERAL_CHANNEL, "\n");
				} */
				if(Data.flag == 1 && Data.RBuffer[Data.Saved-1] == 10) {
					dbg_clear(GENERAL_CHANNEL, "(%u) ", TOS_NODE_ID);
					for(k=0; k<Data.Saved; k++){ dbg_clear(GENERAL_CHANNEL, "%c", Data.RBuffer[k]); }
					Data.Saved = 0;
				}
				else if(Data.RBuffer[Data.Saved-1] == 10){ 
					// Hello - Protocol
					if(Data.RBuffer[0]==72&&Data.RBuffer[1]==101 && Data.RBuffer[2]==108 && Data.RBuffer[3]==108 && Data.RBuffer[4]==111){
						dbg(GENERAL_CHANNEL, "User Found: "); z=0;
						for(k=6; k<APP_MAX_USERNAME_LENGTH && Data.RBuffer[k]!=32; k++){
							Data.Username[k-6] = Data.RBuffer[k];
							dbg_clear(GENERAL_CHANNEL, "%c", Data.Username[k-6]); z++;
						}
						Data.UNLen = z;
						Data.port = Data.RBuffer[k+1]; Data.TO[0]=1; Data.TO[1]=1; Data.TO[2]=1; Data.Saved = 0;
						dbg_clear(GENERAL_CHANNEL, " - Port %u, Length %u\n", Data.port, Data.UNLen);
					}
					// listusr - Protocol
					else if(Data.RBuffer[0]==108 && Data.RBuffer[1]==105 && Data.RBuffer[2]==115 && Data.RBuffer[3]==116){
						dbg(GENERAL_CHANNEL, "Received listusr Message\n");
						memcpy(&Data.WBuffer[0], (&LUR[0]), 12);
						k=12;
						for(z=0; z<Size; z++){
							Temp = call appList.get(z);
							memcpy(&Data.WBuffer[k], &Temp.Username[0], Temp.UNLen);
							memcpy(&Data.WBuffer[k+Temp.UNLen], (&space), 1);
							k+=Temp.UNLen+1;
						}
						memcpy(&Data.WBuffer[k], (&end[0]), 2);
						Data.transfer = k+2;  Data.transfered = 0; Data.Saved = 0;
					}
					// msg - Broadcast Protocol
					else if(Data.RBuffer[0]==109 && Data.RBuffer[1]==115 && Data.RBuffer[2]==103){
						dbg(GENERAL_CHANNEL, "Received Broadcast Message\n");
						memcpy(&Data.TO[0], &Data.RBuffer[0], 3);
						for(k=0; k<Size; k++){
							Temp = call appList.front();
							if(Data.ID != Temp.ID){
								memcpy(&Temp.WBuffer[0], &Data.RBuffer[4], Data.Saved-4);
								Temp.transfer = Data.Saved-4;	Temp.transfered = 0;
							}
							call appList.popfront();
							call appList.pushback(Temp);
						} 
						Data.Saved = 0;
					}
					// wsp - Unicast Protocl
					else if(Data.RBuffer[0]==119 && Data.RBuffer[1]==115 && Data.RBuffer[2]==112){
						dbg(GENERAL_CHANNEL, "Received Unicast Message\n");
						for(k=4; k<Data.Saved; k++){ if(Data.RBuffer[k] == space){ break; } }
						memcpy(&Data.TO[0], &Data.RBuffer[4], k-4); check = TRUE;
						for(l=0; l<Size; l++){
							Temp = call appList.front();
							for(z=0; z<Temp.UNLen; z++){
								if(Data.TO[z] != Temp.Username[z]){ check = FALSE; break; }
							}
							if(!check){ check = TRUE; }
							else{ 
								memcpy(&Temp.WBuffer[0], &Data.RBuffer[k+1], Data.Saved-(k+1)); 
								Temp.transfer = Data.Saved-(k+1);	Temp.transfered = 0;
							}
							call appList.popfront();
							call appList.pushback(Temp);
						}
						if(Data.RBuffer[Data.Saved-1] == 10){ Data.TO[0]=0; Data.TO[1]=0; Data.TO[2]=0; }
						Data.Saved = 0;
					} 
					/* // continue to Broadcast
					else if(Data.TO[0]==109 && Data.TO[1]==115 && Data.TO[2]==103){
						dbg(GENERAL_CHANNEL, "Continuing to Broadcast Message\n");
						for(k=0; k<Size; k++){
							Temp = call appList.front();
							if(Data.ID != Temp.ID){
								memcpy(&Temp.WBuffer[0], &Data.RBuffer[0], Data.Saved);
								Temp.transfer += Data.Saved;
							}
							call appList.popfront();
							call appList.pushback(Temp);
						}
					}
					// Continue to Unicast
					else if(Data.TO[0]!=0 && Data.TO[1]!=0 && Data.TO[2]!=0){
						dbg(GENERAL_CHANNEL, "Continuing to Unicast Message\n");
						for(l=0; l<Size; l++){
							Temp = call appList.front();
							for(z=0; z<Temp.UNLen; z++){
								if(Data.TO[z] != Temp.Username[z]){ check = FALSE; break; }
							}
							if(!check){ check = TRUE; }
							else{ 
								memcpy(&Temp.WBuffer[0], &Data.RBuffer[0], Data.Saved); 
								Temp.transfer += Data.Saved;
							}
							call appList.popfront();
							call appList.pushback(Temp);
						}
						if(Data.RBuffer[Data.Saved-1] == 10){ Data.TO[0]=0; Data.TO[1]=0; Data.TO[2]=0; }
					}*/
				}
			}
			call appList.popfront();
			call appList.pushback(Data);
		}
	}

// EVENT SOCKET_T TRANSPORT.CONNECTIONACCEPTED(SOCKET_T FD)
	event socket_t Transport.ConnectionAccepted(socket_t fd){
		app_chat_t Data;
		uint8_t i, Size;

		// The sever can signal a ConnectAccepted event when it is done.
		//dbg(GENERAL_CHANNEL, "SERVER-Connection Accepted - %u\n", fd);

		// Find in data
		Size = call appList.size();
		for(i=0; i<Size; i++){
			Data = call appList.get(i);
			if(Data.ID == fd){
				//dbg(GENERAL_CHANNEL, "SERVER-Socket Found\n");
				Data.Ready = TRUE;
				Data.Saved = 0; Data.TO[0]=0; Data.TO[1]=0; Data.TO[2]=0;
				call appList.popAt(i);
				call appList.pushback(Data);
				return fd;
			}
		}
		// Set Data in proper Formate
		Data.Ready = TRUE;
		Data.flag = 0;
		Data.ID = fd;
		Data.transfer = 0;
		Data.transfered = 0;
		Data.Saved = 0; Data.TO[0]=0; Data.TO[1]=0; Data.TO[2]=0;

		// Push Data into List
		call appList.pushback(Data);
		return fd;
	}

// EVENT SOCKET_T TRANSPORT.CONNECTIONESTABLISHED(SOCKET_T FD)
	event socket_t Transport.ConnectionEstablished(socket_t fd){
		app_chat_t Data;
		uint8_t i, Size;

		// The client can signal a ConnectEstablished event when it is done.
		//dbg(GENERAL_CHANNEL, "CLIENT-Connection Established - %u\n", fd);

		// Find in data
		Size = call appList.size();
		for(i=0; i<Size; i++){
			Data = call appList.get(i);
			if(Data.ID == fd){
				//dbg(GENERAL_CHANNEL, "CLIENT-Socket Found\n");
				Data.Ready = TRUE;
				Data.Saved = 0; Data.TO[0]=0; Data.TO[1]=0; Data.TO[2]=0;
				call appList.popAt(i);
				call appList.pushback(Data);
				break;
			}
		}
		return fd;
	}



// EVENT MESSAGE_T* RECEIVE.RECEIVE(MESSAGE_T* MSG, VOID* PAYLOAD, UINT8_T LENGTH)
	event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
		dbg(GENERAL_CHANNEL, "Flood Packet Received\n");
		if(len==sizeof(pack)){
			pack* myMsg=(pack*) payload;
			dbg(GENERAL_CHANNEL, "Package Payload: %s\n", myMsg->payload);
			return msg;
		}
		dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
		return msg;
	}

// EVENT VOID COMMANDHANDLER.PRINTNEIGHBORS()
	event void CommandHandler.printNeighbors(){
		dbg(GENERAL_CHANNEL, "PRINT NEIGHBORS EVENT \n");	
		call NeighborDiscovery.Print();
	}

// EVENT VOID COMMANDHANDLER.PRINTROUTETABLE()
	event void CommandHandler.printRouteTable(){
		dbg(GENERAL_CHANNEL, "PRINT Routing Table EVENT \n");	
		call Router.PrintLinkState();
	}

// EVENT VOID COMMANDHANDLER.PRINTLINKSTATE()
	event void CommandHandler.printLinkState(){
		dbg(GENERAL_CHANNEL, "PRINT Link State EVENT \n");	
		call Router.PrintLinkState();
	}

	event void CommandHandler.printDistanceVector(){}

///////////////// EVENT VOID COMMANDHANDLER.PING(UINT16_T DESTINATION, UINT8_T *PAYLOAD)  /////////////////
	event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
		dbg(GENERAL_CHANNEL, "PING EVENT \n");
		makePack(&sendPackage,TOS_NODE_ID,destination,MAX_TTL,PROTOCOL_PING,0,payload, PACKET_MAX_PAYLOAD_SIZE);
			dbg(GENERAL_CHANNEL, "Payload: %s\n", payload);
			dbg(GENERAL_CHANNEL, "ID: %d\n", TOS_NODE_ID);
			dbg(GENERAL_CHANNEL, "destination: %d\n\n", destination);
	}

///////////////// EVENT VOID COMMANDHANDLER.SETTESTSERVER(UINT8_T PORT) /////////////////
	event void CommandHandler.setTestServer(uint8_t port){
		// Set up the Test Server
		uint8_t i;
		socket_t sock;				//global fd = socket();
		socket_addr_t sockAddr;		//socket address =  NODE_ID, [srcPort] Only source info.
		app_chat_t Data;

		dbg(GENERAL_CHANNEL, "TEST SERVER EVENT \n");
		dbg(GENERAL_CHANNEL, "ID(%u), Port(%u)\n", TOS_NODE_ID, port);

		//socket address =  NODE_ID, [port] //Only source info. 
		sockAddr.port = port;
		sockAddr.addr = TOS_NODE_ID;
		
		// Get a socket if there is one available.
			// socket_t socket();
		sock = call Transport.socket();
		if(sock == 0){
			dbg(GENERAL_CHANNEL, "Server Socket Port unavialable \n");
			return;
		}

		// Bind a socket with an address.
			//bind(socket_t fd, socket_addr_t *addr);
		if(call Transport.bind(sock, &(sockAddr)) != SUCCESS){	
			dbg(GENERAL_CHANNEL, "Server Unavialable to bind\n");
			return;
		}
		
		// Listen to the socket and wait for a connection.
			// listen(socket_t fd);
		call Transport.listen(sock);

		// Set Data in proper Formate
		Data.Ready = FALSE;
		Data.flag = 0;
		Data.ID = port;
		Data.port = port;
		Data.transfer = 0;
		Data.transfered = 0;
		Data.UNLen = 0;
		Data.Saved = 0;
		Data.TO[0]=0; Data.TO[1]=0; Data.TO[2]=0;

		// Push Data into List
		call appList.pushback(Data);

		//Start PeriodicTimer When Ready
		call periodicTimer.startPeriodic(PTIME); // USE TIME BETWEEN 5s to 30s
	}

///////////////// EVENT VOID COMMANDHANDLER.SETTESTCLIENT(UINT8_T DEST, SRCPORT, DESTPORT, TRANSFER)   /////////////////
	event void CommandHandler.setTestClient(uint8_t dest, uint8_t srcPort, uint8_t destPort, uint8_t transfer){
		// Set up the Test Client
		uint32_t i;
		socket_t sock;				//global fd = socket();
		socket_addr_t sockAddr;		//socket address =  NODE_ID, [srcPort] Only source info.
		socket_addr_t destAddr;		//dest address =  destID, [destPort] Only source info.

		dbg(GENERAL_CHANNEL, "TEST CLIENT EVENT \n");
		dbg(GENERAL_CHANNEL,"ID(%u), Dest(%u), SrcPort(%u), DestPort(%u)\n",TOS_NODE_ID,dest,srcPort,destPort);

		// server address = [dest], [destPort]// Only dest info.
		sockAddr.port = srcPort;
		sockAddr.addr = TOS_NODE_ID;

		destAddr.port = destPort;
		destAddr.addr = dest;

		// Get a socket if there is one available.
			// socket_t socket();
		sock = call Transport.socket();
		if(sock == 0){
			dbg(GENERAL_CHANNEL, "Client Socket Port unavialable \n");
			return;
		}

		// Bind a socket with an address.
			//bind(socket_t fd, socket_addr_t *addr);
		if(call Transport.bind(srcPort, &(sockAddr)) != SUCCESS){
			dbg(GENERAL_CHANNEL, "Client Unavialable to bind\n");
			return;
		}

		// Connect the socket with the address using Transport.connect	/* Attempts a connection to an address. */
			//connect(socket_t fd, socket_addr_t * addr);
		if(call Transport.connect(srcPort, &(destAddr)) != SUCCESS){
			dbg(GENERAL_CHANNEL, "Client Unavialable to connect\n");
			return;
		}

		//  Start PeriodicTimer When Ready
		call periodicTimer.startPeriodic(PTIME); // USE TIME BETWEEN 5s to 30s
	}

//hello acerpa 3\r\n 
//	 \r = 13    	\n = 10		" " = 32
//	 A-Z = 65-90   	a-z = 97-122	0-9 = 48-57
///////////////// EVENT VOID COMMANDHANDLER.CONNECTINGTOSERVER(UINT8_T DEST, SRCPORT, DESTPORT, TRANSFER)   /////////////////
	event void CommandHandler.ConnectingtoServer(uint8_t clientPort, uint8_t dest, uint8_t destPort, uint8_t Ulen, uint8_t *username){
		app_chat_t Data; uint8_t i;
		uint8_t space = 32;
		char end[2] = "\r\n";
		char Hello[6] = "Hello ";

		dbg(GENERAL_CHANNEL, "Starting to connect to Server with port - %u\n", clientPort);

		// Set Data in proper Formate
		Data.Ready = FALSE;
		Data.flag = 1;
		Data.ID = clientPort;
		Data.transfer = 10+Ulen;
		Data.transfered = 0;
		Data.UNLen = Ulen;
		Data.Saved = 0;
		memcpy(&Data.Username[0], username, Ulen);

		memcpy(&Data.WBuffer[0], (&Hello[0]), 6);
		memcpy(&Data.WBuffer[6], &username[0], Ulen);
		memcpy(&Data.WBuffer[6+Ulen], (&space), 1);
		memcpy(&Data.WBuffer[7+Ulen], (&clientPort), 1);
		memcpy(&Data.WBuffer[8+Ulen], (&end[0]), 2);

		// testing values
		/*dbg_clear(GENERAL_CHANNEL, "\tSending: ");
		for(i=0; i < 10+Ulen; i++){
			dbg_clear(GENERAL_CHANNEL, "%u ", Data.WBuffer[i]);
		} dbg_clear(GENERAL_CHANNEL, "\n"); */

		// Push Data into List
		call appList.pushback(Data); 

		// Signal Test Client
		signal CommandHandler.setTestClient(dest, clientPort, destPort, Data.transfer);
	}

///////////////// EVENT VOID COMMANDHANDLER.SETAPPCLIENT(UINT8_T DEST, SRCPORT, DESTPORT, TRANSFER)   /////////////////
	event void CommandHandler.setAppServer(){}
	event void CommandHandler.setAppClient(uint8_t Mlen, uint8_t *message){
		app_chat_t Data;
		Data = call appList.front();

		dbg(GENERAL_CHANNEL, "Sending Message - %s", message);

		memcpy(&Data.WBuffer[0], message, Mlen);
		
		Data.transfer = Mlen;
		Data.transfered = 0;
		call appList.popfront();
		call appList.pushback(Data);
	}

	void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
		Package->src = src;
		Package->dest = dest;
		Package->TTL = TTL;
		Package->seq = seq;
		Package->protocol = protocol;
		memcpy(Package->payload, payload, length);
	}
}
