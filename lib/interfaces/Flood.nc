#include "../../includes/Structures.h"
#include "../../includes/packet.h"

interface Flood {
// DO NOT NEED THIS
	command error_t FSender.send(pack msg, uint16_t dest);
	event message_t* Receiver.receive(message_t* raw_msg, void* payload, uint8_t length);
}
