function vr = initializeUDPforMP285_backVR(vr)

vr.mp285=udp('128.112.219.83', 'RemotePort', 50000, 'LocalPort', 40000, 'timeout', 10);
fopen(vr.mp285);

end