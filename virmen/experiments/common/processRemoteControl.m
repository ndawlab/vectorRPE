%%
function vr = processRemoteControl(vr)
  
  global remoteSets;
  
  for iSet = 1:size(remoteSets,1)
    vr.(remoteSets{iSet,1}) = remoteSets{iSet,2};
  end
  
  remoteSets  = {};
  
end
