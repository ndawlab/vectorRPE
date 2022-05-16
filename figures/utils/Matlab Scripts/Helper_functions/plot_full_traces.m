function plot_full_traces(session_num,cellnums,trials_to_take,foldername)


curgg  = xlsread([foldername,'mouse',num2str(session_num),'.xlsx'],1);
curyvv = xlsread([foldername,'mouse',num2str(session_num),'.xlsx'],2);
curcvv = xlsread([foldername,'mouse',num2str(session_num),'.xlsx'],3);

clear trial_starts has_rw trial_ends cue_period_starts delay_period_starts outcome_period_ends
for l=1:length(trials_to_take)
    trial_starts(l) = curyvv(trials_to_take(l),1);
    has_rw(l) = curyvv(trials_to_take(l),5);
    trial_ends(l) = curyvv(trials_to_take(l),2);
    cue_period_starts(l) = find(curcvv(trial_starts(l):end,3)>0,1,'first')+trial_starts(l)-1;
    delay_period_starts(l) = find(curcvv(trial_starts(l):end,3)>220,1,'first')+trial_starts(l)-1;
    outcome_period_ends(l) = trial_ends(l)+2*15;
end

figure
clf;hold on
plot(curgg(trial_starts(1):outcome_period_ends(end) ,cellnums)+repmat(1:length(cellnums),length(trial_starts(1):outcome_period_ends(end)),1));shg
for l=1:length(trials_to_take)
    line([cue_period_starts(l) delay_period_starts(l)]-trial_starts(1),-[.2 .2],'Color',[0.2 0.2 0.2],'LineWidth',3)
    line([delay_period_starts(l) trial_ends(l)]-trial_starts(1),-[.2 .2],'Color',[0.3 0.3 1],'LineWidth',3)
    line([trial_ends(l) trial_ends(l)+2*15]-trial_starts(1),-[.2 .2],'Color',[1 .4 .7],'LineWidth',3)
    
end
plot(trial_ends(has_rw==1)-trial_starts(1),-ones(1,sum(has_rw))*0.25,'b.')

line([20 20],[0 0.5],'Color','k') % 50% df/f line
line([20 20 + 10*15],[0 0],'Color','k')   % 10 sec line

set(gca,'XTick',[],'YTick',[])
text(0,0.2,{'50%','DF/F'})
text(70,0,'10 s')




