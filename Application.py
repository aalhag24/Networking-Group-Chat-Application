	#ANDES Lab - University of California, Merced
#Author: UCM ANDES Lab
#$Author: abeltran2 $
#$LastChangedDate: 2014-08-31 16:06:26 -0700 (Sun, 31 Aug 2014) $
#! /usr/bin/python
import sys
from TOSSIM import *
from CommandMsg import *

class TestSim:
    moteids=[]
    # COMMAND TYPES
    CMD_PING = 0
    CMD_NEIGHBOR_DUMP = 1
    CMD_ROUTE_DUMP=3
    CMD_TEST_CLIENT=4
    CMD_TEST_SERVER=5
    CMD_CONNECT_SERVER=7
    CMD_APP_CLIENT=8

    # CHANNELS - see includes/channels.h
    COMMAND_CHANNEL="command";
    GENERAL_CHANNEL="general";

    # Project 1
    NEIGHBOR_CHANNEL="neighbor";
    FLOODING_CHANNEL="flooding";

    # Project 2
    ROUTING_CHANNEL="routing";

    # Project 3
    TRANSPORT_CHANNEL="transport";

    # Personal Debuggin Channels for some of the additional models implemented.
    HASHMAP_CHANNEL="hashmap";

    # Initialize Vars
    numMote=0

    def __init__(self):
        self.t = Tossim([])
        self.r = self.t.radio()

        #Create a Command Packet
        self.msg = CommandMsg()
        self.pkt = self.t.newPacket()
        self.pkt.setType(self.msg.get_amType())

    # Load a topo file and use it.
    def loadTopo(self, topoFile):
        print 'Creating Topo!'
        # Read topology file.
        topoFile = 'topo/'+topoFile
        f = open(topoFile, "r")
        self.numMote = int(f.readline());
        print 'Number of Motes', self.numMote
        for line in f:
            s = line.split()
            if s:
                print " ", s[0], " ", s[1], " ", s[2];
                self.r.add(int(s[0]), int(s[1]), float(s[2]))
                if not int(s[0]) in self.moteids:
                    self.moteids=self.moteids+[int(s[0])]
                if not int(s[1]) in self.moteids:
                    self.moteids=self.moteids+[int(s[1])]

    # Load a noise file and apply it.
    def loadNoise(self, noiseFile):
        if self.numMote == 0:
            print "Create a topo first"
            return;

        # Get and Create a Noise Model
        noiseFile = 'noise/'+noiseFile;
        noise = open(noiseFile, "r")
        for line in noise:
            str1 = line.strip()
            if str1:
                val = int(str1)
            for i in self.moteids:
                self.t.getNode(i).addNoiseTraceReading(val)

        for i in self.moteids:
            print "Creating noise model for ",i;
            self.t.getNode(i).createNoiseModel()

    def bootNode(self, nodeID):
        if self.numMote == 0:
            print "Create a topo first"
            return;
        self.t.getNode(nodeID).bootAtTime(1333*nodeID);

    def bootAll(self):
        i=0;
        for i in self.moteids:
            self.bootNode(i);

    def moteOff(self, nodeID):
        self.t.getNode(nodeID).turnOff();

    def moteOn(self, nodeID):
        self.t.getNode(nodeID).turnOn();

    def run(self, ticks):
        for i in range(ticks):
            self.t.runNextEvent()

    # Rough run time. tickPerSecond does not work.
    def runTime(self, amount):
        self.run(amount*1000)

    # Generic Command
    def sendCMD(self, ID, dest, payloadStr):
        print '\tStarting Generic event', ID;
        self.msg.set_dest(dest);
        self.msg.set_id(ID); #HERE
        self.msg.setString_payload(payloadStr)

        self.pkt.setData(self.msg.data)
        self.pkt.setDestination(dest)
        self.pkt.deliver(dest, self.t.time()+5)

    def neighborDMP(self, destination):
        self.sendCMD(self.CMD_NEIGHBOR_DUMP, destination, "neighbor command");

    def routeDMP(self, destination):
        self.sendCMD(self.CMD_ROUTE_DUMP, destination, "routing command");

    def addChannel(self, channelName, out=sys.stdout):
        print 'Adding Channel', channelName;
        self.t.addChannel(channelName, out);

# Test Server/Client Should be similar to the ping event
    def ping(self, source, dest, msg):
        print '\tStarting ping event'
        self.sendCMD(self.CMD_PING, source, "{0}{1}".format(chr(dest),msg));

    def cmdTestServer(self, source, port):
        print '\tStarting Test Server';
        self.sendCMD(self.CMD_TEST_SERVER, source, "{0}".format(chr(port)));

    def cmdTestClient(self, source, dest, srcPort, destPort, transfer):
        print '\tStarting Test Client';
        self.sendCMD(self.CMD_TEST_CLIENT, source, "{0}{1}{2}{3}".format(chr(dest),chr(srcPort),chr(destPort),chr(transfer)));

# Test Application functions
    def cmdConnectServer(self, source, clientport, dest, destPort, username, Ulen):
        print '\tConnecting to Server';
        self.sendCMD(self.CMD_CONNECT_SERVER,source,"{0}{1}{2}{3}{4}".format(chr(clientport),chr(dest),chr(destPort),chr(Ulen),username));

    def cmdAppClient(self, source, Mlen, msg):
        print '\tSending a Message';
        self.sendCMD(self.CMD_APP_CLIENT, source, "{0}{1}".format(chr(Mlen),msg));


 
def main():
    s = TestSim();
    s.runTime(20);
    s.loadTopo("long_line.topo");
    s.loadNoise("no_noise.txt");
    s.bootAll();
    s.addChannel(s.COMMAND_CHANNEL);
    s.addChannel(s.GENERAL_CHANNEL);
    #s.addChannel(s.FLOODING_CHANNEL);
    #s.addChannel(s.NEIGHBOR_CHANNEL);
    #s.addChannel(s.ROUTING_CHANNEL);
    #s.addChannel(s.TRANSPORT_CHANNEL);
    s.runTime(150);

    s.cmdTestServer(1, 41);
    s.runTime(50);

    #s.cmdTestClient(6, 2, 1, 1, 64); #Need to establish the transfer protocol
    #s.runTime(5000); # no_noise=5,000  ---  meyer-heavy=7,500  --- some_noise=40,000

    s.cmdConnectServer(2, 23, 1, 41, "acerpa", len("acerpa"));
    s.runTime(500);

    s.cmdConnectServer(8, 52, 1, 41, "ayadav6", len("ayadav6"));
    s.runTime(500);

    s.cmdConnectServer(5, 72, 1, 41, "jshanmugasundaram", len("jshanmugasundaram"));
    s.runTime(500);

    s.cmdConnectServer(6, 48, 1, 41, "dwinlker2", len("dwinlker2"));
    s.runTime(500);

    message = "listusr\r\n";
    s.cmdAppClient(2, len(message), message);
    s.runTime(500);

    message = "msg Good Morning Ever\r\n"; #Max len message I can Send
    s.cmdAppClient(2, len(message), message);
    s.runTime(1000);

    message = "msg How are you\r\n"; #Max len message I can Send
    s.cmdAppClient(6, len(message), message);
    s.runTime(1000);

    user = "ayadav6";
    message = "wsp " + user + " Secert\r\n";
    s.cmdAppClient(6, len(message), message);
    s.runTime(1000);

    user = "dwinlker2";
    message = "wsp " + user + " Code\r\n";
    s.cmdAppClient(8, len(message), message);
    s.runTime(1000);


if __name__ == '__main__':
    main()
