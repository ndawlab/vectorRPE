function vr = initializeUDPforVR(vr)

vr.comm=udp('localhost', 'RemotePort', 30000, 'LocalPort', 20000);
fopen(vr.comm);

end