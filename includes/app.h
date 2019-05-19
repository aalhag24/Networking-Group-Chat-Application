#ifndef APP_H
#define APP_H

enum{
    MAX_NUM_OF_APPLICATIONS = 10,
	APP_MAX_USERNAME_LENGTH = 64,
	APP_BUFFER_SIZE = 1024,
};

typedef struct app_chat_t {
	socket_t ID;	 	// Stores the Information of the file descripter ID
	bool Ready;
	uint8_t flag;		// Server or Client
	uint16_t transfer;
	uint16_t transfered;
	uint16_t Saved;
	uint8_t port;
	uint8_t UNLen;
	uint8_t TO[APP_MAX_USERNAME_LENGTH];
	uint8_t Username[APP_MAX_USERNAME_LENGTH];
	uint8_t RBuffer[APP_BUFFER_SIZE];
	uint8_t WBuffer[APP_BUFFER_SIZE];
} app_chat_t;

#endif;
