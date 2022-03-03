% Extract summary information about ViRMen worlds
function summary = summarizeVirmenWorld(world)

  summary.name            = world.name;
  summary.objects         = cell(size(world.objects));
  for iObj = 1:numel(world.objects)
    summary.objects{iObj} = world.objects{iObj}.name;
  end
  summary.objects         = sort(summary.objects);

end

