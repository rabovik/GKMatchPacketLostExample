An example app demonstrating Game Center GKMatch GKSendDataReliable packets lost. See [StackOverflow question][SO].

## Steps to reproduce the bug

* Change Bundle ID to yours (registered in iTunes Connect to work with Game Center);
* Use two devices with weak internet connection on one of them (I used Wi-Fi on iPad 3 and EDGE on iPhone 4S);
* Run the app and try to host a match

## How typical errors look like

#### Packet loss

![][packetloss]

#### Device stops receiving data while another still sends and receives

![][stopReceiving]


[SO]: http://stackoverflow.com/q/16987880/441735
[GKMatchPacketLostExample]: http:github.com
[SACK]: http://en.wikipedia.org/wiki/Retransmission_(data_networks)
[packetloss]: PacketLoss.png
[stopReceiving]: StopReceiving.png
