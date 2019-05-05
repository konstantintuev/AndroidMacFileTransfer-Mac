# AndroidMacFileTransfer-Mac
This a demo and is not ready and probably will never be ready but is cool.

I am not finishing this because I was (am) on a hackintosh laptop and the bluetooth has a very bad reception and doesn't work after sleep and I can't even use it.

# How it works
1. Drag file to statusbar icon in mac from finder
2. Mac scans for BLE peripherals
3. Mac finds and gets their names
4. User selects on connects
5. Mac connects to android peripheral and android connects to mac as a peripheral (I know bluetooth socket is better idea and also encrypted but this is my first ble project and I was still learning)
6. Android start a temporary hotspot without internet and send ssid and passwd to mac over ble
7. Mac connects and tells android to get ready to receive a file with a specific name
8. Android creates server socket on a specific port and starts listening
9. Mac sends file in chunks as fast as possible
10. Android receives and saves it + notifies the user if it was successfull
11. Mac power cycles the wifi and that way connects to the previous wifi
