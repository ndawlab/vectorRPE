%% Modify ViRMen world object visibilities and colors according to the current maze and trial type.
function vr = configureCues(vr)

  % Default visibility of world objects
  vr.defaultVisibility  = vr.visibilityMask;

  % Turn off visibility of dynamically appearing cues
  if isfield(vr, 'dynamicCueNames')
    for name = vr.dynamicCueNames
      vr.defaultVisibility(vr.(name{:}))    ...
                        = false;
    end
  end
  
  % Turn off visibility of cues that are not appropriate for the trial type
  otherChoices          = setdiff(ChoiceExperimentStats.CHOICES, vr.trialType);
  if vr.hintVisibility
      if isfield(vr, 'choiceCueNames')
          for name = vr.choiceCueNames
              for choice = otherChoices
                  vr.defaultVisibility(vr.(name{:})(choice,:))                    ...
                      = (vr.mazes(vr.mazeID).visible.(name{:}) == 2)  ... # rachel edit: for some reason this was 4, but i changed it back to 2
                      ;
              end
          end
      end
  else
      name={'tri_turnHint'};
      vr.defaultVisibility(vr.(name{:})(Choice(1),:))=0; % change to 1 for doubel towers
      vr.defaultVisibility(vr.(name{:})(Choice(2),:))=0; % change to 1 for doubel towers           
  end
  
  % Special case for cues that are visible from start to end
  if ~isfinite(vr.cueVisibleAt)
    for iSide = 1:numel(vr.cuePos)
      iCue              = 1:numel(vr.cuePos{iSide});
      for name = vr.dynamicCueNames
        triangles       = vr.(name{:})(iSide,:,iCue);
        vr.defaultVisibility(triangles)   ...
                        = true;
      end
    end
    
    if isfield(vr, 'cueAppeared')
      for iSide = 1:numel(vr.cuePos)
        vr.cueAppeared{iSide}(:)  = true;
        vr.cueOnset{iSide}(:)     = 1;
        vr.cueTime{iSide}(:)      = 0;
      end
    end
  end
  
  % Change color of objects as configured for the current trial
  for name = fieldnames(vr.mazes(vr.mazeID).color)'
    for choice = ChoiceExperimentStats.CHOICES
      triangles     = vr.(name{:})(choice,:,:);
      vr.worlds{vr.currentWorld}.surface.colors(:,triangles)    ...
                    = vr.(['clr_' name{:}]){(choice == vr.trialType) + 1, choice};
    end
  end

end
