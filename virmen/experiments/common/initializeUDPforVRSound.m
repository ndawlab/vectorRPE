function vr = initializeUDPforVRSound(vr)

vr.commSound=udp('localhost', 'RemotePort', 30001, 'LocalPort', 20001);
fopen(vr.commSound);

end