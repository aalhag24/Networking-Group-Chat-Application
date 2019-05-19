#include "../../includes/Structures.h"
#include "../../includes/am_types.h"

configuration FloodC{
	// I could have provided the entire Flood interface but the Sender and Receiver are fine
	provides {
		interface Receive as FReceive;
		interface SimpleSend as FSend;
	}
}
implementation {
	// Setting up neccessary parameters and variables
	components FloodP;

	components new AMReceiverC(AM_FLOODING);
	components new SimpleSendC(AM_FLOODING);
	
	// Setting up the wired communication
	FloodP.Reciever -> AMReceiverC;
	FloodP.Sender -> SimpleSendC;

	// Setting up the pack List
	components new ListC(pack, 64);
	FloodP.Storage -> ListC;

	// Setting up the interface system
	FReceive = FloodP.FReceive;
	FSend = FloodP.FSend;
}
