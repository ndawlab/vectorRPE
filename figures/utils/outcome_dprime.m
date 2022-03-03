load dprime_thirds res_diff res_currw sig_all_rw

dprime_diff = [];
dprime_currw = [];
diff = [];
currw = [];
for l=1:23 

    
    nominator = (nanmean(squeeze(nanmean(res_diff.hard_mat_cell{l}))')-nanmean(squeeze(nanmean(res_diff.easy_mat_cell{l}))'));
    denominator = sqrt(0.5*(nanvar(squeeze(mean(res_diff.hard_mat_cell{l}))')+nanvar(squeeze(mean(res_diff.easy_mat_cell{l}))')));
    dprime_diff=[dprime_diff nominator./denominator];
    diff = [diff nominator];
    nominator = (nanmean(squeeze(nanmean(res_currw.hard_mat_cell{l}))')-nanmean(squeeze(nanmean(res_currw.easy_mat_cell{l}))'));
    denominator = sqrt(0.5*(nanvar(squeeze(mean(res_currw.hard_mat_cell{l}))')+nanvar(squeeze(mean(res_currw.easy_mat_cell{l}))')));
    dprime_currw=[dprime_currw nominator./denominator];
    currw = [currw nominator]; 

end





%%

figure
subplot(1,2,1)
[nh,nx]=hist(diff,-.7:.05:.7);
bar(nx,nh,1,'EdgeColor','none','FaceColor',[.3 .3 .3]);shg
title(num2str([median(diff) signrank(diff)]))
axis([-.75 .75 0 max(nh)+1])
line([0 0],ylim,'Color','k','LineWidth',4,'LineStyle','--')
line([0 0]+median(diff),ylim,'Color',[1 .85 .34],'LineWidth',4,'LineStyle','-')
curytick = get(gca,'YTick');
set(gca,'YTick',curytick([1 end]),'FontSize',14,'FontName','Arial')
ylabel('# Neurons')
xlabel('Hard - Easy')
subplot(1,2,2)
[nh,nx]=hist(currw,-1.2:.05:1.2);shg
bar(nx,nh,1,'EdgeColor','none','FaceColor',[.3 .3 .3]);shg
title(num2str([median(currw) signrank(currw)]))
axis([-1.2 1.2 0 max(nh)+1])
line([0 0],ylim,'Color','k','LineWidth',4,'LineStyle','--')
line([0 0]+median(currw),ylim,'Color',[1 .85 .34],'LineWidth',4,'LineStyle','-')
curytick = get(gca,'YTick');
set(gca,'YTick',curytick([1 end]),'FontSize',14,'FontName','Arial')
xlabel('Rewarded - Unrewarded')