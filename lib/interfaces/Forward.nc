interface Forward{
	command error_t send(pack msg, uint16_t dest);
	event message_t* Receiver.receive(message_t* raw_msg, void* payload, uint8_t length);
}
