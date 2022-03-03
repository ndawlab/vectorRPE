function vr = turnOnVisualCue(vr)

vr.worlds{vr.currentWorld}.surface.visible(vr.vc_cylinderIndx) = true;

end