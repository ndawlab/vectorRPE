%% ViRMEn movement function for use with the optical sensor + Arduino + MouseReader_2sensors class setup.
%
%   This function assumes that 4 specific variables have been defined in the vr object, for example
%   by calling the initializeArduinoMouse_2sensors() function in the ViRMEn initialization user code
%   section:
%     1) vr.mr:       A MouseReader_2sensors object
%     2) vr.scaleX:   factor by which to scale dX
%     3) vr.scaleY:   factor by which to scale dY
%     4) vr.scaleA:   factor by which to scale dA
%
%   This motion rule assumes that the sensor measures the displacement of the ball at the mouse's
%   feet as [dX, dY] where dX is lateral and dY is anterior-posterior displacement. The orientation
%   of this displacement vector is interpreted as the rate of view angle change. The linear velocity
%   of the animal in the virtual world is computed by rotating [dX, dY] to the animal's coordinate
%   frame, i.e. a pure dY displacement (dX = 0) corresponds to moving forward/backwards along the
%   current trajectory (as defined by view angle) of the mouse.
%
%   Two different types of gain are supported for view angle velocity, depending on the value of
%   vr.scaleA. The first is a simple linear gain factor, i.e. if vr.scaleA is finite this function
%   will compute:
%       (view angle velocity) = vr.scaleA * vr.orientation / (1 second)
%
%   If vr.scaleA is set to NaN, a qualitatively determined exponential gain is used. This is
%   motivated by the fact that it is physically much more difficult for a mouse to orient its body
%   along large angles while head-fixed on top of a ball, and is therefore unable to make sharp
%   turns when a linear gain is applied (unless the gain is very large, which then makes it
%   impossible for the mouse to reliably walk in a straight line). The following code can be used to
%   visualize the exponential gain function:
%
%     figure; hold on; grid on; xlabel('Orientation (radians)'); ylabel('View angle velocity (rad/s)');
%     ori = -pi/2:0.01:pi/2; plot(ori,ori); plot(ori,sign(ori).*min( exp(1.4*abs(ori).^1.2) - 1, pi ));
%
function [velocity] = moveArduino_FAKE_forward(vr, PosFromData) %took out rawData



PosFromData=double(PosFromData);
% DEBLUG

dy1 = PosFromData(1);
dx1 = PosFromData(2);
dY = PosFromData(3); % for some psychotic reason, this was: round(PosFromData(3) * 1.5);
dX = PosFromData(4);
dT = PosFromData(5);
dTheta = 0.05; % displacement of view angle

rawData         = [dy1, dx1, dY, dX, dT];    % For logging
% Special case for zero integrated Arduino time -- assume that velocity
% is the same as in the last ViRMEn frame
dY              = -dY;                            % This is just due to the orientation of the sensor

% Convert Arduino sampling time dT from ms to seconds
dT              = dT / 1000;

% Apply scale factors to translate number of   vsensor dots to virtual world units



if isPastCrossing(vr.cross_arms, vr.position)
    velocity(1)     = (vr.scaleX * 100 * dX) / dT;
    velocity(2) = 0;
else
    velocity(1) = 0;
    velocity(2)     = vr.scaleY * dY / dT;
end

velocity(3)     = 0;


if ~isPastCrossing(vr.cross_arms, vr.position) && abs(vr.position(4) + (-dX * dTheta)) < pi/6  

    velocity(4) = (-dX * dTheta) / dT; % allows for view angle changes

else
    velocity(4) = 0;
    
    
end

% The following should never happen but just in case
velocity(~isfinite(velocity)) = 0;
end

%% 2D rotation matrix counter-clockwise.
function R = R2(x)
R = [cos(x) -sin(x); sin(x) cos(x)];
end

