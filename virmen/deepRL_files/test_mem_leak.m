initializeVR()

% we call this at "reset" 
virmen_renderWorld();
curr_y_pos = 0;
num_trial = 0;
num_steps = 1000;
y_pos = zeros(1, num_steps);
screens = zeros(68, 120, num_steps);
actual_steps = 0;
% 0 = turn right; 1 = turn left % 2 = move forward/no va change
% for i = 1:num_steps
i = 0; 
while num_trial < 5
    i = i + 1;
    actual_steps = actual_steps + 1;
    y_pos(i) = curr_y_pos;
    if curr_y_pos < 89
        action = 1 ;
    else
        action = 1;
    end
    movement_py = [0, 0, -1, 0, 12.5];

    if action < 2
      movement_py(4) = (1 + action * -2); 
    end
    

    [vr_status, curr_y_pos, tow_positions] = virmenEngine_step(movement_py);
    screens(:,:,i) = virmenGetFrame_1dim(1);
    reward = max(0, (vr_status - 1));
    if vr_status == -1
        virmenEndTrial(num_trial, 0)
        num_trial = num_trial + 1;
        i = 0; 
        virmen_renderWorld()
%         break;
        
    end

end
y_pos = y_pos(1:actual_steps);
screens_saved = screens(:,:,1:actual_steps);