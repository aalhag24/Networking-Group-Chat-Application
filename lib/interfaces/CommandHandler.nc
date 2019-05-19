interface CommandHandler{
   // Events
	event void ping(uint16_t destination, uint8_t *payload);
	event void printNeighbors();
	event void printRouteTable();
	event void printLinkState();
	event void printDistanceVector();
	event void setTestServer(uint8_t port);
	event void setTestClient(uint8_t dest, uint8_t srcPort, uint8_t destPort, uint8_t transfer);
	event void setAppServer();

	event void ConnectingtoServer(uint8_t clientPort, uint8_t dest, uint8_t destPort, uint8_t Ulen, uint8_t *username);
	event void setAppClient(uint8_t Mlen, uint8_t *message);
}
