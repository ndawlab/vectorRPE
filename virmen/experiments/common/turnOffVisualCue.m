function vr = turnOffVisualCue(vr)

vr.worlds{vr.currentWorld}.surface.visible(vr.vc_cylinderIndx) = false;

end