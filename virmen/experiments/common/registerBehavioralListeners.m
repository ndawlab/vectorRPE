%%
function vr = registerBehavioralListeners(vr)

  if ~isfield(vr.exper.userdata, 'pager') || isempty(vr.exper.userdata.pager)
    vr.pager    = [];
    return;
  end

  vr.pager      = vr.exper.userdata.pager;
  vr.runCount   = 0;
  
  vr.pager.addCommandReceiver('P', @doStopExperiment);
  vr.pager.addCommandReceiver('F', @doForfeitTrial);

end

%%
function doStopExperiment(pager, event)
  global remoteSets;
  remoteSets{end+1, 1}  = 'experimentEnded';
  remoteSets{end  , 2}  = true;
end

%%
function doForfeitTrial(pager, event)
  global remoteSets;
  remoteSets{end+1, 1}  = 'choice';
  remoteSets{end  , 2}  = Choice.nil;
  remoteSets{end+1, 1}  = 'state';
  remoteSets{end  , 2}  = BehavioralState.ChoiceMade;
end
